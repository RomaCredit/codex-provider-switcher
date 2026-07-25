$ErrorActionPreference = "Stop"
$Repository = "git+https://github.com/RomaCredit/codex-provider-switcher.git"

if (Get-Command pipx -ErrorAction SilentlyContinue) {
    pipx install --force $Repository
} elseif (Get-Command py -ErrorAction SilentlyContinue) {
    py -m pip install --user --upgrade $Repository
} elseif (Get-Command python -ErrorAction SilentlyContinue) {
    python -m pip install --user --upgrade $Repository
} else {
    throw "Python 3 is required. Install Python and run this installer again."
}

Write-Host "Installed. Run: codex-provider-switcher"
