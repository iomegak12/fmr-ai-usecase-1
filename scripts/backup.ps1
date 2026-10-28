# Usage: scripts/backup.ps1 [goal_db|transaction_db|all ...]
#
# Backs up databases of the running root Compose stack (LLD Section 29) with
# pg_dump's custom format to BACKUP_DIR/<db>/<YYYY-MM-DD>.dump. A second backup
# on the same day replaces that day's file. Each dump is checked with
# pg_restore --list before it is kept. Dumps older than BACKUP_RETENTION_DAYS
# are then deleted. With no database, backs up both.
#
# Settings come from the environment, then the root .env:
#   BACKUP_DIR             default ./backups (relative to the repository root)
#   BACKUP_RETENTION_DAYS  default 7
# Schedule it with host cron or Task Scheduler (daily at 02:00 IST in the LLD).

param(
    [switch]$Help,
    [Parameter(ValueFromRemainingArguments = $true)][string[]]$Database
)
. (Join-Path $PSScriptRoot 'lib/common.ps1')
if ($Help -or $Database -contains '--help') { Show-Usage $PSCommandPath; exit 0 }
$databases = Select-Project $PSCommandPath @('goal_db', 'transaction_db') $Database

$backupDir = Get-KalashSetting 'BACKUP_DIR' './backups'
$retention = Get-KalashSetting 'BACKUP_RETENTION_DAYS' '7'
if ($retention -notmatch '^[1-9][0-9]*$') { Stop-Script 'BACKUP_RETENTION_DAYS must be a whole number of days' }
if (-not [IO.Path]::IsPathRooted($backupDir)) { $backupDir = Join-Path $KalashRoot $backupDir }
$backupDir = [IO.Path]::GetFullPath($backupDir)
$compose = @('compose', '--progress', 'quiet', '-f', $ComposeFileRoot)
$today = Get-Date -Format 'yyyy-MM-dd'
$temp = '/tmp/kalash-backup.dump'

foreach ($db in $databases) {
    $service = ($db -replace '_db$', '') + '-db'
    if (-not (& docker @compose ps --status running -q $service)) {
        Stop-Script "$service is not running; start the stack with 'make up'"
    }
    $targetDir = Join-Path $backupDir $db
    $target = Join-Path $targetDir "$today.dump"
    New-Item -ItemType Directory -Force -Path $targetDir | Out-Null
    Write-Info "${db}: pg_dump from $service"
    Invoke-Native 'docker' ($compose + @('exec', '-T', $service, 'sh', '-c',
            "pg_dump -U `$POSTGRES_USER -d `$POSTGRES_DB -Fc -f $temp && pg_restore --list $temp >/dev/null"))
    Invoke-Native 'docker' ($compose + @('cp', "${service}:$temp", "$target.partial"))
    Invoke-Native 'docker' ($compose + @('exec', '-T', $service, 'rm', '-f', $temp))
    Move-Item -LiteralPath "$target.partial" -Destination $target -Force
    Write-Info "${db}: saved $target ($((Get-Item -LiteralPath $target).Length) bytes)"

    $cutoff = (Get-Date).AddDays(-[int]$retention)
    Get-ChildItem -LiteralPath $targetDir -File -Filter '*.dump' |
        Where-Object { $_.Name -match '^\d{4}-\d{2}-\d{2}\.dump$' -and $_.LastWriteTime -lt $cutoff } |
        ForEach-Object {
            Remove-Item -LiteralPath $_.FullName -Force
            Write-Info "removed expired backup $($_.FullName)"
        }
}
