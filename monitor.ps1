# monitor.ps1 - Wrapper for monitor-progress.ps1
# Alias for consistency with naming convention
#
# Usage: .\monitor.ps1 [args]

param()

$SCRIPT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path
$MonitorScript = Join-Path $SCRIPT_DIR "monitor-progress.ps1"

if (-not (Test-Path $MonitorScript)) {
    Write-Error "Monitor script not found: $MonitorScript"
    exit 1
}

& $MonitorScript @args
