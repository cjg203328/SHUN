param(
    [string]$ConfigPath = "$env:USERPROFILE\.openclaw\openclaw.json",
    [string]$SessionsPath = "$env:USERPROFILE\.openclaw\agents\main\sessions\sessions.json",
    [string]$BaseUrl = "http://20.204.239.211:8317/v1",
    [string]$ApiKey = "bilonzask"
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $ConfigPath)) {
    throw "Config file not found: $ConfigPath"
}

$configBackup = "{0}.bak.{1}" -f $ConfigPath, (Get-Date -Format "yyyyMMdd-HHmmss")
Copy-Item -LiteralPath $ConfigPath -Destination $configBackup -Force

$config = Get-Content -LiteralPath $ConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json

if (-not $config.models) {
    $config | Add-Member -NotePropertyName models -NotePropertyValue ([pscustomobject]@{})
}
$config.models.mode = "merge"

if (-not $config.models.PSObject.Properties["providers"]) {
    $config.models | Add-Member -NotePropertyName providers -NotePropertyValue ([pscustomobject]@{})
}

$relayProvider = [pscustomobject]@{
    baseUrl = $BaseUrl
    apiKey = $ApiKey
    auth = "api-key"
    api = "openai-completions"
    models = @(
        [pscustomobject]@{
            id = "gpt-5.4"
            name = "GPT-5.4"
            reasoning = $true
            input = @("text", "image")
            cost = [pscustomobject]@{
                input = 0
                output = 0
                cacheRead = 0
                cacheWrite = 0
            }
            contextWindow = 272000
            maxTokens = 128000
            compat = [pscustomobject]@{
                supportsDeveloperRole = $true
                supportsReasoningEffort = $true
                supportsTools = $true
                maxTokensField = "max_tokens"
            }
        }
    )
}

$config.models.providers | Add-Member -NotePropertyName relay -NotePropertyValue $relayProvider -Force

if (-not $config.agents) {
    $config | Add-Member -NotePropertyName agents -NotePropertyValue ([pscustomobject]@{})
}
if (-not $config.agents.defaults) {
    $config.agents | Add-Member -NotePropertyName defaults -NotePropertyValue ([pscustomobject]@{})
}

$config.agents.defaults.model = [pscustomobject]@{
    primary = "relay/gpt-5.4"
}

$config.agents.defaults.models = [pscustomobject]@{
    "relay/gpt-5.4" = [pscustomobject]@{
        alias = "GPT"
        params = [pscustomobject]@{
            max_tokens = 4096
        }
    }
}

if ($config.env -and $config.env.vars -and $config.env.vars.PSObject.Properties["OPENROUTER_API_KEY"]) {
    $config.env.vars.PSObject.Properties.Remove("OPENROUTER_API_KEY")
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
    PrimaryModel = "relay/gpt-5.4"
    RelayBaseUrl = $BaseUrl
    SessionsBackupPath = if ($sessionBackup) { $sessionBackup } else { "" }
    ClearedSessionOverrides = $clearedSessions
} | Format-List
