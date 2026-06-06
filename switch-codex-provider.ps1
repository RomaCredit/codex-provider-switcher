param(
    [Parameter(Position = 0)]
    [ValidateSet("apimaster", "official", "status", "test", "save-official", "repair-history")]
    [string] $Mode = "status",

    [string] $ApiKey,
    [string] $Model = "gpt-5.5",
    [string] $BaseUrl = "https://apimaster.ai/v1",
    [string] $CodexHome = (Join-Path $env:USERPROFILE ".codex"),
    [ValidateSet("en", "zh")]
    [string] $Lang = "en",
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

$MessagesJson = @"
{
  "stateDbMissing": {"en": "Codex state DB not found: {0}", "zh": "\u672a\u627e\u5230 Codex \u72b6\u6001\u6570\u636e\u5e93\uff1a{0}"},
  "pythonMissingState": {"en": "Python was not found, so state DB repair was skipped.", "zh": "\u672a\u627e\u5230 Python\uff0c\u5df2\u8df3\u8fc7\u72b6\u6001\u6570\u636e\u5e93\u4fee\u590d\u3002"},
  "sessionsMissing": {"en": "Codex sessions directory not found: {0}", "zh": "\u672a\u627e\u5230 Codex \u4f1a\u8bdd\u76ee\u5f55\uff1a{0}"},
  "pythonMissingSessions": {"en": "Python was not found, so session metadata repair was skipped.", "zh": "\u672a\u627e\u5230 Python\uff0c\u5df2\u8df3\u8fc7\u4f1a\u8bdd\u5143\u6570\u636e\u4fee\u590d\u3002"},
  "globalStateMissing": {"en": "Codex Desktop global state not found: {0}", "zh": "\u672a\u627e\u5230 Codex Desktop \u5168\u5c40\u72b6\u6001\u6587\u4ef6\uff1a{0}"},
  "historyHintsRepaired": {"en": "Repaired Codex Desktop history hints: sessions={0}, added={1}, updated={2}, parse_errors={3}", "zh": "\u5df2\u4fee\u590d Codex Desktop \u5386\u53f2\u63d0\u793a\uff1a\u4f1a\u8bdd\u6570={0}\uff0c\u65b0\u589e={1}\uff0c\u66f4\u65b0={2}\uff0c\u89e3\u6790\u9519\u8bef={3}"},
  "restartCodex": {"en": "Restart Codex Desktop if the sidebar still shows stale project chat lists.", "zh": "\u5982\u679c\u4fa7\u8fb9\u680f\u9879\u76ee\u5bf9\u8bdd\u5217\u8868\u4ecd\u7136\u8fc7\u65e7\uff0c\u8bf7\u91cd\u542f Codex Desktop\u3002"},
  "pasteKey": {"en": "Paste APIMaster API key", "zh": "\u8bf7\u8f93\u5165 APIMaster API key"},
  "keyRequired": {"en": "APIMaster API key is required.", "zh": "\u5fc5\u987b\u63d0\u4f9b APIMaster API key\u3002"},
  "switchedApimaster": {"en": "Switched Codex to APIMaster: model={0}, base_url={1}", "zh": "\u5df2\u5c06 Codex \u5207\u6362\u5230 APIMaster\uff1a\u6a21\u578b={0}\uff0cbase_url={1}"},
  "historyUntouched": {"en": "Conversation history is untouched. Restart Codex Desktop or open a new turn if the app has cached provider settings.", "zh": "\u5bf9\u8bdd\u5185\u5bb9\u672a\u88ab\u5220\u9664\u6216\u6539\u5199\u3002\u5982\u679c\u5e94\u7528\u7f13\u5b58\u4e86 provider \u8bbe\u7f6e\uff0c\u8bf7\u91cd\u542f Codex Desktop \u6216\u6253\u5f00\u4e00\u4e2a\u65b0\u56de\u5408\u3002"},
  "officialAuthMissing": {"en": "No saved official auth profile found. Use Codex login if the official subscription is not active.", "zh": "\u672a\u627e\u5230\u5df2\u4fdd\u5b58\u7684\u5b98\u65b9\u8ba4\u8bc1\u914d\u7f6e\u3002\u5982\u679c\u5b98\u65b9\u8ba2\u9605\u672a\u751f\u6548\uff0c\u8bf7\u5728 Codex \u4e2d\u91cd\u65b0\u767b\u5f55\u3002"},
  "switchedOfficial": {"en": "Switched Codex to official subscription profile.", "zh": "\u5df2\u5c06 Codex \u5207\u6362\u5230\u5b98\u65b9\u8ba2\u9605\u914d\u7f6e\u3002"},
  "providerStatus": {"en": "Codex provider: {0}", "zh": "Codex provider\uff1a{0}"},
  "modelStatus": {"en": "Model: {0}", "zh": "\u6a21\u578b\uff1a{0}"},
  "authStatus": {"en": "Auth mode: {0}", "zh": "\u8ba4\u8bc1\u6a21\u5f0f\uff1a{0}"},
  "backupStatus": {"en": "Switcher backups: {0}", "zh": "\u5207\u6362\u5668\u5907\u4efd\u76ee\u5f55\uff1a{0}"},
  "noApimasterKey": {"en": "No APIMaster API key found. Run: .\\switch-codex-provider.ps1 apimaster -ApiKey YOUR_KEY", "zh": "\u672a\u627e\u5230 APIMaster API key\u3002\u8bf7\u8fd0\u884c\uff1a.\\switch-codex-provider.ps1 apimaster -ApiKey YOUR_KEY"},
  "modelsOk": {"en": "APIMaster /models OK. First models:", "zh": "APIMaster /models \u8bf7\u6c42\u6210\u529f\u3002\u524d\u51e0\u4e2a\u6a21\u578b\uff1a"},
  "savedOfficial": {"en": "Saved current Codex config/auth as official profile.", "zh": "\u5df2\u5c06\u5f53\u524d Codex \u914d\u7f6e\u548c\u8ba4\u8bc1\u4fdd\u5b58\u4e3a\u5b98\u65b9\u914d\u7f6e\u3002"}
}
"@
$Messages = $MessagesJson | ConvertFrom-Json
function T {
    param(
        [Parameter(Mandatory = $true)] [string] $Key,
        [object[]] $Args = @()
    )
    $entryProp = $Messages.PSObject.Properties[$Key]
    if (!$entryProp) { return $Key }
    $entry = $entryProp.Value
    $templateProp = $entry.PSObject.Properties[$Lang]
    if (!$templateProp) { $templateProp = $entry.PSObject.Properties["en"] }
    $template = $templateProp.Value
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
    $env:CODEX_SWITCHER_LANG = $Lang
    $script = @'
import os
import sqlite3
import time

db = os.environ["CODEX_SWITCHER_STATE_DB"]
backup_dir = os.environ["CODEX_SWITCHER_BACKUP_DIR"]
desired_provider = os.environ.get("CODEX_SWITCHER_PROVIDER") or "openai"
lang = os.environ.get("CODEX_SWITCHER_LANG") or "en"
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

if lang == "zh":
    print(
        "宸蹭慨澶?Codex 鐘舵€佹暟鎹簱锛?
        f"cwd_checked={len(rows)}锛宑wd_updated={cwd_updated}锛?
        f"provider={desired_provider}锛宲rovider_updated={provider_updated}锛?
        f"backup={backup}"
    )
else:
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
    $env:CODEX_SWITCHER_LANG = $Lang
    $script = @'
import json
import os
import shutil
import time
from pathlib import Path

sessions_dir = Path(os.environ["CODEX_SWITCHER_SESSIONS_DIR"])
backup_root = Path(os.environ["CODEX_SWITCHER_BACKUP_DIR"])
desired_provider = os.environ.get("CODEX_SWITCHER_PROVIDER") or "openai"
lang = os.environ.get("CODEX_SWITCHER_LANG") or "en"
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

        updated_first = json.dumps(meta, ensure_ascii=False, separators=(",", ":"))
        path.write_text(updated_first + (sep or newline) + rest, encoding="utf-8")
        changed += 1
    except Exception:
        errors += 1

if lang == "zh":
    backup_label = backup_dir if changed else "鏃犻渶澶囦唤"
    print(
        "宸蹭慨澶?Codex 浼氳瘽鍏冩暟鎹細"
        f"checked={checked}锛宑hanged={changed}锛宲rovider={desired_provider}锛?
        f"parse_errors={errors}锛宐ackup_dir={backup_label}"
    )
else:
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
