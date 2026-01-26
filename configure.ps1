# configure.ps1 - Wrapper for setup-notifications.ps1
# Alias for consistency with naming convention
#
# Usage: .\configure.ps1

param()

$SCRIPT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path
$SetupScript = Join-Path $SCRIPT_DIR "setup-notifications.ps1"

if (-not (Test-Path $SetupScript)) {
    Write-Error "Setup script not found: $SetupScript"
    exit 1
}

& $SetupScript @args
