# Security Policy

## Reporting a Vulnerability

Please open a private security advisory on GitHub if available, or contact the maintainer privately before publishing details.

## Sensitive Data

This tool works with local Codex Desktop state files. Those files may contain:

- API keys
- Auth tokens
- Conversation metadata
- Workspace paths

Do not attach real `.codex` state files to public issues. Redact secrets before sharing logs or screenshots.

## Expected Behavior

The script:

- Writes backups before modifying Codex state
- Stores APIMaster API keys only on the local machine
- Does not upload data
- Does not delete conversation files

