# Codex Provider Switcher

[中文文档](README.zh-CN.md)

Codex Provider Switcher is a small Windows and macOS utility for switching Codex Desktop between the official ChatGPT subscription profile and an OpenAI-compatible third-party API provider.

The default third-party provider is APIMaster:

```text
https://apimaster.ai/v1
```

The tool also synchronizes Codex Desktop conversation history metadata, so project sidebar conversations remain visible after switching provider modes.

## Why This Exists

Codex Desktop official subscription usage can hit its rolling usage limit. When that happens, this tool lets you switch to an APIMaster.ai third-party API key and keep working in the same project conversations.

When the official subscription limit resets, you can switch back to the official Codex subscription profile. Conversation history metadata is synchronized in both directions, so the same project threads remain visible and usable across provider modes.

## Language

Runtime output is English-only to avoid Windows console and PowerShell encoding issues. Chinese documentation is available in [README.zh-CN.md](README.zh-CN.md).

## Features

- Switch to APIMaster API-key mode.
- Switch back to the official ChatGPT subscription profile.
- Keep project conversation history available across both modes.
- Save and reuse official and APIMaster auth profiles.
- Repair Codex Desktop project sidebar conversation history.
- Synchronize `model_provider` in both `state_5.sqlite` and `sessions/rollout-*.jsonl`.
- Normalize old `\\?\` working-directory path prefixes.
- Create backups before modifying Codex Desktop state.
- Support Windows through PowerShell and macOS through the Python CLI.

## Requirements

- Windows or macOS
- Codex Desktop
- Python 3
- PowerShell, only for the Windows `.ps1` and `.bat` entry points

Python is used to safely update Codex Desktop SQLite state and JSONL session metadata.

## Quick Start

Fully quit Codex Desktop first.

On Windows, double-click:

```bat
codex-provider-menu.bat
```

On macOS, run:

```bash
chmod +x ./codex-provider-menu.command
./codex-provider-menu.command
```

Menu options:

```text
1. Switch to APIMaster and sync history
2. Switch to official subscription and sync history
3. Show status
4. Test APIMaster /v1/models
5. Save current profile as official
6. Repair Desktop history list
0. Exit
```

Recommended flow:

1. Fully quit Codex Desktop.
2. Run `codex-provider-menu.bat`.
3. Choose the target provider mode.
4. Wait for the script to finish.
5. Reopen Codex Desktop.

## CLI Usage

### Cross-Platform Python CLI

Show current status:

```bash
python3 codex_provider_switcher.py status
```

Switch to APIMaster:

```bash
python3 codex_provider_switcher.py apimaster
```

Switch to APIMaster with explicit key, model, and base URL:

```bash
python3 codex_provider_switcher.py apimaster \
  --api-key "YOUR_APIMASTER_KEY" \
  --model "gpt-5.5" \
  --base-url "https://apimaster.ai/v1"
```

Switch back to the official ChatGPT subscription profile:

```bash
python3 codex_provider_switcher.py official
```

Repair history without switching provider:

```bash
python3 codex_provider_switcher.py repair-history
```

Use a non-default Codex home directory for testing:

```bash
python3 codex_provider_switcher.py status --codex-home "/tmp/fake-codex-home"
```

### Windows PowerShell CLI

Show current status:

```powershell
.\switch-codex-provider.ps1 status
```

Switch to APIMaster. If no APIMaster key has been saved, the script will prompt for it:

```powershell
.\switch-codex-provider.ps1 apimaster
```

Switch to APIMaster with explicit key, model, and base URL:

```powershell
.\switch-codex-provider.ps1 apimaster `
  -ApiKey "YOUR_APIMASTER_KEY" `
  -Model "gpt-5.5" `
  -BaseUrl "https://apimaster.ai/v1"
```

Switch back to the official ChatGPT subscription profile:

```powershell
.\switch-codex-provider.ps1 official
```

Repair history without switching provider:

```powershell
.\switch-codex-provider.ps1 repair-history
```

Test APIMaster `/models`:

```powershell
.\switch-codex-provider.ps1 test
```

Save the current Codex config/auth as the official profile:

```powershell
.\switch-codex-provider.ps1 save-official
```

Use a non-default Codex home directory for testing:

```powershell
.\switch-codex-provider.ps1 status -CodexHome "D:\tmp\fake-codex-home"
```

## What It Modifies

By default, the tool reads and writes:

On Windows:

- `%USERPROFILE%\.codex\config.toml`
- `%USERPROFILE%\.codex\auth.json`
- `%USERPROFILE%\.codex\.codex-global-state.json`
- `%USERPROFILE%\.codex\state_5.sqlite`
- `%USERPROFILE%\.codex\sessions\...\rollout-*.jsonl`

On macOS:

- `~/.codex/config.toml`
- `~/.codex/auth.json`
- `~/.codex/.codex-global-state.json`
- `~/.codex/state_5.sqlite`
- `~/.codex/sessions/.../rollout-*.jsonl`

It does not delete conversation content. The history repair only updates metadata used by Codex Desktop to associate threads with projects and providers.

## Backups

Backups are written to:

Windows:

```text
%USERPROFILE%\.codex\provider-switcher
```

macOS:

```text
~/.codex/provider-switcher
```

Typical backup files:

- `config.<timestamp>.toml.bak`
- `auth.<timestamp>.json.bak`
- `global-state.<timestamp>.json.bak`
- `state_5.<timestamp>.sqlite.bak`
- `session-meta.<timestamp>.bak\...`

## Why History Sync Is Needed

Codex Desktop project sidebar history is not based only on the session files. It may also use:

- Global project hints: `.codex-global-state.json`
- SQLite thread index: `state_5.sqlite`
- The first-line session metadata in `sessions/rollout-*.jsonl`

The `model_provider` value can affect sidebar filtering or backfill behavior. If only `config.toml` and `auth.json` are switched, old conversations may remain under `openai` or `custom`, so they can disappear when the current mode is APIMaster.

This tool synchronizes provider metadata to the current mode:

- APIMaster mode: `apimaster`
- Official subscription mode: `openai`

## Rollback

To roll back, fully quit Codex Desktop and manually restore the relevant timestamped backup files from:

```text
%USERPROFILE%\.codex\provider-switcher
```

## Security Notes

- API keys are stored only on the local machine.
- The tool does not upload files.
- The tool does not modify the Codex installation directory.
- The tool does not delete conversation files.
- SQLite and JSONL state files are backed up before modification.

Do not share real `.codex` files in public issues. They may contain secrets or private workspace paths.

## Platform Notes

The Python CLI is the primary cross-platform implementation and supports Windows and macOS.

The PowerShell script and `.bat` menus are kept for Windows users who prefer a native double-click workflow.

On macOS, Codex Desktop should be fully quit before switching. If the `.command` file does not run after download, use:

```bash
chmod +x ./codex-provider-menu.command
```

## Limitations

- Codex Desktop only.
- Codex Desktop internal state may change between versions. If a future update breaks history display, run `repair-history` first.
- The official subscription profile must exist locally. Sign in to Codex Desktop first, then run `save-official` or switch from official to APIMaster once.

## Development

This project has no build step.

Core files:

- `codex_provider_switcher.py`
- `switch-codex-provider.ps1`
- `codex-provider-menu.bat`
- `codex-provider-menu.command`

Basic checks:

```powershell
.\switch-codex-provider.ps1 status
```

```bash
python3 codex_provider_switcher.py status
```

## License

MIT. See [LICENSE](LICENSE).
