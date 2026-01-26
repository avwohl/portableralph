#!/bin/bash
# detect-platform.sh - Cross-platform launcher for PortableRalph
# Automatically detects OS and calls appropriate script version
#
# Usage:
#   ./detect-platform.sh <script-name> [args...]
#
# Examples:
#   ./detect-platform.sh ralph.sh ./my-plan.md build
#   ./detect-platform.sh notify.sh "Test message"
#
# This launcher:
#   - Detects Linux/macOS/Windows/WSL
#   - Calls .sh scripts on Unix-like systems
#   - Calls .ps1 scripts on Windows (via PowerShell)
#   - Passes all arguments to the target script

set -euo pipefail

RALPH_DIR="$(cd "$(dirname "$0")" && pwd)"

# Source platform utilities if available
if [ -f "$RALPH_DIR/lib/platform-utils.sh" ]; then
    source "$RALPH_DIR/lib/platform-utils.sh"
fi

# Detect operating system
detect_os() {
    case "$(uname -s)" in
        Linux*)
            # Check if running under WSL
            if grep -qi microsoft /proc/version 2>/dev/null; then
                echo "WSL"
            else
                echo "Linux"
            fi
            ;;
        Darwin*)
            echo "macOS"
            ;;
        CYGWIN*|MINGW*|MSYS*)
            echo "Windows"
            ;;
        *)
            echo "Unknown"
            ;;
    esac
}

# Get the script to execute
SCRIPT_NAME="${1:-}"
if [ -z "$SCRIPT_NAME" ]; then
    echo "Error: No script specified"
    echo "Usage: $0 <script-name> [args...]"
    exit 1
fi

shift  # Remove script name from arguments

# Detect platform
OS=$(detect_os)
echo "Detected OS: $OS"

# Determine which script to execute
case "$OS" in
    Linux|macOS|WSL)
        # Unix-like systems: use .sh scripts
        SCRIPT_PATH="$RALPH_DIR/$SCRIPT_NAME"

        if [ ! -f "$SCRIPT_PATH" ]; then
            echo "Error: Script not found: $SCRIPT_PATH"
            exit 1
        fi

        if [ ! -x "$SCRIPT_PATH" ]; then
            echo "Error: Script not executable: $SCRIPT_PATH"
            echo "Run: chmod +x $SCRIPT_PATH"
            exit 1
        fi

        # Execute the shell script
        exec "$SCRIPT_PATH" "$@"
        ;;

    Windows)
        # Windows: use PowerShell scripts
        # Convert .sh to .ps1
        PS_SCRIPT="${SCRIPT_NAME%.sh}.ps1"
        SCRIPT_PATH="$RALPH_DIR/$PS_SCRIPT"

        if [ ! -f "$SCRIPT_PATH" ]; then
            echo "Error: PowerShell script not found: $SCRIPT_PATH"
            echo "Windows support requires PowerShell versions of scripts"
            exit 1
        fi

        # Execute via PowerShell
        # Use -ExecutionPolicy Bypass to avoid execution policy issues
        powershell.exe -ExecutionPolicy Bypass -File "$SCRIPT_PATH" "$@"
        ;;

    *)
        echo "Error: Unsupported operating system: $OS"
        echo "Supported: Linux, macOS, Windows (Git Bash/MSYS), WSL"
        exit 1
        ;;
esac
