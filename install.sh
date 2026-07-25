#!/bin/sh
set -eu

SCRIPT_URL="https://raw.githubusercontent.com/RomaCredit/codex-provider-switcher/main/codex_provider_switcher.py"

if ! command -v python3 >/dev/null 2>&1; then
  echo "Python 3 is required." >&2
  exit 1
fi

if [ -n "${CODEX_SWITCHER_BIN_DIR:-}" ]; then
  bin_dir="$CODEX_SWITCHER_BIN_DIR"
elif [ "$(id -u)" -eq 0 ]; then
  bin_dir="/usr/local/bin"
else
  bin_dir="${HOME}/.local/bin"
fi

mkdir -p "$bin_dir"
target="$bin_dir/codex-provider-switcher"
temporary="${target}.tmp.$$"
trap 'rm -f "$temporary"' EXIT HUP INT TERM

if command -v curl >/dev/null 2>&1; then
  curl -fsSL "$SCRIPT_URL" -o "$temporary"
elif command -v wget >/dev/null 2>&1; then
  wget -qO "$temporary" "$SCRIPT_URL"
else
  echo "curl or wget is required." >&2
  exit 1
fi

chmod 755 "$temporary"
mv "$temporary" "$target"
trap - EXIT HUP INT TERM

echo "Installed: $target"
case ":${PATH}:" in
  *":${bin_dir}:"*) echo "Run: codex-provider-switcher" ;;
  *)
    echo "Add $bin_dir to PATH, then run: codex-provider-switcher"
    echo "For the current shell: export PATH=\"$bin_dir:\$PATH\""
    ;;
esac
