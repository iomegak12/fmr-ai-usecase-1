# Usage: scripts/lint.ps1 [goal|txn|gateway|all ...]
#
# Runs the lint and format checks without changing any file:
#   goal     Spotless check (google-java-format)
#   txn      Ruff check and Ruff format --check
#   gateway  luacheck, in the gateway test image
# With no project, checks all three. Exits non-zero on the first failure.

param(
    [switch]$Help,
    [Parameter(ValueFromRemainingArguments = $true)][string[]]$Project
)
. (Join-Path $PSScriptRoot 'lib/common.ps1')
if ($Help -or $Project -contains '--help') { Show-Usage $PSCommandPath; exit 0 }
$projects = Select-Project $PSCommandPath @('goal', 'txn', 'gateway') $Project

foreach ($name in $projects) {
    switch ($name) {
        'goal' {
            Write-Info 'goal: Spotless check'
            Invoke-GoalMaven @('spotless:check')
        }
        'txn' {
            Write-Info 'txn: Ruff check and format check'
            Invoke-TxnUv @('run', '--locked', 'ruff', 'check', '.')
            Invoke-TxnUv @('run', '--locked', 'ruff', 'format', '--check', '.')
        }
        'gateway' {
            Write-Info 'gateway: luacheck'
            Invoke-GatewaySpec 'luacheck lua spec'
        }
    }
}
Write-Info "lint passed: $($projects -join ' ')"
