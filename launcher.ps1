# launcher.ps1 - Auto-detect launcher for PortableRalph (Windows/PowerShell)
# Detects OS and launches appropriate script
#
# Usage:
#   .\launcher.ps1 ralph <args>
#   .\launcher.ps1 update <args>
#   .\launcher.ps1 notify <args>
#   .\launcher.ps1 monitor <args>

param(
    [Parameter(Position=0)]
    [string]$Command,

    [Parameter(ValueFromRemainingArguments=$true)]
    [string[]]$Arguments
)

$ErrorActionPreference = "Stop"

# Get the directory where this script is located
$SCRIPT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path

# Source platform utilities
$PlatformUtilsPath = Join-Path $SCRIPT_DIR "lib\platform-utils.ps1"
if (-not (Test-Path $PlatformUtilsPath)) {
    Write-Error "ERROR: Cannot find lib\platform-utils.ps1"
    exit 1
}

. $PlatformUtilsPath

# Show usage if no command provided
if (-not $Command) {
    Write-Host "Usage: $($MyInvocation.MyCommand.Name) <command> [args...]" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Commands:" -ForegroundColor White
    Write-Host "  ralph              - Run PortableRalph"
    Write-Host "  update             - Update PortableRalph"
    Write-Host "  notify             - Send notifications"
    Write-Host "  setup-notifications- Configure notifications"
    Write-Host "  configure          - Configure notifications (alias)"
    Write-Host "  monitor            - Monitor progress"
    Write-Host "  monitor-progress   - Monitor progress (full name)"
    Write-Host "  start-monitor      - Start background monitor"
    Write-Host "  decrypt-env        - Decrypt environment variables"
    Write-Host "  install            - Install PortableRalph"
    Write-Host "  uninstall          - Uninstall PortableRalph"
    Write-Host ""
    Write-Host "Examples:" -ForegroundColor White
    Write-Host "  launcher.ps1 ralph my-plan.md"
    Write-Host "  launcher.ps1 update --check"
    Write-Host "  launcher.ps1 notify test"
    Write-Host ""
    Write-Host "For more info: https://github.com/aaron777collins/portableralph" -ForegroundColor Cyan
    exit 1
}

# Determine which script to run
$ScriptName = switch ($Command) {
    "ralph" { "ralph" }
    "update" { "update" }
    "notify" { "notify" }
    "monitor" { "monitor-progress" }
    "monitor-progress" { "monitor-progress" }
    "setup-notifications" { "setup-notifications" }
    "configure" { "setup-notifications" }
    "start-monitor" { "start-monitor" }
    "decrypt-env" { "decrypt-env" }
    "install" { "install" }
    "uninstall" { "uninstall" }
    default {
        Write-Host "ERROR: Unknown command: $Command" -ForegroundColor Red
        Write-Host ""
        Write-Host "Valid commands:" -ForegroundColor Yellow
        Write-Host "  ralph, update, notify, setup-notifications, configure,"
        Write-Host "  monitor, monitor-progress, start-monitor, decrypt-env,"
        Write-Host "  install, uninstall"
        Write-Host ""
        Write-Host "Run without arguments to see full help." -ForegroundColor Cyan
        exit 1
    }
}

# Detect operating system
$OS = Get-OperatingSystem

# Determine which script variant to use based on OS
$ScriptPath = $null

switch ($OS) {
    "Windows" {
        # On Windows: use PowerShell scripts
        $ScriptPath = Join-Path $SCRIPT_DIR "$ScriptName.ps1"

        if (-not (Test-Path $ScriptPath)) {
            Write-Error "ERROR: PowerShell script not found: $ScriptPath"

            # Fallback to bash script if available (Git Bash/WSL)
            $BashScript = Join-Path $SCRIPT_DIR "$ScriptName.sh"
            if (Test-Path $BashScript) {
                Write-Host "Falling back to bash script..." -ForegroundColor Yellow

                # Try to use bash if available
                if (Get-Command bash -ErrorAction SilentlyContinue) {
                    & bash $BashScript @Arguments
                    exit $LASTEXITCODE
                }
            }

            exit 1
        }
    }

    "WSL" {
        # WSL: prefer bash scripts
        $ScriptPath = Join-Path $SCRIPT_DIR "$ScriptName.sh"

        if (-not (Test-Path $ScriptPath)) {
            Write-Error "ERROR: Bash script not found: $ScriptPath"

            # Fallback to PowerShell script
            $PSScript = Join-Path $SCRIPT_DIR "$ScriptName.ps1"
            if (Test-Path $PSScript) {
                Write-Host "Falling back to PowerShell script..." -ForegroundColor Yellow
                $ScriptPath = $PSScript
            } else {
                exit 1
            }
        }
    }

    { $_ -in @("Linux", "macOS") } {
        # Unix: use bash scripts
        $ScriptPath = Join-Path $SCRIPT_DIR "$ScriptName.sh"

        if (-not (Test-Path $ScriptPath)) {
            Write-Error "ERROR: Bash script not found: $ScriptPath"
            exit 1
        }
    }

    default {
        Write-Error "ERROR: Unsupported operating system: $OS"
        exit 1
    }
}

# Verify script exists
if (-not (Test-Path $ScriptPath)) {
    Write-Host "ERROR: Script not found: $ScriptPath" -ForegroundColor Red
    Write-Host ""
    Write-Host "This could mean:" -ForegroundColor Yellow
    Write-Host "  1. The script file is missing from the installation"
    Write-Host "  2. The installation is incomplete or corrupted"
    Write-Host ""
    Write-Host "Try reinstalling PortableRalph or check the installation directory." -ForegroundColor Cyan
    exit 1
}

# Execute the script
if ($ScriptPath -match '\.ps1$') {
    # PowerShell script
    try {
        & $ScriptPath @Arguments
        exit $LASTEXITCODE
    }
    catch {
        Write-Host "ERROR: Failed to execute PowerShell script: $ScriptPath" -ForegroundColor Red
        Write-Host "Error details: $_" -ForegroundColor Yellow
        exit 1
    }
} elseif ($ScriptPath -match '\.sh$') {
    # Bash script - make executable and run
    if (Get-Command bash -ErrorAction SilentlyContinue) {
        # Make executable (Unix)
        if (Test-IsUnix -or Test-IsWSL) {
            try {
                & chmod +x $ScriptPath 2>$null
            }
            catch {
                # Ignore errors
            }
        }

        # Execute with bash
        try {
            & bash $ScriptPath @Arguments
            exit $LASTEXITCODE
        }
        catch {
            Write-Host "ERROR: Failed to execute bash script: $ScriptPath" -ForegroundColor Red
            Write-Host "Error details: $_" -ForegroundColor Yellow
            exit 1
        }
    } else {
        Write-Host "ERROR: bash not found. Cannot execute: $ScriptPath" -ForegroundColor Red
        Write-Host ""
        Write-Host "To run bash scripts on Windows, you need one of:" -ForegroundColor Yellow
        Write-Host "  - Git Bash (https://git-scm.com/downloads)"
        Write-Host "  - WSL (Windows Subsystem for Linux)"
        Write-Host "  - Cygwin (https://www.cygwin.com/)"
        Write-Host ""
        Write-Host "Alternatively, use the PowerShell version of this script." -ForegroundColor Cyan
        exit 1
    }
} else {
    Write-Host "ERROR: Unknown script type: $ScriptPath" -ForegroundColor Red
    Write-Host "Expected .ps1 or .sh extension" -ForegroundColor Yellow
    exit 1
}
