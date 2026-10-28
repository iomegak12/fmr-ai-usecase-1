# Usage: scripts/setup.ps1
#
# Prepares a development machine:
# 1. Checks the tools. Docker with Compose v2 is required. uv (Transaction
#    Service), GNU Make and Java 25 are reported when missing; without
#    Java 25 the Goal Service builds in Docker instead.
# 2. Copies each missing .env from its .env.example (root, both services and
#    the gateway). Blank GOAL_DB_PASSWORD and TXN_DB_PASSWORD values get a
#    random development password, the same in every file, reusing one already
#    set in an existing .env. Existing .env files are never changed, and
#    passwords are never printed.
# 3. Installs the Transaction Service's locked dependencies (uv sync --locked).

param(
    [switch]$Help,
    [Parameter(ValueFromRemainingArguments = $true)][string[]]$Rest
)
. (Join-Path $PSScriptRoot 'lib/common.ps1')
if ($Help -or $Rest -contains '--help') { Show-Usage $PSCommandPath; exit 0 }
if ($Rest) { Stop-Usage $PSCommandPath 'setup takes no arguments' }

$errors = 0
function Write-Report([string]$Name, [string]$Status) { Write-Host ('  {0,-10} {1}' -f $Name, $Status) }
function Test-Tool([string]$Name) { return [bool](Get-Command $Name -ErrorAction SilentlyContinue) }

# Runs a native command for its output only; a failure returns $null.
function Get-NativeOutput([string]$Command, [string[]]$Arguments) {
    $previous = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $output = & $Command @Arguments 2>$null
        if ($LASTEXITCODE -ne 0) { return $null }
        return (@($output) -join "`n").Trim()
    } finally {
        $ErrorActionPreference = $previous
    }
}

Write-Info 'Checking tools'
if (Test-Tool 'docker') {
    Write-Report 'docker' "ok ($(Get-NativeOutput 'docker' @('version', '--format', '{{.Client.Version}}')))"
    $composeVersion = Get-NativeOutput 'docker' @('compose', 'version', '--short')
    if ($composeVersion) {
        Write-Report 'compose' "ok ($composeVersion)"
    } else {
        Write-Report 'compose' 'MISSING: Docker Compose v2 is required'
        $errors++
    }
    if ($null -eq (Get-NativeOutput 'docker' @('info', '--format', '{{.ServerVersion}}'))) {
        Write-Report 'daemon' "not running: start Docker before 'make up' or the tests"
    }
} else {
    Write-Report 'docker' 'MISSING: Docker is required (images, stack, gateway tests)'
    $errors++
}
if (Test-Tool 'uv') {
    Write-Report 'uv' "ok ($((Get-NativeOutput 'uv' @('--version')) -replace '^uv\s+(\S+).*$', '$1'))"
} else {
    Write-Report 'uv' 'missing: needed for Transaction lint, tests and host runs'
}
if (Test-Tool 'make') {
    Write-Report 'make' "ok ($((Get-NativeOutput 'make' @('--version')) -split "`n" | Select-Object -First 1))"
} else {
    Write-Report 'make' 'missing: run the scripts in scripts/ directly'
}
$java = Get-JavaMajor
if ($java -ge 25) {
    Write-Report 'java' "ok ($java)"
} else {
    $found = if ($java) { $java } else { 'none' }
    Write-Report 'java' "Java 25 not found (found $found): Goal builds and runs use Docker"
}

Write-Info 'Creating missing .env files'
$envDirs = @($KalashRoot, $GoalDir, $TxnDir, $GatewayDir)

# Returns a password already set in any existing .env, or a new random one.
function Get-Password([string]$Key) {
    foreach ($dir in $envDirs) {
        $values = Read-DotEnv (Join-Path $dir '.env')
        if ($values.Contains($Key) -and $values[$Key]) { return $values[$Key] }
    }
    $bytes = New-Object byte[] 16
    [Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($bytes)
    return -join ($bytes | ForEach-Object { $_.ToString('x2') })
}
$passwords = @{
    'GOAL_DB_PASSWORD' = Get-Password 'GOAL_DB_PASSWORD'
    'TXN_DB_PASSWORD' = Get-Password 'TXN_DB_PASSWORD'
}

$utf8 = New-Object Text.UTF8Encoding($false)
foreach ($dir in $envDirs) {
    $name = $dir.Substring($KalashRoot.Length).TrimStart('\', '/').Replace('\', '/')
    $name = if ($name) { "$name/.env" } else { '.env' }
    $target = Join-Path $dir '.env'
    if (Test-Path -LiteralPath $target) {
        Write-Report 'kept' "$name (unchanged)"
        continue
    }
    $lines = foreach ($line in Get-Content -LiteralPath (Join-Path $dir '.env.example')) {
        if ($line -match '^(GOAL_DB_PASSWORD|TXN_DB_PASSWORD)=$') { $line + $passwords[$Matches[1]] } else { $line }
    }
    $temporary = "$target.tmp"
    [IO.File]::WriteAllText($temporary, (($lines -join "`n") + "`n"), $utf8)
    if (-not $OnWindows) { & chmod 600 $temporary }
    Move-Item -LiteralPath $temporary -Destination $target
    Write-Report 'created' $name
}

if (Test-Tool 'uv') {
    Write-Info 'Installing Transaction Service dependencies'
    Invoke-TxnUv @('sync', '--locked')
}

if ($errors -gt 0) { Stop-Script "$errors required tool(s) missing" }
Write-Info "Setup finished. Next: 'make up' for the full stack, or 'make help'."
