param(
    [string]$ConfigPath = "$env:USERPROFILE\.openclaw\openclaw.json",
    [string]$SessionsPath = "$env:USERPROFILE\.openclaw\agents\main\sessions\sessions.json",
    [string]$BaseUrl = "https://api.minimaxi.com/anthropic",
    [string]$ApiKey
)

$ErrorActionPreference = "Stop"

if ([string]::IsNullOrWhiteSpace($ApiKey)) {
    throw "ApiKey is required."
}

if (-not (Test-Path -LiteralPath $ConfigPath)) {
    throw "Config file not found: $ConfigPath"
}

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$configBackup = "{0}.bak.{1}" -f $ConfigPath, $timestamp
Copy-Item -LiteralPath $ConfigPath -Destination $configBackup -Force

$config = Get-Content -LiteralPath $ConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json

if (-not $config.env) {
    $config | Add-Member -NotePropertyName env -NotePropertyValue ([pscustomobject]@{})
}
if (-not $config.env.PSObject.Properties["vars"]) {
    $config.env | Add-Member -NotePropertyName vars -NotePropertyValue ([pscustomobject]@{})
}
$config.env.vars | Add-Member -NotePropertyName MINIMAX_API_KEY -NotePropertyValue $ApiKey -Force

if ($config.env.vars.PSObject.Properties["OPENROUTER_API_KEY"]) {
    $config.env.vars.PSObject.Properties.Remove("OPENROUTER_API_KEY")
}

if (-not $config.models) {
    $config | Add-Member -NotePropertyName models -NotePropertyValue ([pscustomobject]@{})
}
$config.models.mode = "merge"

if (-not $config.models.PSObject.Properties["providers"]) {
    $config.models | Add-Member -NotePropertyName providers -NotePropertyValue ([pscustomobject]@{})
}

$minimaxProvider = [pscustomobject]@{
    baseUrl = $BaseUrl
    apiKey = '${MINIMAX_API_KEY}'
    auth = "api-key"
    api = "anthropic-messages"
    models = @(
        [pscustomobject]@{
            id = "MiniMax-M2.7"
            name = "MiniMax M2.7"
            reasoning = $true
            input = @("text")
            cost = [pscustomobject]@{
                input = 0.3
                output = 1.2
                cacheRead = 0.03
                cacheWrite = 0.12
            }
            contextWindow = 200000
            maxTokens = 8192
        },
        [pscustomobject]@{
            id = "MiniMax-M2.7-highspeed"
            name = "MiniMax M2.7 Highspeed"
            reasoning = $true
            input = @("text")
            cost = [pscustomobject]@{
                input = 0.3
                output = 1.2
                cacheRead = 0.03
                cacheWrite = 0.12
            }
            contextWindow = 200000
            maxTokens = 8192
        }
    )
}

$config.models.providers | Add-Member -NotePropertyName minimax -NotePropertyValue $minimaxProvider -Force

if (-not $config.agents) {
    $config | Add-Member -NotePropertyName agents -NotePropertyValue ([pscustomobject]@{})
}
if (-not $config.agents.defaults) {
    $config.agents | Add-Member -NotePropertyName defaults -NotePropertyValue ([pscustomobject]@{})
}

$config.agents.defaults.model = [pscustomobject]@{
    primary = "minimax/MiniMax-M2.7"
    fallbacks = @("minimax/MiniMax-M2.7-highspeed")
}

$config.agents.defaults.models = [pscustomobject]@{
    "minimax/MiniMax-M2.7" = [pscustomobject]@{
        alias = "MiniMax"
        params = [pscustomobject]@{
            max_tokens = 4096
        }
    }
    "minimax/MiniMax-M2.7-highspeed" = [pscustomobject]@{
        alias = "MiniMaxFast"
        params = [pscustomobject]@{
            max_tokens = 4096
        }
    }
}

if (-not $config.meta) {
    $config | Add-Member -NotePropertyName meta -NotePropertyValue ([pscustomobject]@{})
}
$config.meta.lastTouchedAt = (Get-Date).ToString("o")

$configJson = $config | ConvertTo-Json -Depth 50
[System.IO.File]::WriteAllText($ConfigPath, $configJson, [System.Text.UTF8Encoding]::new($false))

$sessionBackup = $null
$clearedSessions = 0
if (Test-Path -LiteralPath $SessionsPath) {
    $sessionBackup = "{0}.bak.{1}" -f $SessionsPath, $timestamp
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
    PrimaryModel = "minimax/MiniMax-M2.7"
    FallbackModel = "minimax/MiniMax-M2.7-highspeed"
    ProviderBaseUrl = $BaseUrl
    SessionsBackupPath = if ($sessionBackup) { $sessionBackup } else { "" }
    ClearedSessionOverrides = $clearedSessions
} | Format-List
