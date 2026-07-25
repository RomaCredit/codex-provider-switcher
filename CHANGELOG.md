# Changelog

## 0.2.2

- Remove the UTF-8 BOM that prevented Linux from recognizing the Python shebang.
- Make the standalone installer strip a BOM defensively before installing.

## 0.2.1

- Make the macOS/Linux one-line installer work without pip or pipx.
- Install the standalone command into `/usr/local/bin` for root or `~/.local/bin` for regular users.

## 0.2.0

- Add Python package metadata and the global `codex-provider-switcher` command.
- Open an interactive menu when the installed command is run without arguments.
- Add `pipx`, `pip`, curl, and PowerShell installation paths.
- Add cross-platform GitHub Actions tests.

## 0.1.0

- Add APIMaster and official subscription switching.
- Add one-click Windows batch menu.
- Add Codex Desktop history synchronization across provider modes.
- Repair project sidebar hints, thread `cwd` paths, SQLite provider values, and session metadata provider values.
- Add automatic backups before state changes.
- Add Chinese documentation while keeping runtime output English-only for encoding safety.
- Add cross-platform Python CLI and macOS `.command` menus.
