# Usage: scripts/run.ps1 goal|txn
#
# Runs one service on the host in the foreground with its local profile and
# coloured console logs. Press Ctrl+C to stop it.
#   goal  Loads services/goal-service/.env into the process environment
#         (Spring does not read .env), builds the jar and runs it with
#         Java 25. Without Java 25 it runs in the Maven image instead,
#         publishing GOAL_SERVICE_PORT; a localhost database is then
#         reached through host.docker.internal.
#   txn   uv run python -m app; the service reads its own .env. Apply
#         migrations first with scripts/migrate.ps1.
# The service's database must already be running, for example from
# 'make up' or the project's own compose file.

param(
    [switch]$Help,
    [Parameter(ValueFromRemainingArguments = $true)][string[]]$Service
)
. (Join-Path $PSScriptRoot 'lib/common.ps1')
if ($Help -or $Service -contains '--help') { Show-Usage $PSCommandPath; exit 0 }
if (-not $Service -or $Service.Count -ne 1) { Stop-Usage $PSCommandPath 'name exactly one service' }
$skipChecks = @('-Dmaven.test.skip=true', '-Dspotless.check.skip=true', '-Djacoco.skip=true')

switch ($Service[0]) {
    'goal' {
        $envFile = Join-Path $GoalDir '.env'
        if (-not (Test-Path -LiteralPath $envFile)) {
            Stop-Script "services/goal-service/.env is missing; run 'make setup'"
        }
        $keys = Import-DotEnv $envFile
        if (-not $env:SPRING_PROFILES_ACTIVE) { $env:SPRING_PROFILES_ACTIVE = 'local' }
        if ((Get-GoalMode) -eq 'host') {
            Invoke-GoalMaven (@('-q') + $skipChecks + @('package'))
            $jar = Get-ChildItem -LiteralPath (Join-Path $GoalDir 'target') -Filter 'goal-service-*.jar' |
                Select-Object -First 1
            Write-Info "goal: starting target/$($jar.Name)"
            & java -jar $jar.FullName
            exit $LASTEXITCODE
        }
        if (-not $env:GOAL_DB_HOST -or @('localhost', '127.0.0.1') -contains $env:GOAL_DB_HOST) {
            $env:GOAL_DB_HOST = 'host.docker.internal'
        }
        $port = Get-Setting 'GOAL_SERVICE_PORT' '8080'
        # -e NAME copies the value from this process, so no secret is on the command line.
        $envArgs = @()
        foreach ($key in @($keys) + @('SPRING_PROFILES_ACTIVE', 'GOAL_DB_HOST')) { $envArgs += @('-e', $key) }
        Write-Info "goal: building and starting in $MavenImage on port $port"
        $command = 'sh ./mvnw -B -q $* package && exec java -jar target/goal-service-*.jar'
        & docker (@('run', '--rm') + (Get-TtyFlag) + @('--name', 'kalash-goal-run', '-p', "${port}:${port}",
                '--add-host', 'host.docker.internal:host-gateway') + $envArgs + @(
                '--mount', (Get-MountArgument $GoalDir '/workspace'),
                '--mount', "type=volume,source=$GoalMavenCache,target=/root/.m2",
                '-w', '/workspace', $MavenImage, 'sh', '-c', $command, 'sh') + $skipChecks)
        exit $LASTEXITCODE
    }
    'txn' {
        if (-not (Test-Path -LiteralPath (Join-Path $TxnDir '.env'))) {
            Stop-Script "services/transaction-service/.env is missing; run 'make setup'"
        }
        if (-not (Get-Command uv -ErrorAction SilentlyContinue)) {
            Stop-Script "uv is required for the Transaction Service; run 'make setup'"
        }
        Set-Location $TxnDir
        Write-Info 'txn: starting with uv'
        & uv run --locked python -m app
        exit $LASTEXITCODE
    }
    default { Stop-Usage $PSCommandPath "unknown service '$($Service[0])' (expected goal or txn)" }
}
