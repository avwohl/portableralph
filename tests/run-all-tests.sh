#!/bin/bash
# Main test runner for Ralph
# Executes all test suites and generates summary

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
RALPH_DIR="$(dirname "$SCRIPT_DIR")"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Test results tracking
declare -A TEST_RESULTS
TOTAL_TESTS=0
TOTAL_PASSED=0
TOTAL_FAILED=0

# Configuration
RUN_SECURITY=${RUN_SECURITY:-true}
RUN_UNIT=${RUN_UNIT:-true}
RUN_INTEGRATION=${RUN_INTEGRATION:-true}
VERBOSE=${VERBOSE:-false}
STOP_ON_FAILURE=${STOP_ON_FAILURE:-false}

# ============================================
# UTILITIES
# ============================================

print_banner() {
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}  Ralph Test Suite${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

usage() {
    cat << EOF
${BOLD}Ralph Test Suite Runner${NC}

${YELLOW}Usage:${NC}
  $0 [options]

${YELLOW}Options:${NC}
  --unit-only           Run only unit tests
  --integration-only    Run only integration tests
  --security-only       Run only security tests
  --verbose, -v         Verbose output
  --stop-on-failure     Stop on first test suite failure
  --help, -h            Show this help

${YELLOW}Examples:${NC}
  $0                          # Run all tests
  $0 --unit-only              # Run only unit tests
  $0 --verbose                # Run all tests with verbose output
  $0 --stop-on-failure        # Stop on first failure

${YELLOW}Environment Variables:${NC}
  RUN_SECURITY=false         Skip security tests
  RUN_UNIT=false             Skip unit tests
  RUN_INTEGRATION=false      Skip integration tests
  VERBOSE=true               Enable verbose output
  STOP_ON_FAILURE=true       Stop on first failure

EOF
}

# ============================================
# TEST EXECUTION
# ============================================

run_test_suite() {
    local suite_name="$1"
    local test_script="$2"

    if [ ! -x "$test_script" ]; then
        echo -e "${YELLOW}⚠${NC} $suite_name: Test script not executable or not found"
        TEST_RESULTS["$suite_name"]="SKIP"
        return 0
    fi

    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}Running: $suite_name${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    local output
    local exit_code=0

    if [ "$VERBOSE" = true ]; then
        "$test_script" || exit_code=$?
    else
        output=$("$test_script" 2>&1) || exit_code=$?
    fi

    if [ $exit_code -eq 0 ]; then
        echo -e "${GREEN}✓${NC} $suite_name: ${GREEN}PASSED${NC}"
        TEST_RESULTS["$suite_name"]="PASS"

        # Extract test counts from output if not verbose
        if [ "$VERBOSE" = false ] && [ -n "${output:-}" ]; then
            local passed
            local failed
            passed=$(echo "$output" | grep -oP "Tests passed: \K[0-9]+" || echo "0")
            failed=$(echo "$output" | grep -oP "Tests failed: \K[0-9]+" || echo "0")

            TOTAL_PASSED=$((TOTAL_PASSED + passed))
            TOTAL_FAILED=$((TOTAL_FAILED + failed))
            TOTAL_TESTS=$((TOTAL_TESTS + passed + failed))

            echo "  Tests run: $((passed + failed)) | Passed: $passed | Failed: $failed"
        fi
    else
        echo -e "${RED}✗${NC} $suite_name: ${RED}FAILED${NC}"
        TEST_RESULTS["$suite_name"]="FAIL"

        if [ "$VERBOSE" = false ] && [ -n "${output:-}" ]; then
            echo ""
            echo -e "${YELLOW}Output:${NC}"
            echo "$output" | tail -20
            echo ""
        fi

        if [ "$STOP_ON_FAILURE" = true ]; then
            echo ""
            echo -e "${RED}Stopping due to test failure (--stop-on-failure)${NC}"
            exit 1
        fi
    fi
}

# ============================================
# SUMMARY
# ============================================

print_summary() {
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}Test Summary${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    local suite_passed=0
    local suite_failed=0
    local suite_skipped=0

    for suite in "${!TEST_RESULTS[@]}"; do
        local result="${TEST_RESULTS[$suite]}"
        local status_color=""
        local status_text=""

        case "$result" in
            PASS)
                status_color="$GREEN"
                status_text="✓ PASSED"
                suite_passed=$((suite_passed + 1))
                ;;
            FAIL)
                status_color="$RED"
                status_text="✗ FAILED"
                suite_failed=$((suite_failed + 1))
                ;;
            SKIP)
                status_color="$YELLOW"
                status_text="⊝ SKIPPED"
                suite_skipped=$((suite_skipped + 1))
                ;;
        esac

        printf "  %-30s ${status_color}%s${NC}\n" "$suite" "$status_text"
    done

    echo ""
    echo -e "${BOLD}Suite Statistics:${NC}"
    echo "  Total suites:   $((suite_passed + suite_failed + suite_skipped))"
    echo -e "  Passed:         ${GREEN}$suite_passed${NC}"
    echo -e "  Failed:         ${RED}$suite_failed${NC}"
    echo -e "  Skipped:        ${YELLOW}$suite_skipped${NC}"

    if [ $TOTAL_TESTS -gt 0 ]; then
        echo ""
        echo -e "${BOLD}Individual Test Statistics:${NC}"
        echo "  Total tests:    $TOTAL_TESTS"
        echo -e "  Passed:         ${GREEN}$TOTAL_PASSED${NC}"
        echo -e "  Failed:         ${RED}$TOTAL_FAILED${NC}"

        local pass_rate=0
        if [ $TOTAL_TESTS -gt 0 ]; then
            pass_rate=$((TOTAL_PASSED * 100 / TOTAL_TESTS))
        fi
        echo -e "  Pass rate:      ${BOLD}${pass_rate}%${NC}"
    fi

    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

    if [ $suite_failed -eq 0 ]; then
        echo -e "${GREEN}${BOLD}All test suites passed!${NC}"
        echo ""
        return 0
    else
        echo -e "${RED}${BOLD}Some test suites failed.${NC}"
        echo ""
        echo "Run with --verbose for detailed output"
        echo "Run individual test files for debugging:"
        echo ""
        for suite in "${!TEST_RESULTS[@]}"; do
            if [ "${TEST_RESULTS[$suite]}" = "FAIL" ]; then
                local script_name
                script_name=$(echo "$suite" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')
                echo "  $SCRIPT_DIR/test-${script_name}.sh"
            fi
        done
        echo ""
        return 1
    fi
}

# ============================================
# ARGUMENT PARSING
# ============================================

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --unit-only)
                RUN_UNIT=true
                RUN_INTEGRATION=false
                RUN_SECURITY=false
                shift
                ;;
            --integration-only)
                RUN_UNIT=false
                RUN_INTEGRATION=true
                RUN_SECURITY=false
                shift
                ;;
            --security-only)
                RUN_UNIT=false
                RUN_INTEGRATION=false
                RUN_SECURITY=true
                shift
                ;;
            --verbose|-v)
                VERBOSE=true
                shift
                ;;
            --stop-on-failure)
                STOP_ON_FAILURE=true
                shift
                ;;
            --help|-h)
                usage
                exit 0
                ;;
            *)
                echo -e "${RED}Unknown option: $1${NC}"
                echo ""
                usage
                exit 1
                ;;
        esac
    done
}

# ============================================
# PREREQUISITES
# ============================================

check_prerequisites() {
    echo "Checking prerequisites..."

    # Check that we're in the right directory
    if [ ! -f "$RALPH_DIR/ralph.sh" ]; then
        echo -e "${RED}Error: Ralph installation not found${NC}"
        echo "Expected ralph.sh at: $RALPH_DIR/ralph.sh"
        exit 1
    fi

    # Make test scripts executable
    chmod +x "$SCRIPT_DIR"/test-*.sh 2>/dev/null || true

    echo -e "${GREEN}✓${NC} Prerequisites OK"
    echo ""
}

# ============================================
# MAIN
# ============================================

main() {
    parse_args "$@"
    print_banner
    check_prerequisites

    echo -e "${BOLD}Configuration:${NC}"
    echo "  Unit tests:        $([ "$RUN_UNIT" = true ] && echo "${GREEN}enabled${NC}" || echo "${YELLOW}disabled${NC}")"
    echo "  Integration tests: $([ "$RUN_INTEGRATION" = true ] && echo "${GREEN}enabled${NC}" || echo "${YELLOW}disabled${NC}")"
    echo "  Security tests:    $([ "$RUN_SECURITY" = true ] && echo "${GREEN}enabled${NC}" || echo "${YELLOW}disabled${NC}")"
    echo "  Verbose output:    $([ "$VERBOSE" = true ] && echo "${GREEN}enabled${NC}" || echo "disabled")"
    echo "  Stop on failure:   $([ "$STOP_ON_FAILURE" = true ] && echo "${GREEN}enabled${NC}" || echo "disabled")"

    # Run unit tests
    if [ "$RUN_UNIT" = true ]; then
        run_test_suite "Ralph Tests" "$SCRIPT_DIR/test-ralph.sh"
        run_test_suite "Notify Tests" "$SCRIPT_DIR/test-notify.sh"
        run_test_suite "Monitor Tests" "$SCRIPT_DIR/test-monitor.sh"
        run_test_suite "Setup Tests" "$SCRIPT_DIR/test-setup.sh"
        run_test_suite "Validation Library Tests" "$SCRIPT_DIR/test-validation-lib.sh"
        run_test_suite "Constants Library Tests" "$SCRIPT_DIR/test-constants-lib.sh"
        run_test_suite "Windows Compatibility Tests" "$SCRIPT_DIR/test-windows-compat.sh"
    fi

    # Run integration tests
    if [ "$RUN_INTEGRATION" = true ]; then
        run_test_suite "Integration Tests" "$SCRIPT_DIR/test-integration.sh"
    fi

    # Run security tests
    if [ "$RUN_SECURITY" = true ]; then
        run_test_suite "Security Tests" "$SCRIPT_DIR/test-security.sh"
        run_test_suite "Security Fixes Tests" "$SCRIPT_DIR/test-security-fixes.sh"
    fi

    # Print summary
    print_summary
}

# Trap errors
trap 'echo -e "\n${RED}Test runner interrupted${NC}"; exit 130' INT TERM

# Run main
main "$@"
