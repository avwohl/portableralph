#!/bin/bash
# Docker container test script for portableralph
# Tests all operations to verify everything works correctly

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[PASS]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[FAIL]${NC} $1"; }

# Test counter
TESTS_PASSED=0
TESTS_FAILED=0

run_test() {
    local name="$1"
    local cmd="$2"
    log_info "Testing: $name"
    if eval "$cmd" > /tmp/test_output.txt 2>&1; then
        log_success "$name"
        ((TESTS_PASSED++))
        return 0
    else
        log_error "$name"
        cat /tmp/test_output.txt
        ((TESTS_FAILED++))
        return 1
    fi
}

echo "=========================================="
echo "PortableRalph Docker Container Tests"
echo "=========================================="
echo ""

# Test 1: Check environment variables
log_info "=== Environment Setup Tests ==="
run_test "OPENROUTER_PROXY_KEY is set" '[ -n "$OPENROUTER_PROXY_KEY" ]'
run_test "RALPH_API_BASE is set" '[ -n "$RALPH_API_BASE" ]'
run_test "CLAUDE_MODEL is set" '[ -n "$CLAUDE_MODEL" ]'

# Test 2: Check OpenRouter whitelist proxy connectivity
log_info "=== Proxy Connectivity Tests ==="
run_test "Can reach OpenRouter whitelist proxy" 'curl -sf http://host.docker.internal:4001/health > /dev/null'
run_test "Proxy health check returns OK" 'curl -sf http://host.docker.internal:4001/health | grep -q "ok\|healthy"'

# Test 3: Check model alias resolution
log_info "=== Model Alias Tests ==="
run_test "Can list model aliases" 'curl -sf -H "X-Proxy-Key: $OPENROUTER_PROXY_KEY" http://host.docker.internal:4001/config/models | grep -q "fast"'
run_test "Fast alias resolves to DeepSeek" 'curl -sf -H "X-Proxy-Key: $OPENROUTER_PROXY_KEY" http://host.docker.internal:4001/config/models | grep -q "deepseek"'

# Test 4: Check Claude Code installation
log_info "=== Claude Code Tests ==="
run_test "Claude Code is installed" 'which claude'
run_test "Claude Code version check" 'claude --version 2>/dev/null || claude -v 2>/dev/null || true'

# Test 5: Check PortableRalph installation
log_info "=== PortableRalph Installation Tests ==="
run_test "ralph.sh exists" '[ -f ~/portableralph/ralph.sh ]'
run_test "ralph.sh is executable" '[ -x ~/portableralph/ralph.sh ]'
run_test "ralph command available" 'which ralph || [ -f ~/bin/ralph ] || [ -f ~/.local/bin/ralph ]'

# Test 6: Check library files
log_info "=== Library Tests ==="
run_test "validation-lib.sh exists" '[ -f ~/portableralph/lib/validation-lib.sh ]'
run_test "platform-utils.sh exists" '[ -f ~/portableralph/lib/platform-utils.sh ]'

# Test 7: Basic syntax check
log_info "=== Syntax Tests ==="
run_test "ralph.sh syntax is valid" 'bash -n ~/portableralph/ralph.sh'
run_test "notify.sh syntax is valid" 'bash -n ~/portableralph/notify.sh'

# Test 8: API call test (small request)
log_info "=== API Call Tests ==="
run_test "Can make API call through proxy" '
    curl -sf -X POST http://host.docker.internal:4001/v1/chat/completions \
        -H "Content-Type: application/json" \
        -H "X-Proxy-Key: $OPENROUTER_PROXY_KEY" \
        -d "{\"model\": \"fast\", \"messages\": [{\"role\": \"user\", \"content\": \"Say hi\"}], \"max_tokens\": 10}" \
        | grep -q "content"
'

# Test 9: Create a test workspace and plan file
log_info "=== Workspace Tests ==="
mkdir -p ~/test-workspace
run_test "Can create test workspace" '[ -d ~/test-workspace ]'

cat > ~/test-workspace/test-plan.md << 'EOF'
# Test Plan

## Goal
Create a simple hello world script

## Tasks
1. Create a bash script that prints "Hello, World!"
2. Make the script executable
3. Run the script and verify output
EOF
run_test "Can create plan file" '[ -f ~/test-workspace/test-plan.md ]'

# Summary
echo ""
echo "=========================================="
echo "Test Summary"
echo "=========================================="
echo -e "Tests Passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Tests Failed: ${RED}$TESTS_FAILED${NC}"
echo ""

if [ $TESTS_FAILED -eq 0 ]; then
    log_success "All tests passed!"
    exit 0
else
    log_error "Some tests failed"
    exit 1
fi
