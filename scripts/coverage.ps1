# Usage: scripts/coverage.ps1 [goal|txn|gateway|all ...]
#
# Runs the unit tests with coverage and enforces the gates:
#   goal     Maven verify: JaCoCo, at least 80% line coverage
#            report: services/goal-service/target/site/jacoco/index.html
#   txn      pytest-cov, at least 80% line coverage
#            report: services/transaction-service/htmlcov/index.html
#   gateway  busted with luacov; reported, with no gate (D-23)
#            report: gateway/luacov.report.out
# With no project, covers all three.

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
            Write-Info 'goal: tests with the JaCoCo gate'
            Invoke-GoalMaven @('-Dspotless.check.skip=true', 'verify')
        }
        'txn' {
            Write-Info 'txn: tests with the pytest-cov gate'
            Invoke-TxnUv @('run', '--locked', 'pytest', '--cov-report=html')
        }
        'gateway' {
            Write-Info 'gateway: tests with the luacov report'
            Invoke-GatewaySpec 'busted && luacov && sed -n ''/^Summary/,$p'' luacov.report.out'
        }
    }
}
Write-Info "coverage passed: $($projects -join ' ')"
