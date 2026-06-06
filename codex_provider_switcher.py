#!/usr/bin/env python3
"""Cross-platform Codex Desktop provider switcher.

This CLI supports macOS and Windows. The Windows PowerShell script remains
available for users who prefer the double-click batch menu.
"""

from __future__ import annotations

import argparse
import getpass
import json
import os
import shutil
import sqlite3
import sys
import time
import urllib.request
from pathlib import Path
from typing import Any


DEFAULT_BASE_URL = "https://apimaster.ai/v1"
DEFAULT_MODEL = "gpt-5.5"

MESSAGES = {
    "state_db_missing": "Codex state DB not found: {0}",
    "sessions_missing": "Codex sessions directory not found: {0}",
    "global_state_missing": "Codex Desktop global state not found: {0}",
    "history_hints_repaired": "Repaired Codex Desktop history hints: sessions={0}, added={1}, updated={2}, parse_errors={3}",
    "session_meta_repaired": "Repaired Codex session metadata: checked={0}, changed={1}, provider={2}, parse_errors={3}, backup_dir={4}",
    "state_db_repaired": "Repaired Codex state DB: cwd_checked={0}, cwd_updated={1}, provider={2}, provider_updated={3}, backup={4}",
    "restart": "Restart Codex Desktop if the sidebar still shows stale project chat lists.",
    "paste_key": "Paste APIMaster API key: ",
    "key_required": "APIMaster API key is required.",
    "switched_apimaster": "Switched Codex to APIMaster: model={0}, base_url={1}",
    "history_untouched": "Conversation history is untouched. Restart Codex Desktop or open a new turn if the app has cached provider settings.",
    "official_auth_missing": "No saved official auth profile found. Use Codex login if the official subscription is not active.",
    "switched_official": "Switched Codex to official subscription profile.",
    "provider_status": "Codex provider: {0}",
    "model_status": "Model: {0}",
    "auth_status": "Auth mode: {0}",
    "backup_status": "Switcher backups: {0}",
    "no_apimaster_key": "No APIMaster API key found. Run: python3 codex_provider_switcher.py apimaster --api-key YOUR_KEY",
    "models_ok": "APIMaster /models OK. First models:",
    "saved_official": "Saved current Codex config/auth as official profile.",
}
def tr(key: str, *args: Any) -> str:
    template = MESSAGES.get(key) or key
    return template.format(*args)


def timestamp() -> str:
    return time.strftime("%Y%m%d-%H%M%S")


class Switcher:
    def __init__(self, codex_home: Path) -> None:
        self.codex_home = codex_home.expanduser()
        self.config_path = self.codex_home / "config.toml"
        self.auth_path = self.codex_home / "auth.json"
        self.global_state_path = self.codex_home / ".codex-global-state.json"
        self.sessions_dir = self.codex_home / "sessions"
        self.state_db_path = self.codex_home / "state_5.sqlite"
        self.state_dir = self.codex_home / "provider-switcher"
        self.official_config_path = self.state_dir / "official.config.toml"
        self.official_auth_path = self.state_dir / "official.auth.json"
        self.apimaster_auth_path = self.state_dir / "apimaster.auth.json"

    def say(self, key: str, *args: Any) -> None:
        print(tr(key, *args))

    def warn(self, key: str, *args: Any) -> None:
        print("WARNING: " + tr(key, *args), file=sys.stderr)

    def ensure_state_dir(self) -> None:
        self.state_dir.mkdir(parents=True, exist_ok=True)

    def backup_current(self) -> None:
        self.ensure_state_dir()
        stamp = timestamp()
        if self.config_path.exists():
            shutil.copy2(self.config_path, self.state_dir / f"config.{stamp}.toml.bak")
        if self.auth_path.exists():
            shutil.copy2(self.auth_path, self.state_dir / f"auth.{stamp}.json.bak")

    def save_official_profile(self) -> None:
        self.ensure_state_dir()
        if self.config_path.exists():
            shutil.copy2(self.config_path, self.official_config_path)
        if self.auth_path.exists():
            shutil.copy2(self.auth_path, self.official_auth_path)

    def read_config(self) -> str:
        if not self.config_path.exists():
            return ""
        return self.config_path.read_text(encoding="utf-8")

    def write_config(self, text: str) -> None:
        self.config_path.parent.mkdir(parents=True, exist_ok=True)
        self.config_path.write_text(text, encoding="utf-8")

    @staticmethod
    def _head_tail(text: str) -> tuple[str, str]:
        marker = text.find("\n[")
        if marker >= 0:
            return text[:marker], text[marker:]
        return text, ""

    @staticmethod
    def get_top_level_value(text: str, key: str) -> str | None:
        head, _ = Switcher._head_tail(text)
        for line in head.splitlines():
            stripped = line.strip()
            if not stripped or stripped.startswith("#") or "=" not in stripped:
                continue
            left, right = stripped.split("=", 1)
            if left.strip() != key:
                continue
            value = right.strip().strip('"').strip("'")
            return value or None
        return None

    @staticmethod
    def set_top_level_string(text: str, key: str, value: str) -> str:
        head, tail = Switcher._head_tail(text)
        out: list[str] = []
        replaced = False
        for line in head.splitlines():
            stripped = line.strip()
            if stripped and "=" in stripped and stripped.split("=", 1)[0].strip() == key:
                out.append(f'{key} = "{value}"')
                replaced = True
            else:
                out.append(line)
        if not replaced:
            out.append(f'{key} = "{value}"')
        return "\n".join(line for line in out if line is not None).rstrip() + tail

    @staticmethod
    def remove_top_level_key(text: str, key: str) -> str:
        head, tail = Switcher._head_tail(text)
        out = []
        for line in head.splitlines():
            stripped = line.strip()
            if stripped and "=" in stripped and stripped.split("=", 1)[0].strip() == key:
                continue
            out.append(line)
        return "\n".join(out).rstrip() + tail

    @staticmethod
    def upsert_apimaster_provider(text: str, base_url: str, use_chat: bool) -> str:
        wire_api = "chat" if use_chat else "responses"
        block = (
            "\n[model_providers.apimaster]\n"
            'name = "apimaster"\n'
            f'base_url = "{base_url}"\n'
            f'wire_api = "{wire_api}"\n'
            "requires_openai_auth = true\n"
        )
        lines = text.splitlines()
        out: list[str] = []
        i = 0
        replaced = False
        while i < len(lines):
            if lines[i].strip() == "[model_providers.apimaster]":
                if not replaced:
                    out.extend(block.strip("\n").splitlines())
                    replaced = True
                i += 1
                while i < len(lines) and not lines[i].lstrip().startswith("["):
                    i += 1
                continue
            out.append(lines[i])
            i += 1
        result = "\n".join(out).rstrip()
        if not replaced:
            result += block
        else:
            result += "\n"
        return result

    def current_history_provider(self) -> str:
        provider = self.get_top_level_value(self.read_config(), "model_provider")
        return provider or "openai"

    def repair_state_db(self, desired_provider: str) -> None:
        if not self.state_db_path.exists():
            self.warn("state_db_missing", self.state_db_path)
            return
        self.ensure_state_dir()
        backup = self.state_dir / f"state_5.{timestamp()}.sqlite.bak"
        src = sqlite3.connect(self.state_db_path)
        try:
            dst = sqlite3.connect(backup)
            try:
                src.backup(dst)
            finally:
                dst.close()
            cur = src.cursor()
            rows = cur.execute("select id, cwd from threads").fetchall()
            cwd_updated = 0
            for thread_id, cwd in rows:
                if isinstance(cwd, str) and cwd.startswith("\\\\?\\"):
                    cur.execute("update threads set cwd = ? where id = ?", (cwd[4:], thread_id))
                    cwd_updated += 1
            provider_updated = cur.execute(
                "update threads set model_provider = ? where model_provider <> ?",
                (desired_provider, desired_provider),
            ).rowcount
            src.commit()
        finally:
            src.close()
        self.say(
            "state_db_repaired",
            len(rows),
            cwd_updated,
            desired_provider,
            provider_updated,
            backup,
        )

    def repair_session_metadata(self, desired_provider: str) -> None:
        if not self.sessions_dir.exists():
            self.warn("sessions_missing", self.sessions_dir)
            return
        backup_dir = self.state_dir / f"session-meta.{timestamp()}.bak"
        checked = changed = errors = 0
        for path in self.sessions_dir.rglob("rollout-*.jsonl"):
            checked += 1
            try:
                text = path.read_text(encoding="utf-8")
                if not text:
                    continue
                first, sep, rest = text.partition("\n")
                meta = json.loads(first.rstrip("\r"))
                if meta.get("type") != "session_meta":
                    continue
                payload = meta.setdefault("payload", {})
                cwd = str(payload.get("cwd") or "")
                next_cwd = cwd[4:] if cwd.startswith("\\\\?\\") else cwd
                needs_update = (
                    payload.get("model_provider") != desired_provider or next_cwd != cwd
                )
                if not needs_update:
                    continue
                payload["model_provider"] = desired_provider
                if next_cwd:
                    payload["cwd"] = next_cwd
                rel = path.relative_to(self.sessions_dir)
                backup_path = backup_dir / rel
                backup_path.parent.mkdir(parents=True, exist_ok=True)
                shutil.copy2(path, backup_path)
                updated_first = json.dumps(meta, ensure_ascii=False, separators=(",", ":"))
                path.write_text(updated_first + (sep or "\n") + rest, encoding="utf-8")
                changed += 1
            except Exception:
                errors += 1
        self.say(
            "session_meta_repaired",
            checked,
            changed,
            desired_provider,
            errors,
            backup_dir if changed else "not-needed",
        )

    def repair_desktop_history_hints(self) -> None:
        if not self.global_state_path.exists():
            self.warn("global_state_missing", self.global_state_path)
            return
        if not self.sessions_dir.exists():
            self.warn("sessions_missing", self.sessions_dir)
            return
        self.ensure_state_dir()
        state = json.loads(self.global_state_path.read_text(encoding="utf-8"))
        hints = dict(state.get("thread-workspace-root-hints") or {})
        found = added = updated = errors = 0
        for path in self.sessions_dir.rglob("rollout-*.jsonl"):
            try:
                first = path.read_text(encoding="utf-8").splitlines()[0]
                meta = json.loads(first)
                if meta.get("type") != "session_meta":
                    continue
                payload = meta.get("payload") or {}
                thread_id = str(payload.get("id") or "")
                cwd = str(payload.get("cwd") or "")
                if cwd.startswith("\\\\?\\"):
                    cwd = cwd[4:]
                if not thread_id or not cwd:
                    continue
                found += 1
                if thread_id not in hints:
                    hints[thread_id] = cwd
                    added += 1
                elif hints[thread_id] != cwd:
                    hints[thread_id] = cwd
                    updated += 1
            except Exception:
                errors += 1
        state["thread-workspace-root-hints"] = hints
        backup = self.state_dir / f"global-state.{timestamp()}.json.bak"
        shutil.copy2(self.global_state_path, backup)
        self.global_state_path.write_text(
            json.dumps(state, ensure_ascii=False, separators=(",", ":")),
            encoding="utf-8",
        )
        desired_provider = self.current_history_provider()
        self.say("history_hints_repaired", found, added, updated, errors)
        self.repair_session_metadata(desired_provider)
        self.repair_state_db(desired_provider)
        self.say("restart")

    def switch_to_apimaster(
        self, api_key: str | None, model: str, base_url: str, chat_fallback: bool
    ) -> None:
        self.config_path.parent.mkdir(parents=True, exist_ok=True)
        if not self.config_path.exists():
            self.config_path.write_text("", encoding="utf-8")
        self.backup_current()
        current_config = self.read_config()
        if self.get_top_level_value(current_config, "model_provider") != "apimaster":
            self.save_official_profile()
        if not api_key and self.apimaster_auth_path.exists():
            saved = json.loads(self.apimaster_auth_path.read_text(encoding="utf-8"))
            api_key = saved.get("OPENAI_API_KEY")
        if not api_key:
            api_key = getpass.getpass(tr("paste_key"))
        if not api_key:
            raise SystemExit(tr("key_required"))

        auth_json = json.dumps({"OPENAI_API_KEY": api_key}, indent=2)
        self.auth_path.write_text(auth_json, encoding="utf-8")
        self.apimaster_auth_path.write_text(auth_json, encoding="utf-8")

        updated = current_config
        updated = self.set_top_level_string(updated, "model_provider", "apimaster")
        updated = self.set_top_level_string(updated, "model", model)
        updated = self.set_top_level_string(updated, "model_reasoning_effort", "high")
        updated = self.upsert_apimaster_provider(updated, base_url, chat_fallback)
        self.write_config(updated)

        self.say("switched_apimaster", model, base_url)
        self.repair_desktop_history_hints()
        self.say("history_untouched")

    def switch_to_official(self) -> None:
        self.backup_current()
        if self.official_config_path.exists():
            shutil.copy2(self.official_config_path, self.config_path)
        else:
            text = self.read_config()
            text = self.remove_top_level_key(text, "model_provider")
            text = self.set_top_level_string(text, "model", DEFAULT_MODEL)
            self.write_config(text)
        if self.official_auth_path.exists():
            shutil.copy2(self.official_auth_path, self.auth_path)
        else:
            self.warn("official_auth_missing")
        self.say("switched_official")
        self.repair_desktop_history_hints()
        self.say("history_untouched")

    def status(self) -> None:
        config = self.read_config()
        provider = self.get_top_level_value(config, "model_provider") or "official/default"
        model = self.get_top_level_value(config, "model") or ""
        auth_mode = "missing"
        if self.auth_path.exists():
            auth = json.loads(self.auth_path.read_text(encoding="utf-8"))
            if "auth_mode" in auth:
                auth_mode = str(auth["auth_mode"])
            elif "OPENAI_API_KEY" in auth:
                auth_mode = "apikey"
            else:
                auth_mode = "unknown"
        self.say("provider_status", provider)
        self.say("model_status", model)
        self.say("auth_status", auth_mode)
        self.say("backup_status", self.state_dir)

    def test_apimaster(self, api_key: str | None, base_url: str) -> None:
        if not api_key and self.apimaster_auth_path.exists():
            saved = json.loads(self.apimaster_auth_path.read_text(encoding="utf-8"))
            api_key = saved.get("OPENAI_API_KEY")
        if not api_key and self.auth_path.exists():
            saved = json.loads(self.auth_path.read_text(encoding="utf-8"))
            api_key = saved.get("OPENAI_API_KEY")
        if not api_key:
            raise SystemExit(tr("no_apimaster_key"))
        req = urllib.request.Request(
            base_url.rstrip("/") + "/models",
            headers={"Authorization": f"Bearer {api_key}"},
            method="GET",
        )
        with urllib.request.urlopen(req, timeout=30) as resp:
            data = json.loads(resp.read().decode("utf-8"))
        self.say("models_ok")
        for item in list(data.get("data") or [])[:10]:
            model_id = item.get("id") if isinstance(item, dict) else str(item)
            print(f" - {model_id}")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Switch Codex Desktop provider profiles.")
    parser.add_argument(
        "mode",
        nargs="?",
        default="status",
        choices=["apimaster", "official", "status", "test", "save-official", "repair-history"],
    )
    parser.add_argument("--api-key")
    parser.add_argument("--model", default=DEFAULT_MODEL)
    parser.add_argument("--base-url", default=DEFAULT_BASE_URL)
    parser.add_argument("--codex-home", default=os.path.expanduser("~/.codex"))
    parser.add_argument("--chat-fallback", action="store_true")
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    switcher = Switcher(Path(args.codex_home))
    switcher.ensure_state_dir()
    if args.mode == "apimaster":
        switcher.switch_to_apimaster(
            args.api_key, args.model, args.base_url, args.chat_fallback
        )
    elif args.mode == "official":
        switcher.switch_to_official()
    elif args.mode == "save-official":
        switcher.save_official_profile()
        switcher.say("saved_official")
    elif args.mode == "test":
        switcher.test_apimaster(args.api_key, args.base_url)
    elif args.mode == "repair-history":
        switcher.repair_desktop_history_hints()
    else:
        switcher.status()


if __name__ == "__main__":
    main()
