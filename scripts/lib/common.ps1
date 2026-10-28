# Shared helpers for the Kalash PowerShell scripts. Dot-source this file; do
# not run it.
#
# Sets strict mode, the repository paths and the tool images, and provides
# logging, project selection, .env reading, and the Goal (Maven) and gateway
# (busted/luacheck) runners used by several scripts. Works on Windows
# PowerShell 5.1 and PowerShell 7.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

$script:OnWindows = $env:OS -eq 'Windows_NT'
$script:KalashRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$script:GoalDir = Join-Path $KalashRoot 'services/goal-service'
$script:TxnDir = Join-Path $KalashRoot 'services/transaction-service'
$script:GatewayDir = Join-Path $KalashRoot 'gateway'
$script:ComposeFileRoot = Join-Path $KalashRoot 'docker-compose.yml'

# Same Maven/JDK image as the Goal Dockerfile's build stage.
function Get-Setting([string]$Name, [string]$Default) {
    $value = [Environment]::GetEnvironmentVariable($Name)
    if ($value) { return $value }
    return $Default
}
$script:MavenImage = Get-Setting 'MAVEN_IMAGE' 'maven:3.9.11-eclipse-temurin-25'
$script:GoalMavenCache = Get-Setting 'GOAL_MAVEN_CACHE' 'kalash-goal-maven-cache'
$script:GatewayTestImage = Get-Setting 'GATEWAY_TEST_IMAGE' 'kalash/gateway-test'

function Write-Info([string]$Message) { Write-Host "==> $Message" }
function Write-Warn([string]$Message) { [Console]::Error.WriteLine("warning: $Message") }

function Stop-Script([string]$Message, [int]$Code = 1) {
    [Console]::Error.WriteLine("error: $Message")
    exit $Code
}

# Prints the calling script's header comment (its usage text).
function Show-Usage([string]$ScriptPath) {
    $started = $false
    foreach ($line in Get-Content -LiteralPath $ScriptPath) {
        if ($line -match '^#') {
            $started = $true
            Write-Host ($line -replace '^# ?', '')
        } elseif ($started) {
            break
        }
    }
}

function Stop-Usage([string]$ScriptPath, [string]$Message) {
    [Console]::Error.WriteLine("error: $Message")
    [Console]::Error.WriteLine('')
    Show-Usage $ScriptPath
    exit 2
}

# Runs a native command and stops the script if it fails.
function Invoke-Native([string]$Command, [string[]]$Arguments = @()) {
    & $Command @Arguments
    if ($LASTEXITCODE -ne 0) { Stop-Script "$Command exited with code $LASTEXITCODE" $LASTEXITCODE }
}

# Returns the requested projects, or every allowed project for none or 'all'.
function Select-Project([string]$ScriptPath, [string[]]$Allowed, [string[]]$Requested) {
    if (-not $Requested -or ($Requested.Count -eq 1 -and $Requested[0] -eq 'all')) { return $Allowed }
    foreach ($project in $Requested) {
        if ($Allowed -notcontains $project) {
            Stop-Usage $ScriptPath "unknown project '$project' (expected: $($Allowed -join ' ') or all)"
        }
    }
    return $Requested
}

function ConvertFrom-Quoted([string]$Value) {
    if ($Value -match '^"(.*)"$' -or $Value -match "^'(.*)'$") { return $Matches[1] }
    return $Value
}

# Reads a .env file as text, never evaluating it. Returns an ordered map.
function Read-DotEnv([string]$Path) {
    $values = [ordered]@{}
    if (-not (Test-Path -LiteralPath $Path)) { return $values }
    foreach ($line in Get-Content -LiteralPath $Path) {
        if ($line -match '^\s*(#|$)') { continue }
        if ($line -match '^([A-Za-z_][A-Za-z0-9_]*)=(.*)$') {
            $values[$Matches[1]] = ConvertFrom-Quoted $Matches[2]
        }
    }
    return $values
}

# The environment wins, then the root .env, then the default.
function Get-KalashSetting([string]$Name, [string]$Default) {
    $value = [Environment]::GetEnvironmentVariable($Name)
    if (-not $value) {
        $dotenv = Read-DotEnv (Join-Path $KalashRoot '.env')
        if ($dotenv.Contains($Name)) { $value = $dotenv[$Name] }
    }
    if ($value) { return $value }
    return $Default
}

# Sets each KEY=VALUE in this process's environment. Variables already set
# win, as they do for pydantic-settings. Returns the keys the file defines.
function Import-DotEnv([string]$Path) {
    $values = Read-DotEnv $Path
    foreach ($key in $values.Keys) {
        if ($null -eq [Environment]::GetEnvironmentVariable($key)) {
            [Environment]::SetEnvironmentVariable($key, $values[$key])
        }
    }
    return @($values.Keys)
}

function Get-JavaMajor {
    $java = 'java'
    if ($env:JAVA_HOME) { $java = Join-Path $env:JAVA_HOME 'bin/java' }
    if (-not (Get-Command $java -ErrorAction SilentlyContinue)) { return 0 }
    $previous = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $output = (& $java -version 2>&1 | ForEach-Object { "$_" }) -join "`n"
    } finally {
        $ErrorActionPreference = $previous
    }
    if ($output -match 'version "(\d+)') { return [int]$Matches[1] }
    return 0
}

# host (Java 25+ available) or docker. GOAL_RUNNER=host or docker forces one.
function Get-GoalMode {
    $runner = Get-Setting 'GOAL_RUNNER' 'auto'
    switch ($runner) {
        'host' { return 'host' }
        'docker' { return 'docker' }
        'auto' { if ((Get-JavaMajor) -ge 25) { return 'host' } else { return 'docker' } }
        default { Stop-Script 'GOAL_RUNNER must be auto, host or docker' }
    }
}

# Docker flags for an interactive terminal, when there is one.
function Get-TtyFlag {
    if (-not [Console]::IsInputRedirected -and -not [Console]::IsOutputRedirected) { return @('-it') }
    return @()
}

function Get-MountArgument([string]$Source, [string]$Target) {
    return "type=bind,source=$Source,target=$Target"
}

# Runs the Maven Wrapper with Java 25, on the host or in the Maven image. On
# Linux, files the container writes are handed back to the calling user.
function Invoke-GoalMaven([string[]]$Arguments) {
    if ((Get-GoalMode) -eq 'host') {
        Push-Location $GoalDir
        try {
            if ($OnWindows) { Invoke-Native '.\mvnw.cmd' (@('-B') + $Arguments) }
            else { Invoke-Native 'sh' (@('./mvnw', '-B') + $Arguments) }
        } finally {
            Pop-Location
        }
        return
    }
    $uid = ''
    $gid = ''
    if (-not $OnWindows) {
        $uid = (& id -u)
        $gid = (& id -g)
    }
    Write-Info "Running Maven with Java 25 in $MavenImage (host Java is $(Get-JavaMajor))"
    $command = 'sh ./mvnw -B $*; s=$?; ${HOST_UID:+chown -R $HOST_UID:$HOST_GID target} 2>/dev/null; exit $s'
    Invoke-Native 'docker' (@(
            'run', '--rm', '-e', "HOST_UID=$uid", '-e', "HOST_GID=$gid",
            '--mount', (Get-MountArgument $GoalDir '/workspace'),
            '--mount', "type=volume,source=$GoalMavenCache,target=/root/.m2",
            '-w', '/workspace', $MavenImage, 'sh', '-c', $command, 'sh') + $Arguments)
}

# Runs a shell command in the gateway test image (busted, luacheck, luacov)
# against the working tree, without a network.
function Invoke-GatewaySpec([string]$Command) {
    Write-Info "Building $GatewayTestImage"
    Invoke-Native 'docker' @('build', '--quiet', '--target', 'test', '-t', $GatewayTestImage, $GatewayDir) | Out-Null
    Invoke-Native 'docker' @('run', '--rm', '--network', 'none',
        '--mount', (Get-MountArgument $GatewayDir '/gateway'), $GatewayTestImage, 'sh', '-c', $Command)
}

# Runs uv from the Transaction Service directory.
function Invoke-TxnUv([string[]]$Arguments) {
    if (-not (Get-Command uv -ErrorAction SilentlyContinue)) {
        Stop-Script "uv is required for the Transaction Service; run 'make setup'"
    }
    Push-Location $TxnDir
    try { Invoke-Native 'uv' $Arguments } finally { Pop-Location }
}
