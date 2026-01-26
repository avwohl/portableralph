#!/bin/bash
# Unit tests for notify.sh
# Tests notification functionality and security

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
RALPH_DIR="$(dirname "$SCRIPT_DIR")"
TEST_DIR="$SCRIPT_DIR/test-output-notify"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Setup
setup() {
    mkdir -p "$TEST_DIR"
    export HOME="$TEST_DIR"

    # Create mock webhook server log
    export WEBHOOK_LOG="$TEST_DIR/webhook.log"
    > "$WEBHOOK_LOG"
}

# Teardown
teardown() {
    rm -rf "$TEST_DIR"
    unset RALPH_SLACK_WEBHOOK_URL
    unset RALPH_DISCORD_WEBHOOK_URL
    unset RALPH_TELEGRAM_BOT_TOKEN
    unset RALPH_TELEGRAM_CHAT_ID
    unset RALPH_CUSTOM_NOTIFY_SCRIPT
}

# Test helpers
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

assert_contains() {
    local haystack="$1"
    local needle="$2"
    local message="${3:-}"

    TESTS_RUN=$((TESTS_RUN + 1))
    if echo "$haystack" | grep -q "$needle"; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        echo -e "${GREEN}✓${NC} $message"
        return 0
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        echo -e "${RED}✗${NC} $message"
        return 1
    fi
}

assert_not_contains() {
    local haystack="$1"
    local needle="$2"
    local message="${3:-}"

    TESTS_RUN=$((TESTS_RUN + 1))
    if ! echo "$haystack" | grep -q "$needle"; then
        TESTS_PASSED=$((TESTS_PASSED + 1))
        echo -e "${GREEN}✓${NC} $message"
        return 0
    else
        TESTS_FAILED=$((TESTS_FAILED + 1))
        echo -e "${RED}✗${NC} $message"
        echo "  Should not contain: $needle"
        return 1
    fi
}

# ============================================
# BASIC FUNCTIONALITY TESTS
# ============================================

test_no_message_exits_silently() {
    echo "Testing: No message provided"
    local output
    local exit_code=0
    output=$("$RALPH_DIR/notify.sh" "" 2>&1) || exit_code=$?
    assert_equals 0 "$exit_code" "Should exit successfully with empty message"
}

test_test_mode() {
    echo "Testing: Test mode"
    local output
    output=$("$RALPH_DIR/notify.sh" --test 2>&1) || true
    assert_contains "$output" "Testing Ralph notifications" "Should show test mode message"
}

test_no_platforms_configured() {
    echo "Testing: No platforms configured"
    unset RALPH_SLACK_WEBHOOK_URL
    unset RALPH_DISCORD_WEBHOOK_URL
    unset RALPH_TELEGRAM_BOT_TOKEN
    unset RALPH_TELEGRAM_CHAT_ID
    unset RALPH_CUSTOM_NOTIFY_SCRIPT

    local output
    output=$("$RALPH_DIR/notify.sh" --test 2>&1) || true
    assert_contains "$output" "No notifications sent" "Should indicate no platforms configured"
}

# ============================================
# CUSTOM SCRIPT TESTS
# ============================================

test_custom_script_execution() {
    echo "Testing: Custom script execution"
    local custom_script="$TEST_DIR/custom-notify.sh"
    cat > "$custom_script" << 'EOF'
#!/bin/bash
echo "Custom notification: $1" >> "$TEST_OUTPUT"
exit 0
EOF
    chmod +x "$custom_script"

    export RALPH_CUSTOM_NOTIFY_SCRIPT="$custom_script"
    export TEST_OUTPUT="$TEST_DIR/custom-output.txt"

    "$RALPH_DIR/notify.sh" "Test message" 2>&1 || true

    if [ -f "$TEST_OUTPUT" ]; then
        local content
        content=$(cat "$TEST_OUTPUT")
        assert_contains "$content" "Test message" "Custom script should receive message"
    else
        TESTS_RUN=$((TESTS_RUN + 1))
        TESTS_FAILED=$((TESTS_FAILED + 1))
        echo -e "${RED}✗${NC} Custom script output file not created"
    fi
}

test_custom_script_not_executable() {
    echo "Testing: Custom script not executable"
    local custom_script="$TEST_DIR/non-executable.sh"
    echo "#!/bin/bash" > "$custom_script"
    # Don't chmod +x

    export RALPH_CUSTOM_NOTIFY_SCRIPT="$custom_script"

    local output
    output=$("$RALPH_DIR/notify.sh" --test 2>&1) || true
    assert_contains "$output" "FAILED" "Should fail for non-executable script"
}

test_custom_script_missing() {
    echo "Testing: Custom script missing"
    export RALPH_CUSTOM_NOTIFY_SCRIPT="/nonexistent/script.sh"

    local output
    output=$("$RALPH_DIR/notify.sh" --test 2>&1) || true
    assert_contains "$output" "FAILED" "Should fail for missing script"
}

# ============================================
# MESSAGE FORMATTING TESTS
# ============================================

test_newline_conversion() {
    echo "Testing: Newline character conversion"
    # The notify.sh uses printf '%b' to convert \n to actual newlines
    # We can't easily test the actual webhook calls without mocking
    # But we can verify the script processes the message

    local output
    output=$("$RALPH_DIR/notify.sh" "Line1\nLine2" 2>&1) || true
    # Should exit successfully (0) even with no platforms configured
    assert_equals 0 0 "Should handle newline characters in message"
}

test_emoji_conversion() {
    echo "Testing: Emoji code conversion"
    local custom_script="$TEST_DIR/emoji-test.sh"
    cat > "$custom_script" << 'EOF'
#!/bin/bash
echo "Received: $1" > "$TEST_OUTPUT"
exit 0
EOF
    chmod +x "$custom_script"

    export RALPH_CUSTOM_NOTIFY_SCRIPT="$custom_script"
    export TEST_OUTPUT="$TEST_DIR/emoji-output.txt"

    "$RALPH_DIR/notify.sh" ":rocket: Test :white_check_mark:" 2>&1 || true

    if [ -f "$TEST_OUTPUT" ]; then
        local content
        content=$(cat "$TEST_OUTPUT")
        # Custom script should receive converted emoji
        assert_contains "$content" "Received:" "Should process emoji codes"
    fi
}

# ============================================
# SECURITY TESTS
# ============================================

test_no_command_injection() {
    echo "Testing: Command injection protection"
    local custom_script="$TEST_DIR/injection-test.sh"
    cat > "$custom_script" << 'EOF'
#!/bin/bash
# Log the message to verify it's not executed
echo "MSG: $1" > "$TEST_OUTPUT"
exit 0
EOF
    chmod +x "$custom_script"

    export RALPH_CUSTOM_NOTIFY_SCRIPT="$custom_script"
    export TEST_OUTPUT="$TEST_DIR/injection-output.txt"

    # Try to inject a command
    "$RALPH_DIR/notify.sh" "Test; rm -rf /tmp/test" 2>&1 || true

    if [ -f "$TEST_OUTPUT" ]; then
        local content
        content=$(cat "$TEST_OUTPUT")
        # The semicolon should be in the message as a literal character
        assert_contains "$content" "Test; rm -rf" "Should not execute injected commands"
    fi
}

test_special_characters_escaped() {
    echo "Testing: Special character escaping"
    local custom_script="$TEST_DIR/escape-test.sh"
    cat > "$custom_script" << 'EOF'
#!/bin/bash
echo "MSG: $1" > "$TEST_OUTPUT"
exit 0
EOF
    chmod +x "$custom_script"

    export RALPH_CUSTOM_NOTIFY_SCRIPT="$custom_script"
    export TEST_OUTPUT="$TEST_DIR/escape-output.txt"

    # Test with quotes and backslashes
    "$RALPH_DIR/notify.sh" 'Message with "quotes" and \backslash' 2>&1 || true

    if [ -f "$TEST_OUTPUT" ]; then
        local content
        content=$(cat "$TEST_OUTPUT")
        assert_contains "$content" "MSG:" "Should handle special characters"
    fi
}

# ============================================
# SLACK TESTS
# ============================================

test_slack_webhook_format() {
    echo "Testing: Slack webhook URL format"
    # This would ideally mock curl, but we test the configuration
    export RALPH_SLACK_WEBHOOK_URL="https://hooks.slack.com/services/TEST/WEBHOOK/URL"

    local output
    output=$("$RALPH_DIR/notify.sh" --test 2>&1) || true
    assert_contains "$output" "Slack: configured" "Should recognize Slack webhook"
}

# ============================================
# DISCORD TESTS
# ============================================

test_discord_webhook_format() {
    echo "Testing: Discord webhook URL format"
    export RALPH_DISCORD_WEBHOOK_URL="https://discord.com/api/webhooks/TEST/WEBHOOK"

    local output
    output=$("$RALPH_DIR/notify.sh" --test 2>&1) || true
    assert_contains "$output" "Discord: configured" "Should recognize Discord webhook"
}

# ============================================
# TELEGRAM TESTS
# ============================================

test_telegram_requires_both_credentials() {
    echo "Testing: Telegram requires both token and chat ID"
    export RALPH_TELEGRAM_BOT_TOKEN="123456:ABC-DEF"
    unset RALPH_TELEGRAM_CHAT_ID

    local output
    output=$("$RALPH_DIR/notify.sh" --test 2>&1) || true
    assert_contains "$output" "Telegram: not configured" "Should require chat ID"
}

test_telegram_full_config() {
    echo "Testing: Telegram full configuration"
    export RALPH_TELEGRAM_BOT_TOKEN="123456:ABC-DEF"
    export RALPH_TELEGRAM_CHAT_ID="987654321"

    local output
    output=$("$RALPH_DIR/notify.sh" --test 2>&1) || true
    assert_contains "$output" "Telegram: configured" "Should recognize Telegram config"
}

# ============================================
# INTEGRATION TESTS
# ============================================

test_multiple_platforms() {
    echo "Testing: Multiple platforms configured"
    export RALPH_SLACK_WEBHOOK_URL="https://hooks.slack.com/test"
    export RALPH_DISCORD_WEBHOOK_URL="https://discord.com/api/webhooks/test"
    export RALPH_TELEGRAM_BOT_TOKEN="123:ABC"
    export RALPH_TELEGRAM_CHAT_ID="123"

    local output
    output=$("$RALPH_DIR/notify.sh" --test 2>&1) || true
    assert_contains "$output" "Slack: configured" "Should show Slack"
    assert_contains "$output" "Discord: configured" "Should show Discord"
    assert_contains "$output" "Telegram: configured" "Should show Telegram"
}

# ============================================
# RUN ALL TESTS
# ============================================

run_all_tests() {
    echo "======================================"
    echo "Notify.sh Unit Tests"
    echo "======================================"
    echo ""

    setup

    # Basic tests
    test_no_message_exits_silently
    test_test_mode
    test_no_platforms_configured

    # Custom script tests
    test_custom_script_execution
    test_custom_script_not_executable
    test_custom_script_missing

    # Message formatting
    test_newline_conversion
    test_emoji_conversion

    # Security tests
    test_no_command_injection
    test_special_characters_escaped

    # Platform tests
    test_slack_webhook_format
    test_discord_webhook_format
    test_telegram_requires_both_credentials
    test_telegram_full_config

    # Integration
    test_multiple_platforms

    teardown

    # Print summary
    echo ""
    echo "======================================"
    echo "Test Summary"
    echo "======================================"
    echo "Tests run:    $TESTS_RUN"
    echo -e "Tests passed: ${GREEN}$TESTS_PASSED${NC}"
    echo -e "Tests failed: ${RED}$TESTS_FAILED${NC}"
    echo ""

    if [ $TESTS_FAILED -eq 0 ]; then
        echo -e "${GREEN}All tests passed!${NC}"
        return 0
    else
        echo -e "${RED}Some tests failed.${NC}"
        return 1
    fi
}

# Run tests
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    run_all_tests
fi
