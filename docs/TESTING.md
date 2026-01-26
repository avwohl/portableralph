# Testing Guide

This guide covers testing strategies for PortableRalph and testing code that Ralph generates.

## Overview

Testing Ralph involves two aspects:

1. **Testing Ralph itself** - Ensuring Ralph works correctly
2. **Testing Ralph's output** - Validating AI-generated code

---

## Testing Ralph Installation

### Quick Verification

```bash
# Check Ralph is installed
ralph --version

# Expected output:
# PortableRalph v1.6.0

# Check help works
ralph --help

# Check dependencies
which claude  # Claude CLI
which git     # Git
which curl    # For updates/notifications
```

### New Test Suites

Ralph now includes comprehensive test suites for security, validation, constants, and Windows compatibility.

#### Test Suite: Security Fixes

**File:** `tests/test-security.sh`

Tests all security vulnerabilities and their fixes:

```bash
# Run security tests
cd ~/ralph
./tests/test-security.sh

# Test categories:
# - Command injection prevention (sed, eval, system calls)
# - Path traversal attack prevention
# - SSRF protection in URL validation
# - Custom script validation
# - Input sanitization
# - Token masking in logs
# - Config file validation
```

**Sample output:**
```
Running Ralph Security Tests
============================

Command Injection Tests:
✓ Sed injection prevented
✓ Command substitution blocked
✓ Eval injection prevented

Path Traversal Tests:
✓ Parent directory traversal blocked
✓ Absolute path injection prevented
✓ Symlink attack mitigated

SSRF Protection Tests:
✓ Localhost URLs rejected
✓ Private IP ranges blocked
✓ Metadata service URLs blocked

Tests: 42 | Passed: 42 | Failed: 0
```

**What it tests:**
- Sed injection with malicious patterns
- Command injection via `$()`, backticks, `|`, `;`, `&`
- Path traversal using `..`, `~`, absolute paths
- SSRF attempts to localhost, 127.0.0.1, 192.168.x.x, 10.x.x.x, 169.254.169.254
- Custom script validation (permissions, existence, timeout)
- Token masking (ensures secrets not logged)
- JSON escaping for special characters

#### Test Suite: Validation Library

**File:** `lib/test-compat.sh`

Tests the validation library functions:

```bash
# Run validation tests
cd ~/ralph
./lib/test-compat.sh

# Test categories:
# - URL validation (format, SSRF, protocols)
# - Email validation (RFC compliance)
# - Numeric validation (range checking)
# - Path validation (security, existence)
# - JSON escaping
# - Token masking
```

**Sample output:**
```
Testing Validation Library
=========================

URL Validation:
✓ Valid HTTPS URLs accepted
✓ Invalid URLs rejected
✓ SSRF attempts blocked
✓ Protocol validation working

Email Validation:
✓ Valid emails accepted
✓ Invalid emails rejected
✓ RFC compliance verified

Numeric Validation:
✓ Valid numbers accepted
✓ Invalid input rejected
✓ Range checking works

Tests: 35 | Passed: 35 | Failed: 0
```

**What it tests:**
- `validate_url()` - URL format, SSRF protection, protocol checking
- `validate_email()` - Email format, RFC 5322 compliance
- `validate_numeric()` - Integer validation, range checking
- `validate_path()` - Path security, traversal prevention, existence
- `json_escape()` - Special character escaping for JSON
- `mask_token()` - Sensitive data masking

#### Test Suite: Constants Library

**File:** `lib/constants.sh` (with inline tests)

Tests that all constants are defined and exported:

```bash
# Verify constants are loaded
source ~/ralph/lib/constants.sh

# Check specific constant
echo $HTTP_MAX_TIME
# Should output: 10

# Check all constants exported
env | grep -E 'HTTP_|NOTIFY_|MAX_|TIMEOUT'
```

**What it tests:**
- All timeout constants defined
- All rate limit constants defined
- All retry constants defined
- All validation limit constants defined
- All constants properly exported

#### Test Suite: Windows Compatibility

**Bash Tests:** `lib/test-compat.sh`
**PowerShell Tests:** `lib/test-compat.ps1`

Tests cross-platform compatibility:

```bash
# Run bash compatibility tests
cd ~/ralph
./lib/test-compat.sh

# Test categories:
# - Platform detection
# - Path conversion (Windows ↔ Unix)
# - Command availability checking
# - Process management
# - Configuration loading
```

**PowerShell tests:**
```powershell
# Run PowerShell compatibility tests
cd $HOME\ralph
.\lib\test-compat.ps1

# Test categories:
# - Platform utilities (Get-RalphPlatform, Test-IsWSL)
# - Path conversion (Get-UnixPath, Get-WindowsPath)
# - Command checking (Test-CommandExists)
# - Config management (Get-RalphConfig, Set-RalphConfig)
# - Process management (Test-RalphProcess, Start-RalphBackground)
```

**Sample output:**
```
Testing Windows Compatibility
=============================

Platform Detection:
✓ Platform correctly detected
✓ WSL detection working
✓ Architecture detection working

Path Conversion:
✓ Windows to Unix conversion works
✓ Unix to Windows conversion works
✓ Path normalization works

Command Utilities:
✓ Command existence checking works
✓ Safe command execution works

Tests: 28 | Passed: 28 | Failed: 0
```

**What it tests:**
- Platform detection (Windows, WSL, Linux, macOS)
- Path conversions between Windows and Unix formats
- Command availability (git, claude, curl, etc.)
- Process management (start, stop, status)
- Configuration reading and writing
- Cross-platform compatibility

#### Test Suite: PowerShell Scripts

**File:** `tests/test-ralph.ps1`, `tests/test-notify.ps1`, `tests/test-monitor.ps1`

PowerShell-specific test suites:

```powershell
# Run all PowerShell tests
cd $HOME\ralph\tests

# Test Ralph core
.\test-ralph.ps1

# Test notifications
.\test-notify.ps1

# Test monitoring
.\test-monitor.ps1
```

**What they test:**
- Ralph command execution in PowerShell
- Notification system in PowerShell environment
- Progress monitoring in PowerShell
- Configuration management
- Error handling

### Running All Tests

```bash
# Run all bash tests
cd ~/ralph
for test in tests/test-*.sh lib/test-*.sh; do
    echo "Running $test..."
    bash "$test"
done

# Run all PowerShell tests (Windows)
cd $HOME\ralph
Get-ChildItem -Path tests,lib -Filter "test-*.ps1" | ForEach-Object {
    Write-Host "Running $($_.Name)..."
    & $_.FullName
}
```

### Functional Tests

#### Test 1: Plan Mode

```bash
# Create test plan
cat > test-plan.md << 'EOF'
# Test Feature

## Goal
Create a simple hello world function

## Requirements
- Function named `hello()`
- Returns "Hello, World!"
- Include test
EOF

# Run plan mode
ralph ./test-plan.md plan

# Verify progress file created
test -f test-plan_PROGRESS.md && echo "✓ Progress file created" || echo "✗ Failed"

# Check for task list
grep -q "Task" test-plan_PROGRESS.md && echo "✓ Tasks generated" || echo "✗ Failed"

# Verify status is IN_PROGRESS
grep -q "IN_PROGRESS" test-plan_PROGRESS.md && echo "✓ Status correct" || echo "✗ Failed"

# Clean up
rm test-plan.md test-plan_PROGRESS.md
```

#### Test 2: Build Mode (Dry Run)

```bash
# Create simple plan
cat > test-build.md << 'EOF'
# Test Build

## Goal
Add a comment to README

## Requirements
- Add "# Test Comment" to top of README.md

DO_NOT_COMMIT
EOF

# Backup README
cp README.md README.md.bak

# Run with 1 iteration
ralph ./test-build.md build 1

# Verify change was made
grep -q "Test Comment" README.md && echo "✓ File modified" || echo "✗ Failed"

# Restore
mv README.md.bak README.md
rm test-build.md test-build_PROGRESS.md
```

#### Test 3: Notifications

```bash
# Test notification system
ralph notify test

# Expected output:
# Testing Ralph notifications...
#
# Configured platforms:
#   - Slack: configured (or not configured)
#   - Discord: configured (or not configured)
#   ...
#
# Sending test message...
#   Slack: sent (or FAILED)
#   ...

# Verify notification appeared in Slack/Discord
```

#### Test 4: Configuration

```bash
# Test config commands
ralph config commit status

# Expected output shows current setting:
# Auto-commit setting:
#   Current: enabled (or disabled)

# Toggle setting
ralph config commit off
ralph config commit status | grep -q "disabled" && echo "✓ Config changed" || echo "✗ Failed"

# Restore
ralph config commit on
```

#### Test 5: Update System

```bash
# Check for updates
ralph update --check

# List versions
ralph update --list

# Verify current version shown
ralph update --list | grep -q "$(ralph --version | awk '{print $2}')" && echo "✓ Version found" || echo "✗ Failed"
```

### Continuous Integration Testing

Add Ralph tests to your CI/CD pipeline:

**GitHub Actions:**
```yaml
name: Ralph Tests

on: [push, pull_request]

jobs:
  test-ralph:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Run Ralph security tests
        run: ./tests/test-security.sh

      - name: Run validation tests
        run: ./lib/test-compat.sh

      - name: Verify constants
        run: |
          source ./lib/constants.sh
          test -n "$HTTP_MAX_TIME"
          test -n "$NOTIFY_MAX_RETRIES"
```

**Windows CI with PowerShell:**
```yaml
name: Ralph Windows Tests

on: [push, pull_request]

jobs:
  test-windows:
    runs-on: windows-latest
    steps:
      - uses: actions/checkout@v4

      - name: Run PowerShell compatibility tests
        shell: pwsh
        run: .\lib\test-compat.ps1

      - name: Run PowerShell notification tests
        shell: pwsh
        run: .\tests\test-notify.ps1
```

---

## Testing Ralph's Output

### Unit Testing Generated Code

Ralph should write code that passes your test suite. Ensure Ralph:

1. Runs tests after implementing
2. Fixes failing tests
3. Adds tests for new functionality

**Example plan with test requirements:**

```markdown
# Feature: User Authentication

## Goal
Add user login endpoint

## Requirements
- POST /auth/login endpoint
- Validates username/password
- Returns JWT token

## Testing Requirements
- Unit tests for login function
- Integration test for endpoint
- Test invalid credentials
- Test missing fields
- All tests must pass
```

### Manual Validation

After Ralph completes, manually verify:

```bash
# Review all commits
git log --oneline --author="Ralph" -10

# Check each commit
git show HEAD
git show HEAD~1

# Run full test suite
npm test           # Node.js
pytest             # Python
cargo test         # Rust
go test ./...      # Go

# Run linters
npm run lint       # JavaScript/TypeScript
pylint **/*.py     # Python
clippy             # Rust
go vet ./...       # Go

# Build project
npm run build      # Node.js
python setup.py build  # Python
cargo build        # Rust
go build           # Go
```

### Integration Testing

Verify Ralph's changes work with the rest of the system:

```bash
# Run integration tests
npm run test:integration
pytest tests/integration
cargo test --test integration

# Manual testing
# Start development server
npm run dev

# Test new features manually
curl http://localhost:3000/new-endpoint
# Or use Postman, browser, etc.
```

---

## Automated Testing in CI/CD

### GitHub Actions Example

```yaml
name: Test Ralph Output

on:
  push:
    branches: [ralph/**]  # Branches created by Ralph

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - name: Setup environment
        run: |
          # Install dependencies
          npm install  # or pip install -r requirements.txt

      - name: Lint
        run: |
          npm run lint
          # Fail if linting errors
          exit $?

      - name: Unit tests
        run: |
          npm test
          # Fail if tests fail
          exit $?

      - name: Integration tests
        run: |
          npm run test:integration
          exit $?

      - name: Security scan
        run: |
          npm audit --audit-level=high
          exit $?

      - name: Build
        run: |
          npm run build
          exit $?

      - name: Comment on PR
        if: always()
        uses: actions/github-script@v6
        with:
          script: |
            github.rest.issues.createComment({
              issue_number: context.issue.number,
              owner: context.repo.owner,
              repo: context.repo.repo,
              body: '✅ All tests passed! Ralph-generated code is ready for review.'
            })
```

### Pre-merge Validation

```bash
# Create git hook: .git/hooks/pre-push
#!/bin/bash

echo "Running tests before push..."

# Run tests
npm test
if [ $? -ne 0 ]; then
    echo "❌ Tests failed. Push aborted."
    exit 1
fi

# Run linter
npm run lint
if [ $? -ne 0 ]; then
    echo "❌ Linting failed. Push aborted."
    exit 1
fi

echo "✅ All checks passed. Pushing..."
exit 0
```

Make it executable:
```bash
chmod +x .git/hooks/pre-push
```

---

## Test-Driven Development with Ralph

Ralph works well with TDD. Write tests first, then let Ralph implement:

### Example TDD Workflow

**Step 1: Write tests**

```javascript
// tests/calculator.test.js
describe('Calculator', () => {
    test('add() should sum two numbers', () => {
        const calc = new Calculator();
        expect(calc.add(2, 3)).toBe(5);
    });

    test('subtract() should subtract two numbers', () => {
        const calc = new Calculator();
        expect(calc.subtract(5, 3)).toBe(2);
    });

    test('multiply() should multiply two numbers', () => {
        const calc = new Calculator();
        expect(calc.multiply(2, 3)).toBe(6);
    });
});
```

**Step 2: Create plan**

```markdown
# Implement Calculator

## Goal
Implement Calculator class to pass all tests

## Requirements
- Create Calculator class
- Implement add() method
- Implement subtract() method
- Implement multiply() method
- All tests in tests/calculator.test.js must pass

## Success Criteria
- `npm test` exits with code 0
- No linting errors
```

**Step 3: Run Ralph**

```bash
# Tests currently fail (no implementation)
npm test  # Fails

# Run Ralph
ralph ./calculator-plan.md build 5

# Tests now pass
npm test  # Passes ✓
```

---

## Regression Testing

Ensure Ralph doesn't break existing functionality:

### Create Regression Test Suite

```bash
# Before Ralph makes changes
npm test > baseline-tests.log

# Run Ralph
ralph ./plan.md build

# After Ralph
npm test > after-ralph-tests.log

# Compare
diff baseline-tests.log after-ralph-tests.log

# If different, investigate
```

### Automated Regression Check

```bash
#!/bin/bash
# regression-check.sh

# Get baseline
git checkout main
npm test > /tmp/baseline.log
BASELINE_EXIT=$?

# Get current
git checkout -
npm test > /tmp/current.log
CURRENT_EXIT=$?

# Compare
if [ $BASELINE_EXIT -eq 0 ] && [ $CURRENT_EXIT -ne 0 ]; then
    echo "❌ Regression detected! Tests passed on main but fail now."
    diff /tmp/baseline.log /tmp/current.log
    exit 1
fi

echo "✅ No regression detected"
exit 0
```

---

## Performance Testing

Verify Ralph's changes don't degrade performance:

### Benchmark Tests

```javascript
// benchmark.js
const { performance } = require('perf_hooks');

function benchmark(name, fn, iterations = 1000) {
    const start = performance.now();
    for (let i = 0; i < iterations; i++) {
        fn();
    }
    const end = performance.now();
    const duration = end - start;
    const avg = duration / iterations;

    console.log(`${name}: ${duration.toFixed(2)}ms total, ${avg.toFixed(4)}ms avg`);
}

// Before Ralph
benchmark('Old Implementation', () => {
    oldFunction();
});

// After Ralph
benchmark('New Implementation', () => {
    newFunction();
});
```

### Load Testing

```bash
# Before Ralph
ab -n 1000 -c 10 http://localhost:3000/endpoint > before.txt

# Run Ralph
ralph ./plan.md build

# After Ralph
ab -n 1000 -c 10 http://localhost:3000/endpoint > after.txt

# Compare
diff before.txt after.txt
```

---

## Coverage Testing

Ensure Ralph adds adequate test coverage:

### Measure Coverage

```bash
# JavaScript/TypeScript
npm run test:coverage
# or
jest --coverage

# Python
pytest --cov=src tests/

# Go
go test -coverprofile=coverage.out ./...
go tool cover -html=coverage.out

# Rust
cargo tarpaulin --out Html
```

### Coverage Requirements in Plan

```markdown
# Feature: User Service

## Goal
Add user management functionality

## Requirements
- Create User model
- CRUD operations
- Input validation

## Testing Requirements
- Unit tests for all public methods
- Test edge cases (null, empty, invalid)
- **Minimum 80% code coverage**
- Coverage report must show increase, not decrease
```

### Enforce Coverage Thresholds

```json
// jest.config.js
module.exports = {
    coverageThreshold: {
        global: {
            branches: 80,
            functions: 80,
            lines: 80,
            statements: 80
        }
    }
};
```

```yaml
# pytest.ini
[tool:pytest]
addopts = --cov=src --cov-fail-under=80
```

---

## Test Data Management

### Fixtures for Testing

```python
# tests/fixtures.py
import pytest

@pytest.fixture
def sample_user():
    return {
        "id": 1,
        "username": "testuser",
        "email": "test@example.com"
    }

@pytest.fixture
def mock_database():
    # Setup mock database
    db = MockDB()
    yield db
    # Teardown
    db.close()
```

### Test Plan with Fixtures

```markdown
# Feature: User Management

## Testing Requirements
- Use existing fixtures in tests/fixtures.py
- Add new fixtures for new entities
- Don't use real database in unit tests
- Integration tests can use test database
```

---

## Continuous Testing

### Watch Mode

Run tests continuously as Ralph makes changes:

```bash
# JavaScript/TypeScript
npm test -- --watch

# Python
pytest-watch

# Rust
cargo watch -x test

# Go
gow test ./...
```

### Monitor Ralph + Tests

```bash
# Terminal 1: Run Ralph
ralph ./plan.md build

# Terminal 2: Watch tests
npm test -- --watch

# Terminal 3: Watch logs
tail -f ~/ralph/monitor.log
```

---

## Validation Checklist

Use this checklist after Ralph completes:

### Code Quality
- [ ] All tests pass (`npm test`)
- [ ] Linting passes (`npm run lint`)
- [ ] Build succeeds (`npm run build`)
- [ ] No TypeScript errors (`tsc --noEmit`)
- [ ] Code coverage maintained or increased

### Functionality
- [ ] Feature works as described in plan
- [ ] Edge cases handled
- [ ] Error handling present
- [ ] Input validation added

### Security
- [ ] No hardcoded credentials
- [ ] No SQL injection vulnerabilities
- [ ] No XSS vulnerabilities
- [ ] Dependencies are secure (`npm audit`)

### Documentation
- [ ] Code is commented
- [ ] JSDoc/docstrings added
- [ ] README updated if needed
- [ ] CHANGELOG updated

### Performance
- [ ] No obvious performance regressions
- [ ] Efficient algorithms used
- [ ] No memory leaks

---

## Common Testing Issues

### Issue: Tests Fail After Ralph

**Diagnosis:**

```bash
# See what changed
git diff HEAD~1

# Run specific test
npm test -- --testNamePattern="failing test"

# Check for syntax errors
npm run lint
```

**Solutions:**

1. **Fix manually and commit**
2. **Revert and adjust plan:**
   ```bash
   git revert HEAD
   # Update plan with more specific requirements
   ralph ./plan.md build
   ```
3. **Let Ralph fix it:**
   ```markdown
   # Plan: Fix Tests

   ## Goal
   Fix failing tests after previous implementation

   ## Context
   Tests failing: [list failing tests]
   Error messages: [paste errors]

   ## Requirements
   - Fix all failing tests
   - Don't change test expectations
   - Fix implementation bugs
   ```

### Issue: Coverage Decreased

**Diagnosis:**

```bash
# Check coverage
npm run test:coverage

# See untested code
# Look at coverage report (usually in coverage/index.html)
```

**Solution:**

Add testing requirement to plan:
```markdown
## Testing Requirements
- Add tests for all new functions
- Maintain minimum 80% coverage
- Test edge cases: null, undefined, empty, invalid inputs
```

---

## Best Practices

### 1. Always Include Test Requirements in Plans

```markdown
# Good Plan
## Requirements
- Implement feature X
- Add unit tests
- Add integration tests
- All tests must pass
- Minimum 80% coverage

# Bad Plan
## Requirements
- Implement feature X
```

### 2. Run Plan Mode First

```bash
# Review task list before building
ralph ./plan.md plan
cat plan_PROGRESS.md

# Check if testing tasks included
grep -i "test" plan_PROGRESS.md
```

### 3. Limit Iterations for Testing

```bash
# Build incrementally, test frequently
ralph ./plan.md build 5
npm test  # Verify

ralph ./plan.md build 5
npm test  # Verify again
```

### 4. Use DO_NOT_COMMIT for Experiments

```markdown
# Experimental Feature

DO_NOT_COMMIT

## Goal
Try new approach, run tests, but don't commit yet
```

### 5. Keep Test Data Separate

```bash
# Don't let Ralph modify test fixtures
echo "tests/fixtures/**" >> .gitignore

# Or make them read-only
chmod -w tests/fixtures/*
```

---

## See Also

- [Usage Guide](usage.md) - Ralph commands
- [CI/CD Examples](CI_CD_EXAMPLES.md) - Automated testing in CI
- [Security Guide](SECURITY.md) - Security testing
- [Troubleshooting](TROUBLESHOOTING.md) - Test-related issues
