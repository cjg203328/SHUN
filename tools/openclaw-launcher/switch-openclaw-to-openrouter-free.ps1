param(
    [string]$ConfigPath = "$env:USERPROFILE\.openclaw\openclaw.json",
    [string]$SessionsPath = "$env:USERPROFILE\.openclaw\agents\main\sessions\sessions.json"
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $ConfigPath)) {
    throw "Config file not found: $ConfigPath"
}

$configBackup = "{0}.bak.{1}" -f $ConfigPath, (Get-Date -Format "yyyyMMdd-HHmmss")
Copy-Item -LiteralPath $ConfigPath -Destination $configBackup -Force

$config = Get-Content -LiteralPath $ConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json

if (-not $config.agents) {
    $config | Add-Member -NotePropertyName agents -NotePropertyValue ([pscustomobject]@{})
}
if (-not $config.agents.defaults) {
    $config.agents | Add-Member -NotePropertyName defaults -NotePropertyValue ([pscustomobject]@{})
}

$config.agents.defaults.model = [pscustomobject]@{
    primary = "openrouter/free"
}

$config.agents.defaults.models = [pscustomobject]@{
    "openrouter/free" = [pscustomobject]@{}
}

$config.meta.lastTouchedAt = (Get-Date).ToString("o")

$configJson = $config | ConvertTo-Json -Depth 50
[System.IO.File]::WriteAllText($ConfigPath, $configJson, [System.Text.UTF8Encoding]::new($false))

$sessionBackup = $null
$clearedSessions = 0

if (Test-Path -LiteralPath $SessionsPath) {
    $sessionBackup = "{0}.bak.{1}" -f $SessionsPath, (Get-Date -Format "yyyyMMdd-HHmmss")
    Copy-Item -LiteralPath $SessionsPath -Destination $sessionBackup -Force

    $sessions = Get-Content -LiteralPath $SessionsPath -Raw -Encoding UTF8 | ConvertFrom-Json
    foreach ($property in $sessions.PSObject.Properties) {
        $entry = $property.Value
        $changed = $false

        if ($null -ne $entry.PSObject.Properties["providerOverride"]) {
            $entry.PSObject.Properties.Remove("providerOverride")
            $changed = $true
        }

        if ($null -ne $entry.PSObject.Properties["modelOverride"]) {
            $entry.PSObject.Properties.Remove("modelOverride")
            $changed = $true
        }

        if ($changed) {
            $clearedSessions += 1
        }
    }

    $sessionsJson = $sessions | ConvertTo-Json -Depth 50
    [System.IO.File]::WriteAllText($SessionsPath, $sessionsJson, [System.Text.UTF8Encoding]::new($false))
}

[PSCustomObject]@{
    ConfigPath = $ConfigPath
    ConfigBackupPath = $configBackup
    NewPrimaryModel = "openrouter/free"
    SessionsPath = if (Test-Path -LiteralPath $SessionsPath) { $SessionsPath } else { "" }
    SessionsBackupPath = if ($sessionBackup) { $sessionBackup } else { "" }
    ClearedSessionOverrides = $clearedSessions
} | Format-List
