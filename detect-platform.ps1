# detect-platform.ps1 - Cross-platform launcher for PortableRalph (PowerShell version)
# Automatically detects OS and calls appropriate script version
#
# Usage:
#   .\detect-platform.ps1 <script-name> [args...]
#
# Examples:
#   .\detect-platform.ps1 ralph.ps1 .\my-plan.md build
#   .\detect-platform.ps1 notify.ps1 "Test message"
#
# This launcher:
#   - Detects Windows/Linux/macOS
#   - Calls .ps1 scripts on Windows
#   - Calls .sh scripts on Unix-like systems (via bash/sh)
#   - Passes all arguments to the target script

param(
    [Parameter(Position=0, Mandatory=$true)]
    [string]$ScriptName,

    [Parameter(Position=1, ValueFromRemainingArguments=$true)]
    [string[]]$Arguments
)

$ErrorActionPreference = "Stop"

# Get the directory where this script is located
$RalphDir = Split-Path -Parent $MyInvocation.MyCommand.Path

# Source platform utilities if available
$PlatformUtilsPath = Join-Path $RalphDir "lib\platform-utils.ps1"
if (Test-Path $PlatformUtilsPath) {
    . $PlatformUtilsPath
}

# Detect operating system
function Get-OperatingSystem {
    if ($IsWindows -or $env:OS -match "Windows") {
        return "Windows"
    }
    elseif ($IsLinux) {
        # Check for WSL
        if (Test-Path "/proc/version") {
            $version = Get-Content "/proc/version" -ErrorAction SilentlyContinue
            if ($version -match "microsoft") {
                return "WSL"
            }
        }
        return "Linux"
    }
    elseif ($IsMacOS) {
        return "macOS"
    }
    else {
        return "Unknown"
    }
}

# Detect platform
$OS = Get-OperatingSystem
Write-Host "Detected OS: $OS"

# Determine which script to execute
switch ($OS) {
    "Windows" {
        # Windows: use PowerShell scripts
        $ScriptPath = Join-Path $RalphDir $ScriptName

        if (-not (Test-Path $ScriptPath)) {
            Write-Error "Error: Script not found: $ScriptPath"
            exit 1
        }

        # Execute the PowerShell script
        & $ScriptPath @Arguments
        exit $LASTEXITCODE
    }

    { $_ -in "Linux", "macOS", "WSL" } {
        # Unix-like systems: use .sh scripts
        # Convert .ps1 to .sh
        $ShScript = $ScriptName -replace '\.ps1$', '.sh'
        $ScriptPath = Join-Path $RalphDir $ShScript

        if (-not (Test-Path $ScriptPath)) {
            Write-Error "Error: Shell script not found: $ScriptPath"
            Write-Error "Unix support requires shell script versions"
            exit 1
        }

        # Find bash or sh
        $BashPath = (Get-Command bash -ErrorAction SilentlyContinue).Source
        if (-not $BashPath) {
            $BashPath = (Get-Command sh -ErrorAction SilentlyContinue).Source
        }

        if (-not $BashPath) {
            Write-Error "Error: bash or sh not found in PATH"
            Write-Error "Install bash or use Windows PowerShell scripts"
            exit 1
        }

        # Make script executable (if chmod available)
        $ChmodPath = (Get-Command chmod -ErrorAction SilentlyContinue).Source
        if ($ChmodPath) {
            & $ChmodPath "+x" $ScriptPath 2>$null
        }

        # Execute via bash
        & $BashPath $ScriptPath @Arguments
        exit $LASTEXITCODE
    }

    default {
        Write-Error "Error: Unsupported operating system: $OS"
        Write-Error "Supported: Windows, Linux, macOS, WSL"
        exit 1
    }
}
