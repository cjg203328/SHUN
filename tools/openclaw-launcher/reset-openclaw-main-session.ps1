param(
    [string]$SessionsPath = "$env:USERPROFILE\.openclaw\agents\main\sessions\sessions.json",
    [string]$SessionKey = "agent:main:main"
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $SessionsPath)) {
    throw "Sessions file not found: $SessionsPath"
}

$timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
$sessionsBackup = "{0}.bak.{1}" -f $SessionsPath, $timestamp
Copy-Item -LiteralPath $SessionsPath -Destination $sessionsBackup -Force

$sessions = Get-Content -LiteralPath $SessionsPath -Raw -Encoding UTF8 | ConvertFrom-Json
$entry = $sessions.PSObject.Properties[$SessionKey].Value

if ($null -eq $entry) {
    [PSCustomObject]@{
        SessionKey = $SessionKey
        SessionsBackupPath = $sessionsBackup
        SessionEntryRemoved = $false
        SessionLogArchived = $false
        SessionLogArchivePath = ""
    } | Format-List
    exit 0
}

$sessionFile = ""
if ($entry.PSObject.Properties["sessionFile"] -and -not [string]::IsNullOrWhiteSpace($entry.sessionFile)) {
    $sessionFile = [string]$entry.sessionFile
}

$sessions.PSObject.Properties.Remove($SessionKey)
$sessionsJson = $sessions | ConvertTo-Json -Depth 50
[System.IO.File]::WriteAllText($SessionsPath, $sessionsJson, [System.Text.UTF8Encoding]::new($false))

$archived = $false
$archivePath = ""
if ($sessionFile -and (Test-Path -LiteralPath $sessionFile)) {
    $archivePath = "{0}.bak.{1}" -f $sessionFile, $timestamp
    Move-Item -LiteralPath $sessionFile -Destination $archivePath -Force
    $archived = $true
}

[PSCustomObject]@{
    SessionKey = $SessionKey
    SessionsBackupPath = $sessionsBackup
    SessionEntryRemoved = $true
    SessionLogArchived = $archived
    SessionLogArchivePath = $archivePath
} | Format-List
