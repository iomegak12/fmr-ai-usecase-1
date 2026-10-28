# Usage: scripts/restore.ps1 goal_db|transaction_db FILE
#
# Restores a pg_dump custom-format file (from scripts/backup.ps1) into a
# database of the running root Compose stack. This REPLACES the database's
# current contents: pg_restore --clean --if-exists --single-transaction, so a
# failed restore leaves the database unchanged. The file must be a backup of
# that same database; a dump of the other database is refused.
#
# The database's own service (goal-service or transaction-service) is stopped
# for the restore and started again afterwards, even if the restore fails.
# Restoring one database does not roll back the other; restore both from the
# same day to keep goal balances and transaction history consistent.

param(
    [switch]$Help,
    [Parameter(ValueFromRemainingArguments = $true)][string[]]$Arguments
)
. (Join-Path $PSScriptRoot 'lib/common.ps1')
if ($Help -or $Arguments -contains '--help') { Show-Usage $PSCommandPath; exit 0 }
if (-not $Arguments -or $Arguments.Count -ne 2 -or -not $Arguments[0] -or -not $Arguments[1]) {
    Stop-Usage $PSCommandPath 'name a database and a backup file'
}
$db = $Arguments[0]
$file = $Arguments[1]
switch ($db) {
    'goal_db' { $app = 'goal-service' }
    'transaction_db' { $app = 'transaction-service' }
    default { Stop-Usage $PSCommandPath "unknown database '$db' (expected goal_db or transaction_db)" }
}
if (-not (Test-Path -LiteralPath $file -PathType Leaf)) { Stop-Script "backup file not found: $file" }
$file = (Resolve-Path -LiteralPath $file).Path
$service = ($db -replace '_db$', '') + '-db'
$compose = @('compose', '--progress', 'quiet', '-f', $ComposeFileRoot)
$temp = '/tmp/kalash-restore.dump'
if (-not (& docker @compose ps --status running -q $service)) {
    Stop-Script "$service is not running; start the stack with 'make up'"
}

Write-Info "${db}: copying $file into $service"
Invoke-Native 'docker' ($compose + @('cp', $file, "${service}:$temp"))
function Remove-Copy { & docker @compose exec -T $service rm -f $temp | Out-Null }
$previous = $ErrorActionPreference
$ErrorActionPreference = 'Continue'
$listing = (& docker @compose exec -T $service pg_restore --list $temp 2>$null) -join "`n"
$listed = $LASTEXITCODE -eq 0
$ErrorActionPreference = $previous
if (-not $listed) {
    Remove-Copy
    Stop-Script "$file is not a pg_dump custom-format backup"
}
# Refuse a dump of the other database, which would add its tables here.
$targetDb = ((& docker @compose exec -T $service printenv POSTGRES_DB) -join '').Trim()
$sourceDb = 'unknown'
if ($listing -match 'dbname: (\S+)') { $sourceDb = $Matches[1] }
if ($sourceDb -ne $targetDb) {
    Remove-Copy
    Stop-Script "$file is a backup of '$sourceDb', not '$targetDb'"
}

Write-Info "stopping $app for the restore"
Invoke-Native 'docker' ($compose + @('stop', $app))
try {
    Write-Info "${db}: restoring (replaces the current contents)"
    Invoke-Native 'docker' ($compose + @('exec', '-T', $service, 'sh', '-c',
            "pg_restore -U `$POSTGRES_USER -d `$POSTGRES_DB --clean --if-exists --single-transaction $temp; s=`$?; rm -f $temp; exit `$s"))
    Write-Info "${db}: restored from $file"
} finally {
    Write-Info "starting $app"
    & docker @compose start $app
}
