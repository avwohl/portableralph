#!/bin/bash
# example-usage.sh - Example demonstrating Windows compatibility utilities
# Shows how to write cross-platform scripts using the compatibility libraries

# Load the platform utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/platform-utils.sh"

echo "=================================================="
echo "Cross-Platform Script Example"
echo "=================================================="
echo ""

# 1. Platform Detection
echo "1. Platform Detection"
echo "   ------------------"
OS=$(detect_os)
echo "   Operating System: $OS"

if is_windows_environment; then
    echo "   Environment: Windows (Git Bash, WSL, or Cygwin)"
elif is_unix; then
    echo "   Environment: Unix (Linux or macOS)"
fi

if has_admin_privileges; then
    echo "   Privileges: Administrator/Root"
else
    echo "   Privileges: Regular User"
fi
echo ""

# 2. Path Handling
echo "2. Path Handling"
echo "   -------------"
HOME_DIR=$(get_home_dir)
TEMP_DIR=$(get_temp_dir)
CONFIG_DIR=$(get_config_dir)

echo "   Home directory: $HOME_DIR"
echo "   Temp directory: $TEMP_DIR"
echo "   Config directory: $CONFIG_DIR"

# Example: Convert path if in WSL
if is_wsl; then
    WINDOWS_HOME=$(wsl_to_windows_path "$HOME_DIR")
    echo "   Windows home: $WINDOWS_HOME"
fi
echo ""

# 3. Command Availability
echo "3. Command Availability"
echo "   --------------------"
GREP_CMD=$(get_grep_command)
FIND_CMD=$(get_find_command)
AWK_CMD=$(get_awk_command)

echo "   grep: $GREP_CMD"
echo "   find: $FIND_CMD"
echo "   awk: $AWK_CMD"
echo ""

# 4. File Operations
echo "4. File Operations"
echo "   ---------------"

# Create a temporary test file
TEST_FILE="$TEMP_DIR/compat-example-$$.txt"
cat > "$TEST_FILE" << 'EOF'
This is a test file
Line with ERROR message
Line with WARNING message
Another normal line
Line with error in lowercase
EOF

echo "   Created test file: $TEST_FILE"

# Count lines
LINE_COUNT=$(safe_wc "$TEST_FILE" | awk '{print $1}')
echo "   Line count: $LINE_COUNT"

# Search for pattern
echo "   Searching for 'ERROR'..."
MATCHES=$(safe_grep "ERROR" "$TEST_FILE")
if [ -n "$MATCHES" ]; then
    echo "   Found: $MATCHES"
else
    echo "   No matches found"
fi

# Clean up
rm -f "$TEST_FILE"
echo "   Cleaned up test file"
echo ""

# 5. Process Management
echo "5. Process Management"
echo "   ------------------"
CURRENT_PID=$$
echo "   Current script PID: $CURRENT_PID"

if is_process_running "$CURRENT_PID"; then
    echo "   Current process is running: YES"
fi

# Find bash processes
BASH_PIDS=$(get_pids_by_name "bash" | head -n 3)
if [ -n "$BASH_PIDS" ]; then
    echo "   Sample bash PIDs: $(echo $BASH_PIDS | tr '\n' ' ')"
fi
echo ""

# 6. Lock File Example
echo "6. Lock File Handling"
echo "   ------------------"
LOCK_FILE="$TEMP_DIR/example-lock-$$.lock"

if acquire_lock "$LOCK_FILE"; then
    echo "   Lock acquired: $LOCK_FILE"
    sleep 1
    release_lock "$LOCK_FILE"
    echo "   Lock released"
else
    echo "   Failed to acquire lock"
fi
echo ""

# 7. Environment Variables with Fallbacks
echo "7. Environment Variables"
echo "   ---------------------"
USER_VAR=$(get_env_var "USER" "unknown")
HOME_VAR=$(get_env_var "HOME" "/home/default")
TMP_VAR=$(get_env_var "TMPDIR" "/tmp")

echo "   USER: $USER_VAR"
echo "   HOME: $HOME_VAR"
echo "   TMPDIR: $TMP_VAR"
echo ""

# 8. Platform-Specific Behavior Example
echo "8. Platform-Specific Behavior"
echo "   --------------------------"

# Different behavior based on platform
case "$OS" in
    Windows|WSL)
        echo "   Windows environment detected"
        echo "   - Using Windows-compatible commands"
        echo "   - Path conversion enabled"
        NULL_DEV=$(get_null_device)
        echo "   - Null device: $NULL_DEV"
        ;;
    Linux)
        echo "   Linux environment detected"
        echo "   - Using native Unix commands"
        echo "   - No path conversion needed"
        ;;
    macOS)
        echo "   macOS environment detected"
        echo "   - Using macOS-specific features"
        echo "   - BSD command variants available"
        ;;
esac
echo ""

# 9. Safe Command Wrappers
echo "9. Safe Command Wrappers"
echo "   ---------------------"

# Create temp file with data
DATA_FILE="$TEMP_DIR/data-$$.txt"
cat > "$DATA_FILE" << 'EOF'
apple,red,fruit
banana,yellow,fruit
carrot,orange,vegetable
EOF

echo "   Created data file with 3 lines"

# Use safe_grep to search
FRUIT_COUNT=$(safe_grep "fruit" "$DATA_FILE" | wc -l)
echo "   Fruits found: $FRUIT_COUNT"

# Clean up
rm -f "$DATA_FILE"
echo ""

# 10. Best Practices Summary
echo "10. Best Practices Summary"
echo "    ----------------------"
echo "    ✓ Always check platform before using platform-specific code"
echo "    ✓ Use safe wrappers (safe_grep, safe_find, etc.) for portability"
echo "    ✓ Convert paths when calling Windows executables from WSL/Git Bash"
echo "    ✓ Use get_env_var() for environment variables with fallbacks"
echo "    ✓ Test scripts on multiple platforms when possible"
echo ""

echo "=================================================="
echo "Example completed successfully!"
echo "=================================================="
