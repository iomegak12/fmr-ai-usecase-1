# Usage: scripts/clean.ps1 [goal|txn|gateway|all ...]
#
# Removes build output, caches and coverage reports:
#   goal     target/
#   txn      pytest, Ruff and bytecode caches, coverage data and htmlcov/
#   gateway  luacov statistics and report
# With no project, cleans all three. Keeps .env files, the Transaction .venv,
# backups, Docker images and volumes.

param(
    [switch]$Help,
    [Parameter(ValueFromRemainingArguments = $true)][string[]]$Project
)
. (Join-Path $PSScriptRoot 'lib/common.ps1')
if ($Help -or $Project -contains '--help') { Show-Usage $PSCommandPath; exit 0 }
$projects = Select-Project $PSCommandPath @('goal', 'txn', 'gateway') $Project

function Remove-Path([string]$Base, [string[]]$Names) {
    foreach ($name in $Names) {
        $path = Join-Path $Base $name
        if (Test-Path -LiteralPath $path) { Remove-Item -LiteralPath $path -Recurse -Force }
    }
}

foreach ($name in $projects) {
    switch ($name) {
        'goal' {
            Write-Info 'goal: removing target/'
            Remove-Path $GoalDir @('target')
        }
        'txn' {
            Write-Info 'txn: removing caches and coverage output'
            Remove-Path $TxnDir @('.pytest_cache', '.ruff_cache', 'htmlcov', '.coverage', 'coverage.xml')
            Get-ChildItem -LiteralPath $TxnDir -Filter '.coverage.*' -File -Force |
                Remove-Item -Force
            foreach ($tree in @('app', 'tests', 'alembic')) {
                $root = Join-Path $TxnDir $tree
                if (Test-Path -LiteralPath $root) {
                    Get-ChildItem -LiteralPath $root -Directory -Recurse -Force -Filter '__pycache__' |
                        Remove-Item -Recurse -Force
                }
            }
        }
        'gateway' {
            Write-Info 'gateway: removing luacov output'
            Remove-Path $GatewayDir @('luacov.stats.out', 'luacov.report.out')
        }
    }
}
Write-Info "clean finished: $($projects -join ' ')"
