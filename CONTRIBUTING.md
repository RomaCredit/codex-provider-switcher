# Contributing

Thanks for considering a contribution.

## Development Setup

This project is intentionally small and has no build step.

Requirements:

- Windows or macOS
- PowerShell
- Python 3
- Codex Desktop, for real-world testing

## Before Opening a Pull Request

Please run:

```bash
python3 codex_provider_switcher.py status
```

On Windows, also run:

```powershell
.\switch-codex-provider.ps1 status
```

If your change touches history synchronization, test both directions:

```powershell
.\switch-codex-provider.ps1 apimaster
.\switch-codex-provider.ps1 official
```

Use `-CodexHome` with a temporary fixture directory when possible, so tests do not have to touch your real Codex Desktop state.

## Guidelines

- Keep the tool dependency-light.
- Keep all state mutations backed up before writing.
- Avoid logging API keys or sensitive auth content.
- Document any new Codex Desktop state file that the tool reads or writes.
