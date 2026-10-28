# Usage: scripts/format.ps1 [goal|txn|all ...]
#
# Rewrites source files to the project formatting rules:
#   goal  Spotless apply (google-java-format)
#   txn   Ruff import sorting fix, then Ruff format
# With no project, formats both. The gateway has no Lua formatter; luacheck
# (scripts/lint.ps1 gateway) checks its style.

param(
    [switch]$Help,
    [Parameter(ValueFromRemainingArguments = $true)][string[]]$Project
)
. (Join-Path $PSScriptRoot 'lib/common.ps1')
if ($Help -or $Project -contains '--help') { Show-Usage $PSCommandPath; exit 0 }
$projects = Select-Project $PSCommandPath @('goal', 'txn') $Project

foreach ($name in $projects) {
    switch ($name) {
        'goal' {
            Write-Info 'goal: Spotless apply'
            Invoke-GoalMaven @('spotless:apply')
        }
        'txn' {
            Write-Info 'txn: Ruff import sorting and format'
            Invoke-TxnUv @('run', '--locked', 'ruff', 'check', '--select', 'I', '--fix', '.')
            Invoke-TxnUv @('run', '--locked', 'ruff', 'format', '.')
        }
    }
}
Write-Info "format finished: $($projects -join ' ')"
