$ErrorActionPreference = 'Stop'

Write-Host '== Sunliao Flutter CLI Recovery ==' -ForegroundColor Cyan

$targetNames = @('flutter', 'dart')
$existing = Get-Process -Name $targetNames -ErrorAction SilentlyContinue |
  Sort-Object StartTime

if (-not $existing) {
  Write-Host 'No flutter/dart processes are running.' -ForegroundColor Green
  exit 0
}

Write-Host 'Found running processes:' -ForegroundColor Yellow
$existing |
  Select-Object ProcessName, Id, StartTime |
  Format-Table -AutoSize |
  Out-String |
  Write-Host

$attempt = 1
do {
  $running = Get-Process -Name $targetNames -ErrorAction SilentlyContinue
  if (-not $running) {
    break
  }

  Write-Host "Stopping flutter/dart processes (attempt $attempt)..." -ForegroundColor Yellow
  $running | Stop-Process -Force
  Start-Sleep -Milliseconds 500
  $attempt++
} while ($attempt -le 3)

$remaining = Get-Process -Name $targetNames -ErrorAction SilentlyContinue

if ($remaining) {
  Write-Warning 'Some flutter/dart processes are still running after 3 attempts.'
  $remaining |
    Select-Object ProcessName, Id, StartTime |
    Format-Table -AutoSize |
    Out-String |
    Write-Host
  exit 1
}

Write-Host 'Recovery finished. flutter/dart processes have been cleared.' -ForegroundColor Green
Write-Host 'Recommended next step: rerun only the smallest required flutter command outside the sandbox.' -ForegroundColor Cyan
