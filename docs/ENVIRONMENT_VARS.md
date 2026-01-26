# Environment Variables Reference

Complete reference for all PortableRalph environment variables.

## Overview

Ralph uses environment variables stored in `~/.ralph.env` for configuration. This file is loaded automatically when Ralph runs.

**Location:** `~/.ralph.env` (Linux/Mac/WSL) or `C:\Users\Username\.ralph.env` (Windows)

**Permissions:** Should be `600` (read/write for owner only)

```bash
# Check permissions
ls -la ~/.ralph.env

# Fix if needed
chmod 600 ~/.ralph.env
```

---

## Core Configuration

### RALPH_AUTO_COMMIT

**Type:** Boolean (`true` or `false`)
**Default:** `true`
**Description:** Controls whether Ralph automatically commits after each iteration.

```bash
export RALPH_AUTO_COMMIT="true"   # Enable auto-commit (default)
export RALPH_AUTO_COMMIT="false"  # Disable auto-commit
```

**Usage:**

```bash
# Configure via command
ralph config commit on   # Sets to "true"
ralph config commit off  # Sets to "false"

# Check current setting
ralph config commit status
```

**When to Disable:**
- Experimental work
- Want to review changes before committing
- Large refactors requiring a single commit
- Learning/testing Ralph

**Notes:**
- Can be overridden per-plan by adding `DO_NOT_COMMIT` to plan file
- If disabled, you must commit manually

---

## Notification Variables

### Slack

#### RALPH_SLACK_WEBHOOK_URL

**Type:** URL (string)
**Required:** No
**Description:** Slack incoming webhook URL for notifications.

```bash
export RALPH_SLACK_WEBHOOK_URL="https://hooks.slack.com/services/T00/B00/xxxx"
```

**How to Get:**
1. Go to [api.slack.com/apps](https://api.slack.com/apps)
2. Create New App → From scratch
3. Enable Incoming Webhooks
4. Add webhook to workspace
5. Copy webhook URL

#### RALPH_SLACK_CHANNEL

**Type:** String
**Required:** No
**Default:** Channel configured in webhook
**Description:** Override default channel for Slack messages.

```bash
export RALPH_SLACK_CHANNEL="#dev-notifications"
# Or private channel/DM:
export RALPH_SLACK_CHANNEL="#private-channel"
export RALPH_SLACK_CHANNEL="@username"
```

#### RALPH_SLACK_USERNAME

**Type:** String
**Required:** No
**Default:** `"Ralph"`
**Description:** Display name for Ralph bot in Slack.

```bash
export RALPH_SLACK_USERNAME="Ralph Bot"
export RALPH_SLACK_USERNAME="AI Developer"
```

#### RALPH_SLACK_ICON_EMOJI

**Type:** Emoji code (string)
**Required:** No
**Default:** `:robot_face:`
**Description:** Bot icon in Slack messages.

```bash
export RALPH_SLACK_ICON_EMOJI=":robot_face:"
export RALPH_SLACK_ICON_EMOJI=":computer:"
export RALPH_SLACK_ICON_EMOJI=":gear:"
```

**Available Emojis:** Any standard Slack emoji code

---

### Discord

#### RALPH_DISCORD_WEBHOOK_URL

**Type:** URL (string)
**Required:** No
**Description:** Discord webhook URL for notifications.

```bash
export RALPH_DISCORD_WEBHOOK_URL="https://discord.com/api/webhooks/123/abc"
```

**How to Get:**
1. Right-click Discord channel → Edit Channel
2. Integrations → Webhooks
3. New Webhook
4. Copy webhook URL

#### RALPH_DISCORD_USERNAME

**Type:** String
**Required:** No
**Default:** `"Ralph"`
**Description:** Display name for Ralph bot in Discord.

```bash
export RALPH_DISCORD_USERNAME="Ralph"
export RALPH_DISCORD_USERNAME="Code Bot"
```

#### RALPH_DISCORD_AVATAR_URL

**Type:** URL (string)
**Required:** No
**Default:** None
**Description:** Avatar image URL for Discord webhook.

```bash
export RALPH_DISCORD_AVATAR_URL="https://example.com/avatar.png"
```

**Notes:**
- Must be publicly accessible URL
- Recommended: 128x128px or larger
- Formats: PNG, JPG, GIF

---

### Telegram

#### RALPH_TELEGRAM_BOT_TOKEN

**Type:** String (token)
**Required:** No (Required if using Telegram)
**Description:** Telegram bot token from @BotFather.

```bash
export RALPH_TELEGRAM_BOT_TOKEN="123456789:ABCdefGHIjklMNOpqrsTUVwxyz"
```

**How to Get:**
1. Message @BotFather on Telegram
2. Send `/newbot`
3. Follow prompts
4. Copy token

#### RALPH_TELEGRAM_CHAT_ID

**Type:** String or Number
**Required:** No (Required if using Telegram)
**Description:** Chat, group, or channel ID to send messages to.

```bash
export RALPH_TELEGRAM_CHAT_ID="987654321"      # Personal chat (positive)
export RALPH_TELEGRAM_CHAT_ID="-123456789"     # Group chat (negative)
export RALPH_TELEGRAM_CHAT_ID="-100123456789"  # Supergroup (negative, longer)
```

**How to Get:**
1. Start chat with your bot
2. Send any message
3. Visit: `https://api.telegram.org/bot<TOKEN>/getUpdates`
4. Find `"chat":{"id":YOUR_ID}` in JSON response

---

### Custom Notifications

#### RALPH_CUSTOM_NOTIFY_SCRIPT

**Type:** File path (string)
**Required:** No
**Description:** Path to custom notification script for proprietary integrations.

```bash
export RALPH_CUSTOM_NOTIFY_SCRIPT="/home/user/scripts/my-notify.sh"
export RALPH_CUSTOM_NOTIFY_SCRIPT="$HOME/bin/slack-db-bridge.sh"
```

**Requirements:**
- Must be executable (`chmod +x`)
- Receives notification message as first argument (`$1`)
- Exit code is ignored

**Example Script:**

```bash
#!/bin/bash
# my-notify.sh

MESSAGE="$1"

# Post to internal API
curl -X POST -d "text=$MESSAGE" https://internal.api/notify

# Or insert into database
psql -c "INSERT INTO notifications (msg) VALUES ('$MESSAGE');"

# Or send email
echo "$MESSAGE" | mail -s "Ralph Notification" admin@company.com
```

---

### Notification Behavior

#### RALPH_NOTIFY_FREQUENCY

**Type:** Integer
**Required:** No
**Default:** `5`
**Description:** How often to send progress notifications (every N iterations).

```bash
export RALPH_NOTIFY_FREQUENCY=5   # Notify every 5th iteration (default)
export RALPH_NOTIFY_FREQUENCY=1   # Notify every iteration
export RALPH_NOTIFY_FREQUENCY=10  # Notify every 10th iteration
```

**When Notifications Are Sent:**
- Start: Always
- Progress: Every Nth iteration (based on this setting)
- Complete: Always (when RALPH_DONE is detected)
- Max iterations reached: Always

**Examples:**

| Setting | Iterations | Notifications Sent |
|:--------|:-----------|:-------------------|
| `1` | 20 | Start, 1, 2, 3, ..., 20, Complete |
| `5` | 20 | Start, 5, 10, 15, 20, Complete |
| `10` | 20 | Start, 10, 20, Complete |

---

## Monitor-Specific Variables

These are used by `monitor-progress.sh` script.

### Repository Directory

**Not an env var** - passed as command-line argument:

```bash
~/ralph/monitor-progress.sh [interval] [repo_directory]

# Examples:
~/ralph/monitor-progress.sh 300 /home/user/project
~/ralph/monitor-progress.sh 60 "$(pwd)"
```

---

## Deprecated/Legacy Variables

### Variables No Longer Used

The following variables were used in older versions but are deprecated:

- `RALPH_WEBHOOK_URL` → Use `RALPH_SLACK_WEBHOOK_URL`
- `RALPH_NOTIFY_URL` → Use platform-specific variables

---

## Configurable Constants

Ralph uses configurable constants defined in `lib/constants.sh`. These can be customized by overriding them in your `~/.ralph.env`.

### Timeout Constants

```bash
# HTTP request timeouts (seconds)
export HTTP_MAX_TIME=10                    # Maximum time for HTTP request (default: 10)
export HTTP_CONNECT_TIMEOUT=5              # Connection establishment timeout (default: 5)
export HTTP_SMTP_TIMEOUT=30                # SMTP email send timeout (default: 30)

# Script execution timeouts
export CUSTOM_SCRIPT_TIMEOUT=30            # Custom notification script timeout (default: 30)

# Process management
export PROCESS_STOP_TIMEOUT=5              # Graceful shutdown timeout (default: 5)
export PROCESS_VERIFY_DELAY=1              # Delay before process verification (default: 1)

# Iteration timing
export ITERATION_DELAY=2                   # Delay between Ralph iterations (default: 2)
```

**Example - Faster timeouts for local development:**
```bash
# Add to ~/.ralph.env
export HTTP_MAX_TIME=5
export HTTP_CONNECT_TIMEOUT=3
export ITERATION_DELAY=1
```

### Rate Limiting Constants

```bash
# Notification rate limits
export RATE_LIMIT_MAX=60                   # Max notifications per minute (default: 60)
export RATE_LIMIT_WINDOW=60                # Rate limit window in seconds (default: 60)

# Email batching
export EMAIL_BATCH_DELAY_DEFAULT=300       # Delay before sending batch (default: 300 = 5min)
export EMAIL_BATCH_MAX_DEFAULT=10          # Max notifications per batch (default: 10)
export EMAIL_BATCH_LOCK_RETRIES=10         # Lock acquisition attempts (default: 10)
export EMAIL_BATCH_LOCK_DELAY=0.1          # Delay between lock attempts (default: 0.1s)
```

**Example - More aggressive email batching:**
```bash
# Add to ~/.ralph.env
export EMAIL_BATCH_DELAY_DEFAULT=600       # 10 minutes
export EMAIL_BATCH_MAX_DEFAULT=20          # 20 notifications per batch
```

### Retry Configuration Constants

```bash
# Notification retries
export NOTIFY_MAX_RETRIES=3                # Max retry attempts (default: 3)
export NOTIFY_RETRY_DELAY=2                # Initial retry delay in seconds (default: 2)

# Claude CLI retries
export CLAUDE_MAX_RETRIES=3                # Max Claude retry attempts (default: 3)
export CLAUDE_RETRY_DELAY=5                # Initial Claude retry delay (default: 5)

# Monitoring retries
export SLACK_MAX_FAILURES=3                # Max consecutive Slack failures (default: 3)
```

**Example - More persistent retries:**
```bash
# Add to ~/.ralph.env
export NOTIFY_MAX_RETRIES=5
export NOTIFY_RETRY_DELAY=3
```

### Monitoring Constants

```bash
# Progress monitoring
export MONITOR_INTERVAL_DEFAULT=300        # Default monitoring interval (default: 300 = 5min)
export MONITOR_INTERVAL_MIN=10             # Minimum allowed interval (default: 10)
export MONITOR_INTERVAL_MAX=86400          # Maximum allowed interval (default: 86400 = 24hr)

# Progress thresholds
export MONITOR_PROGRESS_THRESHOLD=5        # Min progress change for notification % (default: 5)

# Logging
export LOG_MAX_SIZE=10485760               # Max log size before rotation (default: 10MB)
export LOG_MAX_BACKUPS=5                   # Max log backups to keep (default: 5)

# Time display
export TIME_DISPLAY_MINUTE=60              # Threshold for showing minutes (default: 60s)
export TIME_DISPLAY_HOUR=3600              # Threshold for showing hours (default: 3600s)
```

**Example - More frequent monitoring:**
```bash
# Add to ~/.ralph.env
export MONITOR_INTERVAL_DEFAULT=60         # Check every minute
export MONITOR_PROGRESS_THRESHOLD=1        # Notify on 1% progress change
```

### Validation Limit Constants

```bash
# Numeric validation
export VALIDATION_MIN_DEFAULT=0            # Default minimum for validation (default: 0)
export VALIDATION_MAX_DEFAULT=999999       # Default maximum for validation (default: 999999)

# Iteration limits
export MAX_ITERATIONS_DEFAULT=0            # Default max iterations (default: 0 = unlimited)
export MAX_ITERATIONS_MIN=1                # Minimum when specified (default: 1)
export MAX_ITERATIONS_MAX=10000            # Maximum allowed (default: 10000)

# Security
export TOKEN_MASK_PREFIX_LENGTH=8          # Characters shown in masked tokens (default: 8)
export MESSAGE_TRUNCATE_LENGTH=100         # Log message truncation length (default: 100)
export ERROR_DETAILS_TRUNCATE_LENGTH=500   # Error details truncation (default: 500)
```

**Example - Stricter iteration limits:**
```bash
# Add to ~/.ralph.env
export MAX_ITERATIONS_MAX=1000             # Lower max iterations
```

### Network Constants

```bash
# HTTP status codes
export HTTP_STATUS_SUCCESS_MIN=200         # Min successful status (default: 200)
export HTTP_STATUS_SUCCESS_MAX=300         # Max successful status (default: 300)
```

### Security Constants

```bash
# File permissions
export CONFIG_FILE_MODE=600                # Config file permissions (default: 600)

# Telegram validation
export TELEGRAM_TOKEN_PREFIX_MIN=8         # Min digits in token prefix (default: 8)
export TELEGRAM_TOKEN_PREFIX_MAX=10        # Max digits in token prefix (default: 10)
export TELEGRAM_TOKEN_SECRET_LENGTH=35     # Token secret length (default: 35)
```

**Example - Stricter file permissions:**
```bash
# Add to ~/.ralph.env
export CONFIG_FILE_MODE=400                # Read-only for owner
```

### Display Constants

```bash
# UI elements
export SPINNER_FRAMES=10                   # Loading spinner frames (default: 10)
export LOG_TAIL_LINES=10                   # Lines shown when tailing logs (default: 10)
export UPDATE_MAX_BACKUPS=5                # Max update backups to keep (default: 5)
```

### Customizing Constants

To customize any constant:

1. **Add to `~/.ralph.env`:**
   ```bash
   # Custom timeouts
   export HTTP_MAX_TIME=15
   export CUSTOM_SCRIPT_TIMEOUT=60

   # Custom limits
   export MAX_ITERATIONS_MAX=5000
   export RATE_LIMIT_MAX=120
   ```

2. **Reload configuration:**
   ```bash
   source ~/.ralph.env
   ```

3. **Verify values:**
   ```bash
   # Check a specific constant
   echo $HTTP_MAX_TIME

   # Check all Ralph constants
   env | grep -E 'HTTP_|NOTIFY_|MAX_|TIMEOUT'
   ```

### Constants Reference Location

All constants are defined in: `/home/ubuntu/ralph/lib/constants.sh`

View the file to see all available constants and their default values:

```bash
cat ~/ralph/lib/constants.sh
```

---

## Configuration File Template

Complete `~/.ralph.env` template with all variables:

```bash
# PortableRalph Configuration
# Generated: 2026-01-23

# ============================================
# CORE SETTINGS
# ============================================

# Auto-commit after each iteration
export RALPH_AUTO_COMMIT="true"

# ============================================
# SLACK NOTIFICATIONS
# ============================================

export RALPH_SLACK_WEBHOOK_URL="https://hooks.slack.com/services/T00/B00/xxxx"
export RALPH_SLACK_CHANNEL="#dev-notifications"
export RALPH_SLACK_USERNAME="Ralph"
export RALPH_SLACK_ICON_EMOJI=":robot_face:"

# ============================================
# DISCORD NOTIFICATIONS
# ============================================

export RALPH_DISCORD_WEBHOOK_URL="https://discord.com/api/webhooks/123/abc"
export RALPH_DISCORD_USERNAME="Ralph"
export RALPH_DISCORD_AVATAR_URL="https://example.com/avatar.png"

# ============================================
# TELEGRAM NOTIFICATIONS
# ============================================

export RALPH_TELEGRAM_BOT_TOKEN="123456789:ABCdefGHIjklMNOpqrsTUVwxyz"
export RALPH_TELEGRAM_CHAT_ID="987654321"

# ============================================
# CUSTOM NOTIFICATIONS
# ============================================

export RALPH_CUSTOM_NOTIFY_SCRIPT="$HOME/scripts/my-notify.sh"

# ============================================
# NOTIFICATION BEHAVIOR
# ============================================

# Send progress notification every N iterations
export RALPH_NOTIFY_FREQUENCY=5
```

---

## Setting Variables

### Method 1: Setup Wizard (Recommended)

```bash
ralph notify setup
```

Interactive wizard creates `~/.ralph.env` automatically.

### Method 2: Manual Configuration

```bash
# Create file
cat > ~/.ralph.env << 'EOF'
export RALPH_SLACK_WEBHOOK_URL="https://..."
export RALPH_AUTO_COMMIT="true"
EOF

# Set permissions
chmod 600 ~/.ralph.env

# Load in current shell
source ~/.ralph.env
```

### Method 3: Command-Line for Auto-Commit

```bash
ralph config commit on   # Enable
ralph config commit off  # Disable
```

---

## Loading Configuration

### Automatic Loading

Ralph automatically loads `~/.ralph.env` when it runs. No action needed.

### Manual Loading

Load in current shell session:

```bash
source ~/.ralph.env
```

Permanent loading (add to shell profile):

```bash
# For bash
echo 'source ~/.ralph.env' >> ~/.bashrc

# For zsh
echo 'source ~/.ralph.env' >> ~/.zshrc

# Reload shell
source ~/.bashrc  # or ~/.zshrc
```

---

## Verifying Configuration

### Check Variables Are Set

```bash
# Check specific variable
echo $RALPH_SLACK_WEBHOOK_URL

# Check all Ralph variables
env | grep RALPH

# Pretty print
env | grep RALPH | sort
```

### Test Configuration

```bash
# Test notifications
ralph notify test

# Test auto-commit setting
ralph config commit status
```

---

## Security Best Practices

### 1. File Permissions

```bash
# Config file should be readable by owner only
chmod 600 ~/.ralph.env

# Verify
ls -la ~/.ralph.env
# Should show: -rw-------
```

### 2. Never Commit to Git

```bash
# Add to .gitignore
echo ".ralph.env" >> .gitignore
echo "~/.ralph.env" >> .gitignore

# Verify not tracked
git status | grep ralph.env
# Should show nothing
```

### 3. Rotate Credentials

```bash
# Regenerate webhooks every 90 days
# Update ~/.ralph.env
# Reload: source ~/.ralph.env
```

### 4. Use Environment-Specific Configs

```bash
# Development
~/.ralph.env.dev

# Staging
~/.ralph.env.staging

# Production
~/.ralph.env.prod

# Load appropriate one
source ~/.ralph.env.dev
```

---

## Troubleshooting

### Variables Not Loaded

**Problem:** `echo $RALPH_SLACK_WEBHOOK_URL` returns empty

**Solutions:**

```bash
# 1. Check file exists
ls -la ~/.ralph.env

# 2. Check syntax
bash -n ~/.ralph.env

# 3. Load manually
source ~/.ralph.env

# 4. Check shell profile loads it
grep "ralph.env" ~/.bashrc
```

### Notifications Not Working

**Problem:** Ralph runs but no notifications appear

**Solutions:**

```bash
# 1. Verify variables are set
env | grep RALPH

# 2. Test notifications
ralph notify test

# 3. Check webhook URLs are valid
curl -X POST -d '{"text":"test"}' "$RALPH_SLACK_WEBHOOK_URL"
```

### Permission Denied

**Problem:** `Permission denied: ~/.ralph.env`

**Solution:**

```bash
chmod 600 ~/.ralph.env
```

### Syntax Errors

**Problem:** `bash: ~/.ralph.env: line 5: syntax error`

**Solution:**

```bash
# Check syntax
bash -n ~/.ralph.env

# Fix errors (usually unmatched quotes)
# Example of correct syntax:
export RALPH_SLACK_WEBHOOK_URL="https://..."
```

---

## CI/CD Usage

### GitHub Actions

```yaml
env:
  RALPH_SLACK_WEBHOOK_URL: ${{ secrets.RALPH_SLACK_WEBHOOK }}
  RALPH_AUTO_COMMIT: "false"
  RALPH_NOTIFY_FREQUENCY: "10"
```

### GitLab CI

```yaml
variables:
  RALPH_SLACK_WEBHOOK_URL:
    value: $SLACK_WEBHOOK
    masked: true
  RALPH_AUTO_COMMIT: "false"
```

### Jenkins

```groovy
environment {
    RALPH_SLACK_WEBHOOK_URL = credentials('ralph-slack-webhook')
    RALPH_AUTO_COMMIT = 'false'
}
```

---

## See Also

- [Notifications Guide](notifications.md) - Setup Slack, Discord, Telegram
- [Usage Guide](usage.md) - Ralph commands
- [Security Guide](SECURITY.md) - Secure configuration
- [Installation](installation.md) - Initial setup
