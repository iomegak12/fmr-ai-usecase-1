# Usage: scripts/test.ps1 [goal|txn|gateway|all ...]
#
# Runs the unit tests only, without coverage gates or lint:
#   goal     Maven test phase (JUnit, Mockito, AssertJ)
#   txn      pytest, with coverage collection turned off
#   gateway  busted, in the gateway test image
# With no project, tests all three. Unit tests start no database, Redis or
# network service. Use scripts/coverage.ps1 to enforce the coverage gates.

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
            Write-Info 'goal: unit tests'
            Invoke-GoalMaven @('-Dspotless.check.skip=true', '-Djacoco.skip=true', 'test')
        }
        'txn' {
            Write-Info 'txn: unit tests'
            Invoke-TxnUv @('run', '--locked', 'pytest', '--no-cov')
        }
        'gateway' {
            Write-Info 'gateway: unit tests'
            Invoke-GatewaySpec 'busted --no-coverage'
        }
    }
}
Write-Info "tests passed: $($projects -join ' ')"
