#!/bin/bash
# test-compat.sh - Test Windows compatibility utilities
# Tests platform detection, path conversion, and command availability

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Load the library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/platform-utils.sh"

# Test counter
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Test function
test_function() {
    local test_name="$1"
    local expected="$2"
    local actual="$3"

    TESTS_RUN=$((TESTS_RUN + 1))

    if [ "$expected" = "$actual" ]; then
        echo -e "${GREEN}✓${NC} $test_name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "${RED}✗${NC} $test_name"
        echo -e "  Expected: $expected"
        echo -e "  Actual:   $actual"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

# Test boolean function
test_bool() {
    local test_name="$1"
    local command="$2"
    local expected="$3"

    TESTS_RUN=$((TESTS_RUN + 1))

    if eval "$command"; then
        actual="true"
    else
        actual="false"
    fi

    if [ "$expected" = "$actual" ]; then
        echo -e "${GREEN}✓${NC} $test_name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "${RED}✗${NC} $test_name"
        echo -e "  Expected: $expected"
        echo -e "  Actual:   $actual"
        TESTS_FAILED=$((TESTS_FAILED + 1))
        return 1
    fi
}

echo "============================================"
echo "Testing Windows Compatibility Utilities"
echo "============================================"
echo ""

# Platform Detection Tests
echo "Platform Detection:"
echo "-------------------"
OS=$(detect_os)
echo "Detected OS: $OS"

case "$OS" in
    Linux)
        test_bool "is_unix should be true" "is_unix" "true"
        test_bool "is_windows should be false" "is_windows" "false"
        test_bool "is_wsl should be false" "is_wsl" "false"
        test_bool "is_git_bash should be false" "is_git_bash" "false"
        ;;
    macOS)
        test_bool "is_unix should be true" "is_unix" "true"
        test_bool "is_windows should be false" "is_windows" "false"
        ;;
    WSL)
        test_bool "is_wsl should be true" "is_wsl" "true"
        test_bool "is_windows should be true" "is_windows" "true"
        test_bool "is_windows_environment should be true" "is_windows_environment" "true"
        ;;
    Windows)
        test_bool "is_git_bash should be true" "is_git_bash" "true"
        test_bool "is_windows should be true" "is_windows" "true"
        test_bool "is_windows_environment should be true" "is_windows_environment" "true"
        ;;
esac

echo ""

# Path Conversion Tests
echo "Path Conversion:"
echo "----------------"

# Test normalize_path
if [ "$OS" = "Windows" ] || [ "$OS" = "WSL" ]; then
    normalized=$(normalize_path "/tmp/test/file.txt")
    echo "Normalized path: $normalized"
fi

# Test absolute path
abs_path=$(get_absolute_path ".")
test_bool "get_absolute_path should return absolute path" "is_absolute_path '$abs_path'" "true"
echo "Absolute path of '.': $abs_path"

# Test WSL path conversion (only on WSL)
if is_wsl; then
    win_path=$(wsl_to_windows_path "/mnt/c/Users")
    echo "WSL to Windows: /mnt/c/Users -> $win_path"

    wsl_path=$(windows_to_wsl_path "C:\\Users")
    echo "Windows to WSL: C:\\Users -> $wsl_path"
fi

echo ""

# Command Availability Tests
echo "Command Availability:"
echo "--------------------"

# Test common commands
commands=("grep" "find" "sed" "awk" "ps" "kill")
for cmd in "${commands[@]}"; do
    if command -v "$cmd" &> /dev/null; then
        echo -e "${GREEN}✓${NC} $cmd is available"
    else
        echo -e "${YELLOW}!${NC} $cmd is NOT available"
    fi
done

echo ""

# Test command getters
echo "Platform-Specific Commands:"
echo "---------------------------"
echo "grep command: $(get_grep_command)"
echo "find command: $(get_find_command)"
echo "sed command: $(get_sed_command)"
echo "awk command: $(get_awk_command)"

echo ""

# File Operations Tests
echo "File Operations:"
echo "----------------"

# Create temp file for testing
temp_dir=$(get_temp_dir)
temp_file="$temp_dir/compat-test-$$.txt"
echo "Line 1" > "$temp_file"
echo "Line 2" >> "$temp_file"
echo "Line 3" >> "$temp_file"

# Test safe_wc
line_count=$(safe_wc "$temp_file" | awk '{print $1}')
test_function "safe_wc should count 3 lines" "3" "$line_count"

# Test safe_grep
grep_result=$(safe_grep "Line 2" "$temp_file")
test_function "safe_grep should find 'Line 2'" "Line 2" "$grep_result"

# Cleanup
rm -f "$temp_file"

echo ""

# Environment Variable Tests
echo "Environment Variables:"
echo "---------------------"

home=$(get_env_var "HOME" "/default")
echo "HOME: $home"
test_bool "HOME should be set" "[ -n '$home' ]" "true"

tmpdir=$(get_env_var "TMPDIR" "/tmp")
echo "TMPDIR: $tmpdir"
test_bool "TMPDIR should be set" "[ -n '$tmpdir' ]" "true"

echo ""

# Platform-Specific Path Tests
echo "Platform-Specific Paths:"
echo "-----------------------"
echo "Temp directory: $(get_temp_dir)"
echo "Null device: $(get_null_device)"
echo "Home directory: $(get_home_dir)"
echo "Shell config: $(get_shell_config)"
echo "Config directory: $(get_config_dir)"

echo ""

# Privilege Tests
echo "Privilege Check:"
echo "---------------"
if has_admin_privileges; then
    echo -e "${YELLOW}Running with admin/root privileges${NC}"
else
    echo "Running as regular user"
fi

echo ""

# Process Management Tests
echo "Process Management:"
echo "------------------"

# Test is_process_running with current process
current_pid=$$
test_bool "Current process should be running" "is_process_running $current_pid" "true"
test_bool "Invalid PID should not be running" "is_process_running 999999" "false"

# Test get_pids_by_name
bash_pids=$(get_pids_by_name "bash")
if [ -n "$bash_pids" ]; then
    echo -e "${GREEN}✓${NC} Found bash processes: $(echo $bash_pids | wc -w) processes"
    TESTS_PASSED=$((TESTS_PASSED + 1))
else
    echo -e "${YELLOW}!${NC} No bash processes found (unusual)"
fi
TESTS_RUN=$((TESTS_RUN + 1))

echo ""

# Summary
echo "============================================"
echo "Test Summary"
echo "============================================"
echo "Tests run:    $TESTS_RUN"
echo -e "Tests passed: ${GREEN}$TESTS_PASSED${NC}"
if [ $TESTS_FAILED -gt 0 ]; then
    echo -e "Tests failed: ${RED}$TESTS_FAILED${NC}"
else
    echo "Tests failed: 0"
fi
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed!${NC}"
    exit 1
fi
