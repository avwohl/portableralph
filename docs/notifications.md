# Notifications

Get notified when Ralph starts, progresses, and completes work.

## Overview

Ralph supports five notification channels:

| Platform | Setup Time | Best For |
|:---------|:-----------|:---------|
| **Slack** | ~2 min | Team channels |
| **Discord** | ~1 min | Personal/community servers |
| **Telegram** | ~3 min | Mobile notifications |
| **Email** | ~5 min | Professional alerts |
| **Custom** | Varies | Proprietary systems |

Notifications fire when:

- Run **starts**
- **Every 5 iterations** (configurable via `RALPH_NOTIFY_FREQUENCY`)
- Work **completes** (when `RALPH_DONE` is detected on its own line)
- **Max iterations** reached

## Quick Setup

### Linux / macOS / Windows (WSL/Git Bash)

Run the interactive wizard:

```bash
ralph notify setup
```

Test your configuration:

```bash
ralph notify test
```

### Windows (PowerShell)

```powershell
# If PowerShell version available
ralph notify setup

# Otherwise, use Git Bash or configure manually
# Edit $HOME\.ralph.env with environment variables
```

See [Windows Setup Guide](WINDOWS_SETUP.md) for Windows-specific configuration instructions.

## Platform Setup

### Slack

1. Go to [api.slack.com/apps](https://api.slack.com/apps)
2. **Create New App** → **From scratch**
3. Name it "Ralph", select your workspace
4. Navigate to **Incoming Webhooks**
5. Toggle **Activate Incoming Webhooks** ON
6. Click **Add New Webhook to Workspace**
7. Select your channel → **Allow**
8. Copy the webhook URL

**Linux / macOS / Windows (WSL/Git Bash):**
```bash
export RALPH_SLACK_WEBHOOK_URL="https://hooks.slack.com/services/T00/B00/xxxx"
```

**Windows (PowerShell):**
```powershell
$env:RALPH_SLACK_WEBHOOK_URL = "https://hooks.slack.com/services/T00/B00/xxxx"
# Or add to $HOME\.ralph.env
```

**Optional configuration:**

```bash
export RALPH_SLACK_CHANNEL="#dev-alerts"
export RALPH_SLACK_USERNAME="Ralph Bot"
export RALPH_SLACK_ICON_EMOJI=":robot_face:"
```

### Discord

1. Open your Discord server
2. Right-click channel → **Edit Channel**
3. **Integrations** → **Webhooks**
4. **New Webhook** → Name it "Ralph"
5. **Copy Webhook URL**

**Linux / macOS / Windows (WSL/Git Bash):**
```bash
export RALPH_DISCORD_WEBHOOK_URL="https://discord.com/api/webhooks/xxx/yyy"
```

**Windows (PowerShell):**
```powershell
$env:RALPH_DISCORD_WEBHOOK_URL = "https://discord.com/api/webhooks/xxx/yyy"
# Or add to $HOME\.ralph.env
```

**Optional configuration:**

```bash
export RALPH_DISCORD_USERNAME="Ralph"
export RALPH_DISCORD_AVATAR_URL="https://example.com/avatar.png"
```

### Telegram

**Step 1: Create a bot**

1. Open Telegram, find [@BotFather](https://t.me/BotFather)
2. Send `/newbot`
3. Follow prompts to name your bot
4. Copy the token (format: `123456789:ABCdefGHI...`)

**Step 2: Get chat ID**

1. Start a chat with your new bot
2. Send any message
3. Visit: `https://api.telegram.org/bot<TOKEN>/getUpdates`
4. Find `"chat":{"id":YOUR_ID}` in the response

!!! note
    Group chat IDs are negative numbers (e.g., `-123456789`)

**Linux / macOS / Windows (WSL/Git Bash):**
```bash
export RALPH_TELEGRAM_BOT_TOKEN="123456789:ABCdefGHI..."
export RALPH_TELEGRAM_CHAT_ID="987654321"
```

**Windows (PowerShell):**
```powershell
$env:RALPH_TELEGRAM_BOT_TOKEN = "123456789:ABCdefGHI..."
$env:RALPH_TELEGRAM_CHAT_ID = "987654321"
# Or add to $HOME\.ralph.env
```

### Custom Script

For proprietary integrations—database bridges, internal APIs, SMS gateways.

Your script receives the message as `$1`:

```bash
#!/bin/bash
# my-notify.sh
MESSAGE="$1"

# Post to internal API
curl -X POST -d "text=$MESSAGE" https://internal.company.com/notify

# Or insert into database
docker exec db psql -c "INSERT INTO alerts (msg) VALUES ('$MESSAGE');"
```

```bash
export RALPH_CUSTOM_NOTIFY_SCRIPT="/path/to/my-notify.sh"
```

!!! warning "Important"
    Script must be executable (`chmod +x`). Exit code is ignored.

## Configuration Reference

| Variable | Platform | Description |
|:---------|:---------|:------------|
| `RALPH_SLACK_WEBHOOK_URL` | Slack | Webhook URL |
| `RALPH_SLACK_CHANNEL` | Slack | Override channel |
| `RALPH_SLACK_USERNAME` | Slack | Bot name |
| `RALPH_SLACK_ICON_EMOJI` | Slack | Bot icon |
| `RALPH_DISCORD_WEBHOOK_URL` | Discord | Webhook URL |
| `RALPH_DISCORD_USERNAME` | Discord | Bot name |
| `RALPH_DISCORD_AVATAR_URL` | Discord | Avatar image URL |
| `RALPH_TELEGRAM_BOT_TOKEN` | Telegram | Bot token |
| `RALPH_TELEGRAM_CHAT_ID` | Telegram | Target chat ID |
| `RALPH_CUSTOM_NOTIFY_SCRIPT` | Custom | Path to script |
| `RALPH_NOTIFY_FREQUENCY` | All | Notify every N iterations (default: 5) |

### Email

Ralph supports email notifications via SMTP, SendGrid, or AWS SES.

**Quick setup:**

```bash
export RALPH_EMAIL_TO="your-email@example.com"
export RALPH_EMAIL_FROM="ralph@example.com"

# Choose ONE delivery method:

# Option 1: SMTP (Gmail, Outlook, etc.)
export RALPH_SMTP_HOST="smtp.gmail.com"
export RALPH_SMTP_PORT="587"
export RALPH_SMTP_USER="your-email@gmail.com"
export RALPH_SMTP_PASSWORD="your-app-password"
export RALPH_SMTP_TLS="true"

# Option 2: SendGrid API
export RALPH_SENDGRID_API_KEY="SG.your-api-key-here"

# Option 3: AWS SES
export RALPH_AWS_SES_REGION="us-east-1"
export RALPH_AWS_ACCESS_KEY_ID="AKIAIOSFODNN7EXAMPLE"
export RALPH_AWS_SECRET_KEY="wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
```

See [Email Notifications Guide](EMAIL_NOTIFICATIONS.md) for detailed setup instructions.

## Persisting Configuration

### Linux / macOS / Windows (WSL/Git Bash)

The wizard saves to `~/.ralph.env`. Load automatically:

```bash
echo 'source ~/.ralph.env' >> ~/.bashrc
source ~/.bashrc
```

### Windows (PowerShell)

Configuration is saved to `$HOME\.ralph.env`. To load automatically:

```powershell
# Add to PowerShell profile
$ProfilePath = $PROFILE.CurrentUserAllHosts
if (-not (Test-Path $ProfilePath)) {
    New-Item -Path $ProfilePath -ItemType File -Force
}

Add-Content $ProfilePath @"
# Ralph configuration
if (Test-Path `$HOME\.ralph.env) {
    Get-Content `$HOME\.ralph.env | ForEach-Object {
        if (`$_ -match '^export\s+([^=]+)="([^"]*)"') {
            [Environment]::SetEnvironmentVariable(`$matches[1], `$matches[2], "Process")
        }
    }
}
"@

# Reload profile
. $PROFILE
```

## Multiple Platforms

Configure as many as you want—Ralph sends to **all** configured channels:

```bash
export RALPH_SLACK_WEBHOOK_URL="https://..."
export RALPH_DISCORD_WEBHOOK_URL="https://..."
export RALPH_TELEGRAM_BOT_TOKEN="..."
export RALPH_TELEGRAM_CHAT_ID="..."
```

## Message Format

```
🚀 Ralph Started
Plan: auth-feature
Mode: build
Repo: my-project

⚙️ Ralph Progress: Iteration 5 completed
Plan: auth-feature

✅ Ralph Complete!
Plan: auth-feature
Iterations: 12
Repo: my-project
```
