# Ralph Test Suite

Comprehensive automated tests for the Ralph autonomous development loop.

## Overview

This test suite provides comprehensive coverage for all Ralph functionality including:
- Unit tests for individual scripts
- Integration tests for end-to-end workflows
- Security tests for vulnerability verification
- Cross-platform compatibility testing

## Test Structure

```
tests/
├── test-ralph.sh           # Unit tests for ralph.sh (main launcher)
├── test-notify.sh          # Unit tests for notify.sh (notifications)
├── test-monitor.sh         # Unit tests for monitor-progress.sh
├── test-setup.sh           # Unit tests for setup-notifications.sh
├── test-integration.sh     # Integration tests (end-to-end workflows)
├── test-security.sh        # Security vulnerability tests
├── run-all-tests.sh        # Main test runner
└── README.md               # This file
```

## Running Tests

### Run All Tests

```bash
cd ~/ralph/tests
./run-all-tests.sh
```

### Run Specific Test Suites

```bash
# Unit tests only
./run-all-tests.sh --unit-only

# Integration tests only
./run-all-tests.sh --integration-only

# Security tests only
./run-all-tests.sh --security-only
```

### Run Individual Test Files

```bash
# Run ralph tests
./test-ralph.sh

# Run notification tests
./test-notify.sh

# Run security tests
./test-security.sh
```

### Verbose Output

```bash
# Show detailed output for all tests
./run-all-tests.sh --verbose

# Verbose output for specific suite
./run-all-tests.sh --security-only --verbose
```

### Stop on Failure

```bash
# Stop immediately when a test suite fails
./run-all-tests.sh --stop-on-failure
```

## Test Categories

### Unit Tests

Tests individual script functionality in isolation:

- **test-ralph.sh**: Main launcher script
  - Version and help flags
  - Plan file validation
  - Mode validation (plan/build)
  - Config management
  - DO_NOT_COMMIT directive
  - Progress file naming

- **test-notify.sh**: Notification system
  - Platform configuration (Slack, Discord, Telegram, Custom)
  - Message formatting
  - Error handling
  - Security (injection prevention)

- **test-monitor.sh**: Progress monitoring
  - Progress file parsing
  - Percentage calculation
  - Status detection
  - JSON escaping
  - Slack notification integration

- **test-setup.sh**: Setup wizard
  - Config file creation
  - Platform configuration
  - Permission handling
  - Input validation

### Integration Tests

Tests end-to-end workflows and multi-component interactions:

- Notification setup workflow
- Plan → Build workflow
- Config override workflow
- Multiple concurrent plans
- Error recovery scenarios
- Update workflows
- Multi-platform notifications

### Security Tests

Verifies security vulnerabilities are fixed:

- Command injection prevention
- JSON injection prevention
- Path traversal protection
- Sensitive data exposure
- Input validation
- Script injection prevention
- Privilege escalation prevention
- Temporary file security
- Rate limiting

## Test Results

### Success Output

```
======================================
Test Summary
======================================
Tests run:    45
Tests passed: 45
Tests failed: 0

All tests passed!
```

### Failure Output

```
======================================
Test Summary
======================================
Tests run:    45
Tests passed: 42
Tests failed: 3

Some tests failed.
```

## Environment Variables

Control test execution with environment variables:

```bash
# Skip specific test categories
RUN_SECURITY=false ./run-all-tests.sh    # Skip security tests
RUN_UNIT=false ./run-all-tests.sh        # Skip unit tests
RUN_INTEGRATION=false ./run-all-tests.sh # Skip integration tests

# Verbose output
VERBOSE=true ./run-all-tests.sh

# Stop on first failure
STOP_ON_FAILURE=true ./run-all-tests.sh
```

## CI/CD Integration

### GitHub Actions

The test suite is integrated with GitHub Actions. See `.github/workflows/ci.yml`:

```yaml
# Runs on every push and pull request
- Unit tests across multiple bash versions
- Integration tests
- Security tests
- Cross-platform compatibility (Ubuntu, macOS)
- ShellCheck static analysis
```

### Local CI Simulation

```bash
# Simulate CI environment locally
cd ~/ralph/tests
./run-all-tests.sh --verbose --stop-on-failure
```

## Writing New Tests

### Test Template

```bash
#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
RALPH_DIR="$(dirname "$SCRIPT_DIR")"
TEST_DIR="$SCRIPT_DIR/test-output-mytest"

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

setup() {
    mkdir -p "$TEST_DIR"
    export HOME="$TEST_DIR"
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
        echo "✓ $message"
        return 0
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        echo "✗ $message"
        echo "  Expected: $expected"
        echo "  Actual:   $actual"
        return 1
    fi
}

test_something() {
    echo "Testing: Something"
    assert_equals "expected" "actual" "Description"
}

run_all_tests() {
    setup
    test_something
    teardown

    echo "Tests run: $TESTS_RUN"
    echo "Passed: $TESTS_PASSED"
    echo "Failed: $TESTS_FAILED"

    [ $TESTS_FAILED -eq 0 ] && return 0 || return 1
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    run_all_tests
fi
```

### Guidelines

1. **Isolation**: Each test should be independent
2. **Cleanup**: Always clean up in `teardown()`
3. **Assertions**: Use helper functions (`assert_equals`, `assert_contains`, etc.)
4. **Descriptive**: Test names should clearly describe what's being tested
5. **Fast**: Keep tests fast (mock external dependencies)
6. **Deterministic**: Tests should always produce the same result

## Mock Dependencies

### Mocking curl

```bash
# Create mock curl
mock_curl() {
    local url="$1"
    # Return mock response
    echo '{"status": "ok"}'
}

# Use in tests
export -f mock_curl
alias curl=mock_curl
```

### Mocking Claude CLI

```bash
# Mock Claude CLI for testing
cat > "$TEST_DIR/claude" << 'EOF'
#!/bin/bash
echo "Mock Claude response"
exit 0
EOF
chmod +x "$TEST_DIR/claude"
export PATH="$TEST_DIR:$PATH"
```

## Troubleshooting

### Tests Fail Due to Permissions

```bash
# Make all test scripts executable
chmod +x ~/ralph/tests/*.sh
```

### Tests Leave Artifacts

```bash
# Clean up all test output directories
rm -rf ~/ralph/tests/test-output-*
```

### Tests Timeout

```bash
# Some tests may run external commands
# Ensure you have network connectivity for update tests
# Or skip those tests:
RUN_INTEGRATION=false ./run-all-tests.sh
```

### Color Output Issues

```bash
# Disable colors in CI or non-TTY environments
# Tests automatically detect TTY and disable colors
```

## Test Coverage

Current test coverage:

- **ralph.sh**: ~85% (20+ tests)
- **notify.sh**: ~90% (18+ tests)
- **monitor-progress.sh**: ~75% (15+ tests)
- **setup-notifications.sh**: ~80% (17+ tests)
- **Integration**: ~70% (18+ scenarios)
- **Security**: ~95% (25+ security checks)

**Total**: ~150 automated tests

## Contributing

When adding new functionality:

1. Write tests first (TDD)
2. Ensure all existing tests pass
3. Add integration tests for workflows
4. Update this README

## Resources

- [Bash Test Framework (bats)](https://github.com/bats-core/bats-core)
- [ShellCheck](https://www.shellcheck.net/)
- [GitHub Actions for Bash](https://github.com/actions)

## License

Same as Ralph - see main repository LICENSE file.
