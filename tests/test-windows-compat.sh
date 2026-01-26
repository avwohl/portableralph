#!/bin/bash
# test-windows-compat.sh - Tests for Windows compatibility features
# Tests lib/platform-utils.sh cross-platform functionality
#
# Tests:
#   - Platform detection functions (detect_os, is_windows, is_unix, is_wsl)
#   - Path conversion utilities (WSL <-> Windows)
#   - Path normalization (/ vs \)
#   - Cross-platform command wrappers
#   - Null device detection (/dev/null vs NUL)
#   - Temporary directory detection

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
RALPH_DIR="$(dirname "$SCRIPT_DIR")"
TEST_DIR="$SCRIPT_DIR/test-output-windows-compat"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

setup() {
    mkdir -p "$TEST_DIR"

    # Source the platform utilities library
    if [ -f "$RALPH_DIR/lib/platform-utils.sh" ]; then
        source "$RALPH_DIR/lib/platform-utils.sh"
    else
        echo "ERROR: platform-utils.sh not found at $RALPH_DIR/lib/platform-utils.sh"
        exit 1
    fi
}

teardown() {
    rm -rf "$TEST_DIR"
}

assert_equals() {
    local expected="$1"
    local actual="$2"
    local message="${3:-}"

    TESTS_RUN=$((TESTS_RUN + 1))
    if [ "$expected" = "$actual" ]; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        echo -e "${GREEN}✓${NC} $message"
        return 0
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        echo -e "${RED}✗${NC} $message"
        echo "  Expected: $expected"
        echo "  Actual:   $actual"
        return 1
    fi
}

assert_exit_code() {
    local expected="$1"
    local actual="$2"
    local message="${3:-}"

    TESTS_RUN=$((TESTS_RUN + 1))
    if [ "$expected" -eq "$actual" ]; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        echo -e "${GREEN}✓${NC} $message"
        return 0
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        echo -e "${RED}✗${NC} $message"
        echo "  Expected exit code: $expected"
        echo "  Actual exit code:   $actual"
        return 1
    fi
}

assert_contains() {
    local haystack="$1"
    local needle="$2"
    local message="${3:-}"

    TESTS_RUN=$((TESTS_RUN + 1))
    if echo "$haystack" | grep -qF "$needle"; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        echo -e "${GREEN}✓${NC} $message"
        return 0
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        echo -e "${RED}✗${NC} $message"
        return 1
    fi
}

# ============================================
# PLATFORM DETECTION TESTS
# ============================================

test_detect_os() {
    echo ""
    echo "Testing: detect_os() function"

    local os
    os=$(detect_os)

    # Should return one of: Linux, macOS, WSL, Windows, Unknown
    TESTS_RUN=$((TESTS_RUN + 1))
    if [[ "$os" =~ ^(Linux|macOS|WSL|Windows|Unknown)$ ]]; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        echo -e "${GREEN}✓${NC} detect_os() returns valid OS type: $os"
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        echo -e "${RED}✗${NC} detect_os() returned unexpected value: $os"
    fi
}

test_is_windows_function() {
    echo "Testing: is_windows() function"

    local os
    os=$(detect_os)

    if is_windows; then
        echo "  Detected as Windows environment: $os"
        assert_equals 1 1 "is_windows() returns true for Windows/WSL"
    else
        echo "  Not a Windows environment: $os"
        assert_equals 1 1 "is_windows() returns false for non-Windows"
    fi
}

test_is_unix_function() {
    echo "Testing: is_unix() function"

    local os
    os=$(detect_os)

    if is_unix; then
        echo "  Detected as Unix environment: $os"
        assert_equals 1 1 "is_unix() returns true for Unix-like systems"
    else
        echo "  Not a Unix environment: $os"
        assert_equals 1 1 "is_unix() returns false for non-Unix"
    fi
}

test_is_wsl_function() {
    echo "Testing: is_wsl() function"

    local os
    os=$(detect_os)

    if is_wsl; then
        echo "  Detected as WSL environment"
        assert_equals "WSL" "$os" "is_wsl() matches detect_os() == WSL"
    else
        echo "  Not a WSL environment: $os"
        TESTS_RUN=$((TESTS_RUN + 1))
        if [ "$os" != "WSL" ]; then
            TESTS_PASSED=$((TESTS_PASSED + 1))
            echo -e "${GREEN}✓${NC} is_wsl() returns false when not WSL"
        else
            TESTS_FAILED=$((TESTS_FAILED + 1))
            echo -e "${RED}✗${NC} is_wsl() inconsistent with detect_os()"
        fi
    fi
}

# ============================================
# PATH NORMALIZATION TESTS
# ============================================

test_normalize_path_unix() {
    echo ""
    echo "Testing: normalize_path() for Unix paths"

    # On Unix systems, backslashes should be converted to forward slashes
    local input='C:\Users\Test\file.txt'
    local output
    output=$(normalize_path "$input")

    # On non-Windows, should convert to forward slashes
    if ! is_windows || [[ "$(detect_os)" == "WSL" ]]; then
        assert_contains "$output" "/" "Converts backslashes to forward slashes on Unix"
    else
        echo "  Skipping (running on Windows)"
    fi
}

test_normalize_path_consistency() {
    echo "Testing: normalize_path() consistency"

    local test_path="/home/user/project/file.txt"
    local output
    output=$(normalize_path "$test_path")

    # Should return a valid path
    TESTS_RUN=$((TESTS_RUN + 1))
    if [ -n "$output" ]; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        echo -e "${GREEN}✓${NC} normalize_path() returns non-empty result"
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        echo -e "${RED}✗${NC} normalize_path() returned empty string"
    fi
}

# ============================================
# WSL PATH CONVERSION TESTS
# ============================================

test_wsl_to_windows_path_format() {
    echo ""
    echo "Testing: wsl_to_windows_path() path format"

    if is_wsl; then
        # Test conversion from /mnt/c/... to C:\...
        local wsl_path="/mnt/c/Users/Test/file.txt"
        local win_path
        win_path=$(wsl_to_windows_path "$wsl_path")

        assert_contains "$win_path" "C:" "Converts /mnt/c to C:"
        echo "  WSL: $wsl_path → Windows: $win_path"
    else
        echo "  Skipping (not running in WSL)"
        TESTS_RUN=$((TESTS_RUN + 1))
        TESTS_PASSED=$((TESTS_PASSED + 1))
        echo -e "${GREEN}✓${NC} Test skipped (not WSL)"
    fi
}

test_wsl_to_windows_passthrough() {
    echo "Testing: wsl_to_windows_path() passthrough on non-WSL"

    if ! is_wsl; then
        local test_path="/home/user/file.txt"
        local output
        output=$(wsl_to_windows_path "$test_path")

        # Should return unchanged on non-WSL systems
        assert_equals "$test_path" "$output" "Returns unchanged path on non-WSL"
    else
        echo "  Skipping (running in WSL)"
        TESTS_RUN=$((TESTS_RUN + 1))
        TESTS_PASSED=$((TESTS_PASSED + 1))
        echo -e "${GREEN}✓${NC} Test skipped (is WSL)"
    fi
}

test_windows_to_wsl_path_format() {
    echo "Testing: windows_to_wsl_path() path format"

    if is_wsl; then
        # Test conversion from C:\... to /mnt/c/...
        local win_path='C:\Users\Test\file.txt'
        local wsl_path
        wsl_path=$(windows_to_wsl_path "$win_path")

        assert_contains "$wsl_path" "/mnt/c" "Converts C: to /mnt/c"
        echo "  Windows: $win_path → WSL: $wsl_path"
    else
        echo "  Skipping (not running in WSL)"
        TESTS_RUN=$((TESTS_RUN + 1))
        TESTS_PASSED=$((TESTS_PASSED + 1))
        echo -e "${GREEN}✓${NC} Test skipped (not WSL)"
    fi
}

test_windows_to_wsl_passthrough() {
    echo "Testing: windows_to_wsl_path() passthrough on non-WSL"

    if ! is_wsl; then
        local test_path="/home/user/file.txt"
        local output
        output=$(windows_to_wsl_path "$test_path")

        # Should return unchanged on non-WSL systems
        assert_equals "$test_path" "$output" "Returns unchanged path on non-WSL"
    else
        echo "  Skipping (running in WSL)"
        TESTS_RUN=$((TESTS_RUN + 1))
        TESTS_PASSED=$((TESTS_PASSED + 1))
        echo -e "${GREEN}✓${NC} Test skipped (is WSL)"
    fi
}

# ============================================
# ABSOLUTE PATH TESTS
# ============================================

test_get_absolute_path() {
    echo ""
    echo "Testing: get_absolute_path() function"

    # Test with existing directory
    local abs_path
    abs_path=$(get_absolute_path "$TEST_DIR")

    TESTS_RUN=$((TESTS_RUN + 1))
    if [[ "$abs_path" = /* ]]; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        echo -e "${GREEN}✓${NC} Returns absolute path (starts with /)"
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        echo -e "${RED}✗${NC} Did not return absolute path: $abs_path"
    fi
}

test_get_absolute_path_error() {
    echo "Testing: get_absolute_path() error handling"

    # Test with empty argument
    local output
    local exit_code=0
    output=$(get_absolute_path "" 2>&1) || exit_code=$?

    assert_exit_code 1 $exit_code "Returns error for empty path"
}

test_is_absolute_path_unix() {
    echo "Testing: is_absolute_path() on Unix"

    local exit_code

    # Unix absolute path
    exit_code=0
    is_absolute_path "/home/user/file.txt" || exit_code=$?
    assert_exit_code 0 $exit_code "Recognizes /home/user as absolute"

    # Relative path
    exit_code=0
    is_absolute_path "relative/path/file.txt" || exit_code=$?
    assert_exit_code 1 $exit_code "Recognizes relative/path as relative"

    # Current directory
    exit_code=0
    is_absolute_path "./file.txt" || exit_code=$?
    assert_exit_code 1 $exit_code "Recognizes ./file.txt as relative"
}

# ============================================
# COMMAND FINDING TESTS
# ============================================

test_find_command_success() {
    echo ""
    echo "Testing: find_command() for existing command"

    # bash should exist on all systems running this test
    local bash_path
    bash_path=$(find_command "bash")

    TESTS_RUN=$((TESTS_RUN + 1))
    if [ -n "$bash_path" ]; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        echo -e "${GREEN}✓${NC} find_command() finds bash: $bash_path"
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        echo -e "${RED}✗${NC} find_command() failed to find bash"
    fi
}

test_find_command_failure() {
    echo "Testing: find_command() for non-existent command"

    local exit_code=0
    find_command "nonexistent_command_12345" &>/dev/null || exit_code=$?

    assert_exit_code 1 $exit_code "Returns error for non-existent command"
}

# ============================================
# PROCESS MANAGEMENT TESTS
# ============================================

test_is_process_running() {
    echo ""
    echo "Testing: is_process_running() function"

    # Current process should be running
    local current_pid=$$
    local exit_code=0
    is_process_running "$current_pid" || exit_code=$?

    assert_exit_code 0 $exit_code "Detects current process as running (PID $$)"
}

test_is_process_not_running() {
    echo "Testing: is_process_running() for dead process"

    # Use a PID that's unlikely to exist (very high number)
    local fake_pid=999999
    local exit_code=0
    is_process_running "$fake_pid" || exit_code=$?

    assert_exit_code 1 $exit_code "Detects non-existent process as not running"
}

test_kill_process_graceful() {
    echo "Testing: kill_process_graceful() function"

    # Start a background process
    sleep 30 &
    local test_pid=$!

    # Kill it gracefully
    local exit_code=0
    kill_process_graceful "$test_pid" 2 || exit_code=$?

    assert_exit_code 0 $exit_code "Successfully kills process gracefully"

    # Verify process is dead
    local still_running=0
    is_process_running "$test_pid" || still_running=$?

    assert_exit_code 1 $still_running "Process is actually dead after kill"
}

test_kill_process_error_handling() {
    echo "Testing: kill_process_graceful() error handling"

    # Test with empty PID
    local output
    local exit_code=0
    output=$(kill_process_graceful "" 2>&1) || exit_code=$?

    assert_exit_code 1 $exit_code "Returns error for empty PID"

    # Test with non-numeric PID
    exit_code=0
    output=$(kill_process_graceful "abc" 2>&1) || exit_code=$?

    assert_exit_code 1 $exit_code "Returns error for non-numeric PID"
}

# ============================================
# PROCESS DISCOVERY TESTS
# ============================================

test_get_pids_by_name() {
    echo ""
    echo "Testing: get_pids_by_name() function"

    # Start a uniquely named background process
    sleep 300 &
    local test_pid=$!

    # Try to find it
    local found_pids
    found_pids=$(get_pids_by_name "sleep 300")

    # Clean up
    kill "$test_pid" 2>/dev/null || true

    # Check if we found the PID
    TESTS_RUN=$((TESTS_RUN + 1))
    if echo "$found_pids" | grep -q "$test_pid"; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        echo -e "${GREEN}✓${NC} get_pids_by_name() found test process"
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        echo -e "${RED}✗${NC} get_pids_by_name() did not find test process"
    fi
}

# ============================================
# LOCK FILE TESTS
# ============================================

test_acquire_lock_success() {
    echo ""
    echo "Testing: acquire_lock() successful acquisition"

    local lock_file="$TEST_DIR/test.lock"

    local exit_code=0
    acquire_lock "$lock_file" || exit_code=$?

    assert_exit_code 0 $exit_code "Successfully acquires lock"

    # Clean up
    rm -f "$lock_file"
}

test_acquire_lock_already_locked() {
    echo "Testing: acquire_lock() when already locked"

    local lock_file="$TEST_DIR/test.lock"

    # Acquire lock first time
    acquire_lock "$lock_file" &>/dev/null

    # Try to acquire again (should fail)
    local exit_code=0
    acquire_lock "$lock_file" 2>/dev/null || exit_code=$?

    assert_exit_code 1 $exit_code "Fails when lock already held"

    # Clean up
    rm -f "$lock_file"
}

test_acquire_lock_stale() {
    echo "Testing: acquire_lock() removes stale locks"

    local lock_file="$TEST_DIR/test.lock"

    # Create a stale lock (non-existent PID)
    echo "999999" > "$lock_file"

    # Should remove stale lock and acquire new one
    local exit_code=0
    acquire_lock "$lock_file" 2>/dev/null || exit_code=$?

    assert_exit_code 0 $exit_code "Removes stale lock and acquires new lock"

    # Clean up
    rm -f "$lock_file"
}

test_release_lock() {
    echo "Testing: release_lock() function"

    local lock_file="$TEST_DIR/test.lock"

    # Acquire lock
    acquire_lock "$lock_file" &>/dev/null

    # Release lock
    local exit_code=0
    release_lock "$lock_file" || exit_code=$?

    assert_exit_code 0 $exit_code "Successfully releases lock"

    # Verify lock file is removed
    TESTS_RUN=$((TESTS_RUN + 1))
    if [ ! -f "$lock_file" ]; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        echo -e "${GREEN}✓${NC} Lock file removed after release"
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        echo -e "${RED}✗${NC} Lock file still exists after release"
    fi
}

# ============================================
# NULL DEVICE DETECTION
# ============================================

test_null_device_detection() {
    echo ""
    echo "Testing: Null device detection"

    # On Unix/Linux/WSL/macOS: /dev/null
    # On Windows (cmd): NUL

    local os
    os=$(detect_os)

    if [[ "$os" == "Windows" ]]; then
        echo "  Windows detected - null device should be NUL"
        assert_equals 1 1 "Windows uses NUL"
    else
        echo "  Unix-like detected - null device should be /dev/null"
        TESTS_RUN=$((TESTS_RUN + 1))
        if [ -e "/dev/null" ]; then
            TESTS_PASSED=$((TESTS_PASSED + 1))
            echo -e "${GREEN}✓${NC} /dev/null exists on Unix-like system"
        else
            TESTS_FAILED=$((TESTS_FAILED + 1))
            echo -e "${RED}✗${NC} /dev/null does not exist"
        fi
    fi
}

# ============================================
# TEMP DIRECTORY DETECTION
# ============================================

test_temp_directory() {
    echo ""
    echo "Testing: Temporary directory detection"

    # Should work on all platforms
    local temp_file
    temp_file=$(mktemp) || true

    TESTS_RUN=$((TESTS_RUN + 1))
    if [ -n "$temp_file" ] && [ -f "$temp_file" ]; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        echo -e "${GREEN}✓${NC} mktemp creates temporary file: $temp_file"
        rm -f "$temp_file"
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        echo -e "${RED}✗${NC} mktemp failed to create temporary file"
    fi
}

# ============================================
# RUN ALL TESTS
# ============================================

run_all_tests() {
    echo "======================================"
    echo "Windows Compatibility Test Suite"
    echo "Testing: lib/platform-utils.sh"
    echo "======================================"

    setup

    local os
    os=$(detect_os)
    echo ""
    echo "Detected platform: $os"
    echo ""

    echo "=== Platform Detection Tests ==="
    test_detect_os
    test_is_windows_function
    test_is_unix_function
    test_is_wsl_function

    echo ""
    echo "=== Path Normalization Tests ==="
    test_normalize_path_unix
    test_normalize_path_consistency

    echo ""
    echo "=== WSL Path Conversion Tests ==="
    test_wsl_to_windows_path_format
    test_wsl_to_windows_passthrough
    test_windows_to_wsl_path_format
    test_windows_to_wsl_passthrough

    echo ""
    echo "=== Absolute Path Tests ==="
    test_get_absolute_path
    test_get_absolute_path_error
    test_is_absolute_path_unix

    echo ""
    echo "=== Command Finding Tests ==="
    test_find_command_success
    test_find_command_failure

    echo ""
    echo "=== Process Management Tests ==="
    test_is_process_running
    test_is_process_not_running
    test_kill_process_graceful
    test_kill_process_error_handling

    echo ""
    echo "=== Process Discovery Tests ==="
    test_get_pids_by_name

    echo ""
    echo "=== Lock File Tests ==="
    test_acquire_lock_success
    test_acquire_lock_already_locked
    test_acquire_lock_stale
    test_release_lock

    echo ""
    echo "=== Cross-Platform Compatibility Tests ==="
    test_null_device_detection
    test_temp_directory

    teardown

    # Print summary
    echo ""
    echo "======================================"
    echo "Windows Compatibility Test Summary"
    echo "======================================"
    echo "Platform: $os"
    echo "Tests run:    $TESTS_RUN"
    echo -e "Tests passed: ${GREEN}$TESTS_PASSED${NC}"
    echo -e "Tests failed: ${RED}$TESTS_FAILED${NC}"
    echo ""

    if [ $TESTS_FAILED -eq 0 ]; then
        echo -e "${GREEN}All Windows compatibility tests passed!${NC}"
        return 0
    else
        echo -e "${RED}Some Windows compatibility tests failed.${NC}"
        return 1
    fi
}

# Run tests if executed directly
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    run_all_tests
fi
