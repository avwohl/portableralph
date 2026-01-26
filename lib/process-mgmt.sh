#!/bin/bash
# process-mgmt.sh - Unix process management utilities for PortableRalph
# Provides standardized process management functions
#
# Usage:
#   source ./lib/process-mgmt.sh
#   start_background_process "claude" "--version" "/tmp/output.log"
#   stop_process_by_pattern "claude"

# Load constants
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [ -f "$SCRIPT_DIR/constants.sh" ]; then
    source "$SCRIPT_DIR/constants.sh"
fi

# Start a process in the background (equivalent to nohup)
# Args: $1 = command, $2 = arguments (optional), $3 = output file (optional), $4 = working directory (optional)
# Returns: Process ID
start_background_process() {
    local command="$1"
    local args="${2:-}"
    local output_file="${3:-/dev/null}"
    local work_dir="${4:-$(pwd)}"

    # Change to working directory if specified
    local original_dir=$(pwd)
    cd "$work_dir" 2>/dev/null || {
        echo "ERROR: Cannot change to directory: $work_dir" >&2
        return 1
    }

    # Start process in background
    if [ -n "$args" ]; then
        nohup $command $args >> "$output_file" 2>&1 &
    else
        nohup $command >> "$output_file" 2>&1 &
    fi

    local pid=$!

    # Return to original directory
    cd "$original_dir"

    echo "$pid"
}

# Stop a process gracefully (equivalent to kill)
# Args: $1 = PID, $2 = force flag (optional, "force"), $3 = timeout in seconds (default: 5)
# Returns: 0 if stopped successfully, 1 otherwise
stop_process_safe() {
    local pid="$1"
    local force="${2:-}"
    local timeout="${3:-${PROCESS_STOP_TIMEOUT:-5}}"

    # Check if process exists
    if ! kill -0 "$pid" 2>/dev/null; then
        return 0
    fi

    # Try graceful stop first (unless force is specified)
    if [ "$force" != "force" ]; then
        kill -TERM "$pid" 2>/dev/null || return 1

        # Wait for process to exit
        local elapsed=0
        local check_delay="${PROCESS_VERIFY_DELAY:-1}"
        while kill -0 "$pid" 2>/dev/null && [ "$elapsed" -lt "$timeout" ]; do
            sleep "$check_delay"
            elapsed=$((elapsed + check_delay))
        done

        # Check if exited
        if ! kill -0 "$pid" 2>/dev/null; then
            return 0
        fi
    fi

    # Force kill
    kill -9 "$pid" 2>/dev/null || return 1
    local verify_delay="${PROCESS_VERIFY_DELAY:-1}"
    sleep "$verify_delay"

    # Verify process is dead
    if kill -0 "$pid" 2>/dev/null; then
        return 1
    else
        return 0
    fi
}

# List processes with details (equivalent to ps)
# Args: $1 = pattern (optional)
# Returns: Process list
get_process_list() {
    local pattern="${1:-}"

    if [ -n "$pattern" ]; then
        ps aux | grep "$pattern" | grep -v grep
    else
        ps aux
    fi
}

# Find processes by name or command pattern (equivalent to pgrep)
# Args: $1 = pattern, $2 = full path flag (optional, "fullpath")
# Returns: Space-separated list of PIDs
find_process_by_pattern() {
    local pattern="$1"
    local fullpath="${2:-}"

    if command -v pgrep &> /dev/null; then
        if [ "$fullpath" = "fullpath" ]; then
            pgrep -f "$pattern" 2>/dev/null || true
        else
            pgrep "$pattern" 2>/dev/null || true
        fi
    else
        # Fallback to ps + grep
        if [ "$fullpath" = "fullpath" ]; then
            ps aux | grep "$pattern" | grep -v grep | awk '{print $2}'
        else
            ps aux | grep "$pattern" | grep -v grep | awk '{print $2}'
        fi
    fi
}

# Stop all processes matching a pattern (equivalent to pkill)
# Args: $1 = pattern, $2 = force flag (optional, "force"), $3 = full path flag (optional, "fullpath")
# Returns: Number of processes stopped
stop_process_by_pattern() {
    local pattern="$1"
    local force="${2:-}"
    local fullpath="${3:-}"

    local pids=$(find_process_by_pattern "$pattern" "$fullpath")
    local count=0

    for pid in $pids; do
        if stop_process_safe "$pid" "$force"; then
            count=$((count + 1))
        fi
    done

    echo "$count"
}

# Check if a process is running
# Args: $1 = PID
# Returns: 0 if running, 1 otherwise
test_process_running() {
    local pid="$1"

    if [ -z "$pid" ]; then
        return 1
    fi

    kill -0 "$pid" 2>/dev/null
}

# Get process information (equivalent to ps -p <pid>)
# Args: $1 = PID
# Returns: Process information
get_process_info() {
    local pid="$1"

    ps -p "$pid" -o pid,comm,cpu,vsz,rss,start,command 2>/dev/null
}

# Wait for a process to exit (equivalent to wait)
# Args: $1 = PID, $2 = timeout in seconds (optional, 0 = no timeout)
# Returns: 0 if exited, 1 if timeout
wait_process_exit() {
    local pid="$1"
    local timeout="${2:-0}"

    # Check if process exists
    if ! kill -0 "$pid" 2>/dev/null; then
        return 0
    fi

    # If no timeout, wait indefinitely
    if [ "$timeout" -eq 0 ]; then
        wait "$pid" 2>/dev/null || true
        return 0
    fi

    # Wait with timeout
    local elapsed=0
    local check_delay="${PROCESS_VERIFY_DELAY:-1}"
    while kill -0 "$pid" 2>/dev/null && [ "$elapsed" -lt "$timeout" ]; do
        sleep "$check_delay"
        elapsed=$((elapsed + check_delay))
    done

    # Check if process exited
    if kill -0 "$pid" 2>/dev/null; then
        return 1  # Timeout
    else
        return 0  # Exited
    fi
}

# Start a process and detach (like nohup &)
# Args: $1 = command, $2 = arguments (optional), $3 = log file (optional), $4 = working directory (optional)
# Returns: Process ID
start_detached_process() {
    local command="$1"
    local args="${2:-}"
    local log_file="${3:-/dev/null}"
    local work_dir="${4:-$(pwd)}"

    start_background_process "$command" "$args" "$log_file" "$work_dir"
}

# Export functions for use in other scripts
export -f start_background_process
export -f stop_process_safe
export -f get_process_list
export -f find_process_by_pattern
export -f stop_process_by_pattern
export -f test_process_running
export -f get_process_info
export -f wait_process_exit
export -f start_detached_process
