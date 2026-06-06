param(
    [Parameter(Position = 0)]
    [ValidateSet("apimaster", "official", "status", "test", "save-official", "repair-history")]
    [string] $Mode = "status",

    [string] $ApiKey,
    [string] $Model = "gpt-5.5",
    [string] $BaseUrl = "https://apimaster.ai/v1",
    [string] $CodexHome = (Join-Path $env:USERPROFILE ".codex"),
    [switch] $ChatFallback
)

$ErrorActionPreference = "Stop"

$ConfigPath = Join-Path $CodexHome "config.toml"
$AuthPath = Join-Path $CodexHome "auth.json"
$GlobalStatePath = Join-Path $CodexHome ".codex-global-state.json"
$SessionsDir = Join-Path $CodexHome "sessions"
$StateDbPath = Join-Path $CodexHome "state_5.sqlite"
$StateDir = Join-Path $CodexHome "provider-switcher"
$OfficialConfigPath = Join-Path $StateDir "official.config.toml"
$OfficialAuthPath = Join-Path $StateDir "official.auth.json"
$ApimasterAuthPath = Join-Path $StateDir "apimaster.auth.json"

$Messages = @{
    stateDbMissing = "Codex state DB not found: {0}"
    pythonMissingState = "Python was not found, so state DB repair was skipped."
    sessionsMissing = "Codex sessions directory not found: {0}"
    pythonMissingSessions = "Python was not found, so session metadata repair was skipped."
    globalStateMissing = "Codex Desktop global state not found: {0}"
    historyHintsRepaired = "Repaired Codex Desktop history hints: sessions={0}, added={1}, updated={2}, parse_errors={3}"
    restartCodex = "Restart Codex Desktop if the sidebar still shows stale project chat lists."
    pasteKey = "Paste APIMaster API key"
    keyRequired = "APIMaster API key is required."
    switchedApimaster = "Switched Codex to APIMaster: model={0}, base_url={1}"
    historyUntouched = "Conversation history is untouched. Restart Codex Desktop or open a new turn if the app has cached provider settings."
    officialAuthMissing = "No saved official auth profile found. Use Codex login if the official subscription is not active."
    switchedOfficial = "Switched Codex to official subscription profile."
    providerStatus = "Codex provider: {0}"
    modelStatus = "Model: {0}"
    authStatus = "Auth mode: {0}"
    backupStatus = "Switcher backups: {0}"
    noApimasterKey = "No APIMaster API key found. Run: .\switch-codex-provider.ps1 apimaster -ApiKey YOUR_KEY"
    modelsOk = "APIMaster /models OK. First models:"
    savedOfficial = "Saved current Codex config/auth as official profile."
}

function T {
    param(
        [Parameter(Mandatory = $true)] [string] $Key,
        [object[]] $Args = @()
    )
    $template = $Messages[$Key]
    if (!$template) { return $Key }
    if ($Args.Count -gt 0) { return [string]::Format($template, $Args) }
    return $template
}

function Ensure-StateDir {
    if (!(Test-Path $StateDir)) {
        New-Item -ItemType Directory -Path $StateDir | Out-Null
    }
}

function Timestamp {
    return (Get-Date).ToString("yyyyMMdd-HHmmss")
}

function Backup-Current {
    Ensure-StateDir
    $stamp = Timestamp
    if (Test-Path $ConfigPath) {
        Copy-Item -LiteralPath $ConfigPath -Destination (Join-Path $StateDir "config.$stamp.toml.bak") -Force
    }
    if (Test-Path $AuthPath) {
        Copy-Item -LiteralPath $AuthPath -Destination (Join-Path $StateDir "auth.$stamp.json.bak") -Force
    }
}

function Write-Utf8NoBom {
    param([string] $Path, [string] $Value)
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $Value, $utf8NoBom)
}

function Set-JsonProperty {
    param(
        [Parameter(Mandatory = $true)] $Object,
        [Parameter(Mandatory = $true)] [string] $Name,
        [Parameter(Mandatory = $true)] $Value
    )
    Add-Member -InputObject $Object -NotePropertyName $Name -NotePropertyValue $Value -Force
}

function Save-OfficialProfile {
    Ensure-StateDir
    if (Test-Path $ConfigPath) {
        Copy-Item -LiteralPath $ConfigPath -Destination $OfficialConfigPath -Force
    }
    if (Test-Path $AuthPath) {
        Copy-Item -LiteralPath $AuthPath -Destination $OfficialAuthPath -Force
    }
}

function Get-CurrentHistoryProvider {
    $config = if (Test-Path $ConfigPath) { Get-Content -Raw -LiteralPath $ConfigPath } else { "" }
    $provider = Get-TopLevelValue -Text $config -Key "model_provider"
    if ($provider) { return $provider }
    return "openai"
}

function Repair-StateDbThreadCwds {
    param([string] $DesiredProvider = (Get-CurrentHistoryProvider))

    if (!(Test-Path $StateDbPath)) {
        Write-Warning (T "stateDbMissing" $StateDbPath)
        return
    }

    $python = Get-Command python -ErrorAction SilentlyContinue
    if (!$python) {
        Write-Warning (T "pythonMissingState")
        return
    }

    $env:CODEX_SWITCHER_STATE_DB = $StateDbPath
    $env:CODEX_SWITCHER_BACKUP_DIR = $StateDir
    $env:CODEX_SWITCHER_PROVIDER = $DesiredProvider
    $script = @'
import os
import sqlite3
import time

db = os.environ["CODEX_SWITCHER_STATE_DB"]
backup_dir = os.environ["CODEX_SWITCHER_BACKUP_DIR"]
desired_provider = os.environ.get("CODEX_SWITCHER_PROVIDER") or "openai"
os.makedirs(backup_dir, exist_ok=True)

stamp = time.strftime("%Y%m%d-%H%M%S")
backup = os.path.join(backup_dir, f"state_5.{stamp}.sqlite.bak")

src = sqlite3.connect(db)
dst = sqlite3.connect(backup)
src.backup(dst)
dst.close()

cur = src.cursor()
rows = cur.execute("select id, cwd from threads").fetchall()

cwd_updated = 0
for thread_id, cwd in rows:
    if cwd.startswith("\\\\?\\"):
        cur.execute("update threads set cwd = ? where id = ?", (cwd[4:], thread_id))
        cwd_updated += 1

provider_updated = cur.execute(
    "update threads set model_provider = ? where model_provider <> ?",
    (desired_provider, desired_provider),
).rowcount

src.commit()
src.close()

print(
    "Repaired Codex state DB: "
    f"cwd_checked={len(rows)}, cwd_updated={cwd_updated}, "
    f"provider={desired_provider}, provider_updated={provider_updated}, "
    f"backup={backup}"
)
'@
    $script | & $python.Source -
}

function Repair-SessionMetadata {
    param([string] $DesiredProvider = (Get-CurrentHistoryProvider))

    if (!(Test-Path $SessionsDir)) {
        Write-Warning (T "sessionsMissing" $SessionsDir)
        return
    }

    $python = Get-Command python -ErrorAction SilentlyContinue
    if (!$python) {
        Write-Warning (T "pythonMissingSessions")
        return
    }

    $env:CODEX_SWITCHER_SESSIONS_DIR = $SessionsDir
    $env:CODEX_SWITCHER_BACKUP_DIR = $StateDir
    $env:CODEX_SWITCHER_PROVIDER = $DesiredProvider
    $script = @'
import json
import os
import shutil
import time
from pathlib import Path

sessions_dir = Path(os.environ["CODEX_SWITCHER_SESSIONS_DIR"])
backup_root = Path(os.environ["CODEX_SWITCHER_BACKUP_DIR"])
desired_provider = os.environ.get("CODEX_SWITCHER_PROVIDER") or "openai"
stamp = time.strftime("%Y%m%d-%H%M%S")
backup_dir = backup_root / f"session-meta.{stamp}.bak"

checked = changed = errors = 0
for path in sessions_dir.rglob("rollout-*.jsonl"):
    checked += 1
    try:
        text = path.read_text(encoding="utf-8")
        if not text:
            continue
        newline = "\r\n" if "\r\n" in text[:4096] else "\n"
        first, sep, rest = text.partition("\n")
        line = first.rstrip("\r")
        meta = json.loads(line)
        if meta.get("type") != "session_meta":
            continue

        payload = meta.setdefault("payload", {})
        cwd = str(payload.get("cwd") or "")
        next_cwd = cwd[4:] if cwd.startswith("\\\\?\\") else cwd
        before_provider = payload.get("model_provider")
        needs_update = before_provider != desired_provider or next_cwd != cwd
        if not needs_update:
            continue

        payload["model_provider"] = desired_provider
        if next_cwd:
            payload["cwd"] = next_cwd

        rel = path.relative_to(sessions_dir)
        backup_path = backup_dir / rel
        backup_path.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(path, backup_path)

        updated_first = json.dumps(meta, ensure_ascii=True, separators=(",", ":"))
        path.write_text(updated_first + (sep or newline) + rest, encoding="utf-8")
        changed += 1
    except Exception:
        errors += 1

print(
    "Repaired Codex session metadata: "
    f"checked={checked}, changed={changed}, provider={desired_provider}, "
    f"parse_errors={errors}, backup_dir={backup_dir if changed else 'not-needed'}"
)
'@
    $script | & $python.Source -
}

function Repair-DesktopHistoryHints {
    if (!(Test-Path $GlobalStatePath)) {
        Write-Warning (T "globalStateMissing" $GlobalStatePath)
        return
    }
    if (!(Test-Path $SessionsDir)) {
        Write-Warning (T "sessionsMissing" $SessionsDir)
        return
    }

    $state = Get-Content -Encoding UTF8 -Raw -LiteralPath $GlobalStatePath | ConvertFrom-Json
    $existing = $state.PSObject.Properties["thread-workspace-root-hints"]
    $hints = [ordered]@{}
    if ($existing -and $existing.Value) {
        foreach ($prop in $existing.Value.PSObject.Properties) {
            $hints[$prop.Name] = [string] $prop.Value
        }
    }

    $found = 0
    $added = 0
    $updated = 0
    $errors = 0
    $rollouts = Get-ChildItem -Recurse -File -LiteralPath $SessionsDir -Filter "rollout-*.jsonl" -ErrorAction SilentlyContinue
    foreach ($file in $rollouts) {
        try {
            $line = Get-Content -Encoding UTF8 -TotalCount 1 -LiteralPath $file.FullName
            if (!$line) { continue }
            $meta = $line | ConvertFrom-Json
            if ($meta.type -ne "session_meta") { continue }

            $threadId = [string] $meta.payload.id
            $cwd = [string] $meta.payload.cwd
            if ($cwd.StartsWith("\\?\")) {
                $cwd = $cwd.Substring(4)
            }
            if (!$threadId -or !$cwd) { continue }

            $found += 1
            if (!$hints.Contains($threadId)) {
                $hints[$threadId] = $cwd
                $added += 1
            } elseif ($hints[$threadId] -ne $cwd) {
                $hints[$threadId] = $cwd
                $updated += 1
            }
        } catch {
            $errors += 1
        }
    }

    Set-JsonProperty -Object $state -Name "thread-workspace-root-hints" -Value ([pscustomobject] $hints)

    $stamp = Timestamp
    Copy-Item -LiteralPath $GlobalStatePath -Destination (Join-Path $StateDir "global-state.$stamp.json.bak") -Force
    $json = $state | ConvertTo-Json -Depth 100 -Compress
    Write-Utf8NoBom -Path $GlobalStatePath -Value $json

    $desiredProvider = Get-CurrentHistoryProvider
    Write-Host (T "historyHintsRepaired" $found, $added, $updated, $errors)
    Repair-SessionMetadata -DesiredProvider $desiredProvider
    Repair-StateDbThreadCwds -DesiredProvider $desiredProvider
    Write-Host (T "restartCodex")
}

function Get-TopLevelValue {
    param([string] $Text, [string] $Key)
    $pattern = "(?m)^\s*$([regex]::Escape($Key))\s*=\s*""?([^""\r\n]+)""?\s*$"
    $firstTable = $Text.IndexOf("`n[")
    $head = if ($firstTable -ge 0) { $Text.Substring(0, $firstTable) } else { $Text }
    $m = [regex]::Match($head, $pattern)
    if ($m.Success) { return $m.Groups[1].Value.Trim() }
    return $null
}

function Set-TopLevelString {
    param([string] $Text, [string] $Key, [string] $Value)
    $line = "$Key = `"$Value`""
    $firstTable = $Text.IndexOf("`n[")
    if ($firstTable -ge 0) {
        $head = $Text.Substring(0, $firstTable)
        $tail = $Text.Substring($firstTable)
    } else {
        $head = $Text
        $tail = ""
    }

    $pattern = "(?m)^\s*$([regex]::Escape($Key))\s*=.*$"
    if ([regex]::IsMatch($head, $pattern)) {
        $head = [regex]::Replace($head, $pattern, $line, 1)
    } else {
        $head = $head.TrimEnd() + "`r`n" + $line + "`r`n"
    }
    return $head.TrimEnd() + $tail
}

function Remove-TopLevelKey {
    param([string] $Text, [string] $Key)
    $firstTable = $Text.IndexOf("`n[")
    if ($firstTable -ge 0) {
        $head = $Text.Substring(0, $firstTable)
        $tail = $Text.Substring($firstTable)
    } else {
        $head = $Text
        $tail = ""
    }
    $pattern = "(?m)^\s*$([regex]::Escape($Key))\s*=.*\r?\n?"
    $head = [regex]::Replace($head, $pattern, "")
    return $head.TrimEnd() + $tail
}

function Upsert-ApimasterProvider {
    param([string] $Text, [string] $ProviderBaseUrl, [bool] $UseChat)
    $wireApi = if ($UseChat) { "chat" } else { "responses" }
    $block = @"

[model_providers.apimaster]
name = "apimaster"
base_url = "$ProviderBaseUrl"
wire_api = "$wireApi"
requires_openai_auth = true
"@
    $pattern = "(?ms)^\[model_providers\.apimaster\]\r?\n.*?(?=^\[|\z)"
    if ([regex]::IsMatch($Text, $pattern)) {
        return [regex]::Replace($Text, $pattern, $block.TrimStart() + "`r`n", 1)
    }
    return $Text.TrimEnd() + "`r`n" + $block + "`r`n"
}

function Switch-ToApimaster {
    if (!(Test-Path $ConfigPath)) {
        New-Item -ItemType File -Path $ConfigPath -Force | Out-Null
    }
    Backup-Current

    $currentConfig = Get-Content -Raw -LiteralPath $ConfigPath
    $currentProvider = Get-TopLevelValue -Text $currentConfig -Key "model_provider"
    if ($currentProvider -ne "apimaster") {
        Save-OfficialProfile
    }

    if (!$ApiKey) {
        if (Test-Path $ApimasterAuthPath) {
            $saved = Get-Content -Raw -LiteralPath $ApimasterAuthPath | ConvertFrom-Json
            $ApiKey = $saved.OPENAI_API_KEY
        }
    }
    if (!$ApiKey) {
        $secure = Read-Host (T "pasteKey") -AsSecureString
        $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure)
        try {
            $ApiKey = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
        } finally {
            [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
        }
    }
    if (!$ApiKey) {
        throw (T "keyRequired")
    }

    $auth = [ordered]@{ OPENAI_API_KEY = $ApiKey }
    $authJson = $auth | ConvertTo-Json -Depth 4
    Write-Utf8NoBom -Path $AuthPath -Value $authJson
    Write-Utf8NoBom -Path $ApimasterAuthPath -Value $authJson

    $updated = $currentConfig
    $updated = Set-TopLevelString -Text $updated -Key "model_provider" -Value "apimaster"
    $updated = Set-TopLevelString -Text $updated -Key "model" -Value $Model
    $updated = Set-TopLevelString -Text $updated -Key "model_reasoning_effort" -Value "high"
    $updated = Upsert-ApimasterProvider -Text $updated -ProviderBaseUrl $BaseUrl -UseChat ([bool]$ChatFallback)
    Write-Utf8NoBom -Path $ConfigPath -Value $updated

    Write-Host (T "switchedApimaster" $Model, $BaseUrl)
    Repair-DesktopHistoryHints
    Write-Host (T "historyUntouched")
}

function Switch-ToOfficial {
    Backup-Current
    if (Test-Path $OfficialConfigPath) {
        Copy-Item -LiteralPath $OfficialConfigPath -Destination $ConfigPath -Force
    } else {
        $text = if (Test-Path $ConfigPath) { Get-Content -Raw -LiteralPath $ConfigPath } else { "" }
        $text = Remove-TopLevelKey -Text $text -Key "model_provider"
        $text = Set-TopLevelString -Text $text -Key "model" -Value "gpt-5.5"
        Write-Utf8NoBom -Path $ConfigPath -Value $text
    }

    if (Test-Path $OfficialAuthPath) {
        Copy-Item -LiteralPath $OfficialAuthPath -Destination $AuthPath -Force
    } else {
        Write-Warning (T "officialAuthMissing")
    }

    Write-Host (T "switchedOfficial")
    Repair-DesktopHistoryHints
    Write-Host (T "historyUntouched")
}

function Show-Status {
    $config = if (Test-Path $ConfigPath) { Get-Content -Raw -LiteralPath $ConfigPath } else { "" }
    $provider = Get-TopLevelValue -Text $config -Key "model_provider"
    $modelName = Get-TopLevelValue -Text $config -Key "model"
    if (!$modelName) { $modelName = "" }
    $authMode = "missing"
    if (Test-Path $AuthPath) {
        $auth = Get-Content -Raw -LiteralPath $AuthPath | ConvertFrom-Json
        if ($auth.PSObject.Properties.Name -contains "auth_mode") {
            $authMode = $auth.auth_mode
        } elseif ($auth.PSObject.Properties.Name -contains "OPENAI_API_KEY") {
            $authMode = "apikey"
        } else {
            $authMode = "unknown"
        }
    }
    $providerLabel = if ($provider) { $provider } else { "official/default" }
    Write-Host (T "providerStatus" $providerLabel)
    Write-Host (T "modelStatus" $modelName)
    Write-Host (T "authStatus" $authMode)
    Write-Host (T "backupStatus" $StateDir)
}

function Test-Apimaster {
    if (!$ApiKey) {
        if (Test-Path $ApimasterAuthPath) {
            $saved = Get-Content -Raw -LiteralPath $ApimasterAuthPath | ConvertFrom-Json
            $ApiKey = $saved.OPENAI_API_KEY
        } elseif (Test-Path $AuthPath) {
            $saved = Get-Content -Raw -LiteralPath $AuthPath | ConvertFrom-Json
            $ApiKey = $saved.OPENAI_API_KEY
        }
    }
    if (!$ApiKey) {
        throw (T "noApimasterKey")
    }
    $headers = @{ Authorization = "Bearer $ApiKey" }
    $resp = Invoke-RestMethod -Uri "$BaseUrl/models" -Headers $headers -Method Get
    $ids = @($resp.data | Select-Object -First 10 -ExpandProperty id)
    Write-Host (T "modelsOk")
    $ids | ForEach-Object { Write-Host " - $_" }
}

Ensure-StateDir
switch ($Mode) {
    "apimaster" { Switch-ToApimaster }
    "official" { Switch-ToOfficial }
    "save-official" { Save-OfficialProfile; Write-Host (T "savedOfficial") }
    "test" { Test-Apimaster }
    "repair-history" { Repair-DesktopHistoryHints }
    default { Show-Status }
}
