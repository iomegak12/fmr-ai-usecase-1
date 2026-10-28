# Usage: scripts/wait-for-ready.ps1 [-Timeout SECONDS] [URL ...]
#
# Polls each URL every 2 seconds until it answers HTTP 200, and fails if any
# URL is still not ready when the timeout (default 120 seconds) expires.
# With no URL, waits for the full stack's host-published readiness checks:
#   http://localhost/ready        gateway
#   http://localhost:8080/ready   Goal Service
#   http://localhost:8000/ready   Transaction Service

param(
    [switch]$Help,
    [ValidateRange(1, 86400)][int]$Timeout = 120,
    [Parameter(ValueFromRemainingArguments = $true)][string[]]$Url
)
. (Join-Path $PSScriptRoot 'lib/common.ps1')
if ($Help -or $Url -contains '--help') { Show-Usage $PSCommandPath; exit 0 }
if (-not $Url) { $Url = @('http://localhost/ready', 'http://localhost:8080/ready', 'http://localhost:8000/ready') }

function Get-StatusCode([string]$Target) {
    try {
        return [int](Invoke-WebRequest -Uri $Target -UseBasicParsing -TimeoutSec 3 -Method Get).StatusCode
    } catch {
        $response = $null
        if ($_.Exception.PSObject.Properties['Response']) { $response = $_.Exception.Response }
        if ($response) { return [int]$response.StatusCode }
        return 0
    }
}

$deadline = (Get-Date).AddSeconds($Timeout)
foreach ($target in $Url) {
    while (($status = Get-StatusCode $target) -ne 200) {
        if ((Get-Date) -ge $deadline) {
            Stop-Script "$target not ready after ${Timeout}s (last status: $(if ($status) { $status } else { 'none' }))"
        }
        Start-Sleep -Seconds 2
    }
    Write-Info "ready: $target"
}
