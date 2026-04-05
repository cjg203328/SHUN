param(
    [string]$ConfigPath = "$env:USERPROFILE\.openclaw\openclaw.json"
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $ConfigPath)) {
    throw "Config file not found: $ConfigPath"
}

$raw = Get-Content -LiteralPath $ConfigPath -Raw -Encoding UTF8

function Get-FirstMatch {
    param(
        [string]$Content,
        [string]$Pattern,
        [string]$Default = $null
    )

    $match = [regex]::Match($Content, $Pattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
    if ($match.Success) {
        return $match.Groups[1].Value
    }

    return $Default
}

function Get-BoolMatch {
    param(
        [string]$Content,
        [string]$Pattern,
        [bool]$Default
    )

    $value = Get-FirstMatch -Content $Content -Pattern $Pattern
    if ($null -eq $value) {
        return $Default
    }

    return $value.Trim().ToLowerInvariant() -eq "true"
}

function New-OrderedHashtable {
    return [ordered]@{}
}

$openRouterApiKey = Get-FirstMatch -Content $raw -Pattern 'OPENROUTER_API_KEY"\s*:\s*"([^"]+)"'
if ([string]::IsNullOrWhiteSpace($openRouterApiKey)) {
    $openRouterApiKey = Get-FirstMatch -Content $raw -Pattern 'OPENROUTER_API_KEY\s*:\s*"([^"]+)"'
}
if ([string]::IsNullOrWhiteSpace($openRouterApiKey)) {
    throw "Could not recover OPENROUTER_API_KEY from the existing config."
}

$primaryModel = Get-FirstMatch -Content $raw -Pattern '"primary"\s*:\s*"([^"]+)"' -Default 'openrouter/xiaomi/mimo-v2-pro'
$allQuotedModels = [regex]::Matches($raw, '"(openrouter\/[^"]+)"') |
    ForEach-Object { $_.Groups[1].Value } |
    Select-Object -Unique

$fallbackModels = @($allQuotedModels | Where-Object { $_ -ne $primaryModel })

$workspace = Get-FirstMatch -Content $raw -Pattern '"workspace"\s*:\s*"([^"]+)"' -Default "$env:USERPROFILE\.openclaw\workspace"
$gatewayToken = Get-FirstMatch -Content $raw -Pattern '"token"\s*:\s*"([^"]+)"'
if ([string]::IsNullOrWhiteSpace($gatewayToken)) {
    throw "Could not recover gateway.auth.token from the existing config."
}

$gatewayPort = Get-FirstMatch -Content $raw -Pattern '"port"\s*:\s*(\d+)' -Default '18789'
$gatewayBind = Get-FirstMatch -Content $raw -Pattern '"bind"\s*:\s*"([^"]+)"' -Default 'loopback'
$tailscaleMode = Get-FirstMatch -Content $raw -Pattern '"mode"\s*:\s*"([^"]+)"\s*,\s*"resetOnExit"' -Default 'off'
$tailscaleResetOnExit = Get-BoolMatch -Content $raw -Pattern '"resetOnExit"\s*:\s*(true|false)' -Default $false
$dmScope = Get-FirstMatch -Content $raw -Pattern '"dmScope"\s*:\s*"([^"]+)"' -Default 'per-channel-peer'
$toolProfile = Get-FirstMatch -Content $raw -Pattern '"profile"\s*:\s*"([^"]+)"' -Default 'coding'
$wizardLastRunAt = Get-FirstMatch -Content $raw -Pattern '"lastRunAt"\s*:\s*"([^"]+)"'
$wizardLastRunVersion = Get-FirstMatch -Content $raw -Pattern '"lastRunVersion"\s*:\s*"([^"]+)"'
$wizardLastRunCommand = Get-FirstMatch -Content $raw -Pattern '"lastRunCommand"\s*:\s*"([^"]+)"'
$wizardLastRunMode = Get-FirstMatch -Content $raw -Pattern '"lastRunMode"\s*:\s*"([^"]+)"'
$metaLastTouchedVersion = Get-FirstMatch -Content $raw -Pattern '"lastTouchedVersion"\s*:\s*"([^"]+)"'
$metaLastTouchedAt = Get-FirstMatch -Content $raw -Pattern '"lastTouchedAt"\s*:\s*"([^"]+)"'

$config = New-OrderedHashtable

$config.env = [ordered]@{
    vars = [ordered]@{
        OPENROUTER_API_KEY = $openRouterApiKey
    }
}

$config.models = [ordered]@{
    mode = "merge"
}

$defaultAgent = [ordered]@{
    model = if ($fallbackModels.Count -gt 0) {
        [ordered]@{
            primary = $primaryModel
            fallbacks = @($fallbackModels)
        }
    } else {
        [ordered]@{
            primary = $primaryModel
        }
    }
    models = [ordered]@{}
    workspace = $workspace
}

foreach ($modelId in @($primaryModel) + $fallbackModels) {
    if (-not $defaultAgent.models.Contains($modelId)) {
        $defaultAgent.models[$modelId] = [ordered]@{}
    }
}

$config.agents = [ordered]@{
    defaults = $defaultAgent
}

$config.gateway = [ordered]@{
    mode = "local"
    auth = [ordered]@{
        mode = "token"
        token = $gatewayToken
    }
    port = [int]$gatewayPort
    bind = $gatewayBind
    tailscale = [ordered]@{
        mode = $tailscaleMode
        resetOnExit = $tailscaleResetOnExit
    }
}

$config.session = [ordered]@{
    dmScope = $dmScope
}

$config.tools = [ordered]@{
    profile = $toolProfile
}

$wizard = [ordered]@{}
if ($wizardLastRunAt) { $wizard.lastRunAt = $wizardLastRunAt }
if ($wizardLastRunVersion) { $wizard.lastRunVersion = $wizardLastRunVersion }
if ($wizardLastRunCommand) { $wizard.lastRunCommand = $wizardLastRunCommand }
if ($wizardLastRunMode) { $wizard.lastRunMode = $wizardLastRunMode }
if ($wizard.Count -gt 0) {
    $config.wizard = $wizard
}

$meta = [ordered]@{}
if ($metaLastTouchedVersion) { $meta.lastTouchedVersion = $metaLastTouchedVersion }
if ($metaLastTouchedAt) { $meta.lastTouchedAt = $metaLastTouchedAt }
if ($meta.Count -gt 0) {
    $config.meta = $meta
}

$backupPath = "{0}.bak.{1}" -f $ConfigPath, (Get-Date -Format "yyyyMMdd-HHmmss")
Copy-Item -LiteralPath $ConfigPath -Destination $backupPath -Force

$json = $config | ConvertTo-Json -Depth 20
[System.IO.File]::WriteAllText($ConfigPath, $json, [System.Text.UTF8Encoding]::new($false))

[PSCustomObject]@{
    ConfigPath = $ConfigPath
    BackupPath = $backupPath
    PrimaryModel = $primaryModel
    Fallbacks = if ($fallbackModels.Count -gt 0) { ($fallbackModels -join ", ") } else { "" }
} | Format-List
