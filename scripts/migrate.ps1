# Usage: scripts/migrate.ps1
#
# Applies the Transaction Service's Alembic migrations (alembic upgrade head)
# to the database in services/transaction-service/.env. Run it before
# 'make run-txn'. The Goal Service needs no step: Flyway migrates goal_db
# when the service starts. In Docker, the Transaction entrypoint migrates.

param(
    [switch]$Help,
    [Parameter(ValueFromRemainingArguments = $true)][string[]]$Rest
)
. (Join-Path $PSScriptRoot 'lib/common.ps1')
if ($Help -or $Rest -contains '--help') { Show-Usage $PSCommandPath; exit 0 }
if ($Rest) { Stop-Usage $PSCommandPath 'migrate takes no arguments' }
if (-not (Test-Path -LiteralPath (Join-Path $TxnDir '.env'))) {
    Stop-Script "services/transaction-service/.env is missing; run 'make setup'"
}

Write-Info 'txn: alembic upgrade head'
Invoke-TxnUv @('run', '--locked', 'alembic', 'upgrade', 'head')
Write-Info 'migrations applied'
