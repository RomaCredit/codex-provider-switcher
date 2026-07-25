#!/bin/sh
set -eu

REPOSITORY="git+https://github.com/RomaCredit/codex-provider-switcher.git"

if command -v pipx >/dev/null 2>&1; then
  pipx install --force "$REPOSITORY"
elif command -v python3 >/dev/null 2>&1; then
  python3 -m pip install --user --upgrade "$REPOSITORY"
else
  echo "Python 3 is required." >&2
  exit 1
fi

echo "Installed. Run: codex-provider-switcher"
