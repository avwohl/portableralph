# notify.ps1 - Multi-platform notifications for Ralph
# PowerShell version for Windows support
# Supports: Slack, Discord, Telegram, Email, and Custom scripts
#
# Configuration (via environment variables):
#
#   SLACK:
#     RALPH_SLACK_WEBHOOK_URL  - Slack incoming webhook URL
#     RALPH_SLACK_CHANNEL      - Override default channel (optional)
#     RALPH_SLACK_USERNAME     - Bot username (default: "Ralph")
#     RALPH_SLACK_ICON_EMOJI   - Bot icon (default: ":robot_face:")
#
#   DISCORD:
#     RALPH_DISCORD_WEBHOOK_URL - Discord webhook URL
#     RALPH_DISCORD_USERNAME    - Bot username (default: "Ralph")
#     RALPH_DISCORD_AVATAR_URL  - Bot avatar URL (optional)
#
#   TELEGRAM:
#     RALPH_TELEGRAM_BOT_TOKEN - Telegram bot token (from @BotFather)
#     RALPH_TELEGRAM_CHAT_ID   - Chat/group/channel ID to send to
#
#   EMAIL:
#     RALPH_EMAIL_TO           - Recipient email address(es) (comma-separated)
#     RALPH_EMAIL_FROM         - Sender email address
#     RALPH_EMAIL_SUBJECT      - Email subject prefix (default: "Ralph Notification")
#
#     SMTP Configuration:
#     RALPH_EMAIL_SMTP_SERVER  - SMTP server hostname
#     RALPH_EMAIL_PORT         - SMTP server port (default: 587)
#     RALPH_EMAIL_USER         - SMTP username
#     RALPH_EMAIL_PASS         - SMTP password
#     RALPH_EMAIL_USE_SSL      - Use SSL (true/false, default: true)
#
#   CUSTOM:
#     RALPH_CUSTOM_NOTIFY_SCRIPT - Path to custom notification script
#
# Usage:
#   .\notify.ps1 "Your message here"
#   .\notify.ps1 --test              # Send test notification to all configured platforms

param(
    [Parameter(Position=0)]
    [string]$Message,

    [switch]$Test
)

$ErrorActionPreference = "Continue"

$RALPH_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path

# Load validation library
$ValidationLib = Join-Path $RALPH_DIR "lib\validation.ps1"
if (Test-Path $ValidationLib) {
    . $ValidationLib
}

# Check for test mode
if ($Test) {
    $TEST_MODE = $true
    $Message = "Test notification from Ralph"
} else {
    $TEST_MODE = $false
}

# Exit if no message provided
if (-not $Message) {
    exit 0
}

# Convert literal \n to actual newlines
$Message = $Message -replace '\\n', "`n"

# Track if any notification was sent
$SENT_ANY = $false

# ============================================
# SLACK
# ============================================
function Send-Slack {
    param([string]$Msg)

    if (-not $env:RALPH_SLACK_WEBHOOK_URL) {
        return $true
    }

    $username = if ($env:RALPH_SLACK_USERNAME) { $env:RALPH_SLACK_USERNAME } else { "Ralph" }
    $iconEmoji = if ($env:RALPH_SLACK_ICON_EMOJI) { $env:RALPH_SLACK_ICON_EMOJI } else { ":robot_face:" }
    $channel = $env:RALPH_SLACK_CHANNEL

    # Build JSON payload
    $payload = @{
        text = $Msg
        username = $username
        icon_emoji = $iconEmoji
    }

    if ($channel) {
        $payload.channel = $channel
    }

    $jsonPayload = $payload | ConvertTo-Json -Compress

    try {
        $response = Invoke-RestMethod -Uri $env:RALPH_SLACK_WEBHOOK_URL `
            -Method Post `
            -ContentType "application/json" `
            -Body $jsonPayload `
            -TimeoutSec 10 `
            -ErrorAction Stop

        $script:SENT_ANY = $true
        if ($TEST_MODE) {
            Write-Host "  Slack: sent"
        }
        return $true
    } catch {
        if ($TEST_MODE) {
            Write-Host "  Slack: FAILED"
        }
        return $false
    }
}

# ============================================
# DISCORD
# ============================================
function Send-Discord {
    param([string]$Msg)

    if (-not $env:RALPH_DISCORD_WEBHOOK_URL) {
        return $true
    }

    $username = if ($env:RALPH_DISCORD_USERNAME) { $env:RALPH_DISCORD_USERNAME } else { "Ralph" }
    $avatarUrl = $env:RALPH_DISCORD_AVATAR_URL

    # Convert Slack-style formatting to Discord markdown
    $discordMsg = $Msg -replace '\*([^*]*)\*', '**$1**'

    # Build JSON payload
    $payload = @{
        content = $discordMsg
        username = $username
    }

    if ($avatarUrl) {
        $payload.avatar_url = $avatarUrl
    }

    $jsonPayload = $payload | ConvertTo-Json -Compress

    try {
        $response = Invoke-RestMethod -Uri $env:RALPH_DISCORD_WEBHOOK_URL `
            -Method Post `
            -ContentType "application/json" `
            -Body $jsonPayload `
            -TimeoutSec 10 `
            -ErrorAction Stop

        $script:SENT_ANY = $true
        if ($TEST_MODE) {
            Write-Host "  Discord: sent"
        }
        return $true
    } catch {
        if ($TEST_MODE) {
            Write-Host "  Discord: FAILED"
        }
        return $false
    }
}

# ============================================
# TELEGRAM
# ============================================
function Send-Telegram {
    param([string]$Msg)

    if (-not $env:RALPH_TELEGRAM_BOT_TOKEN -or -not $env:RALPH_TELEGRAM_CHAT_ID) {
        return $true
    }

    # Convert Slack-style formatting to Telegram
    $telegramMsg = $Msg
    $telegramMsg = $telegramMsg -replace ':rocket:', '🚀'
    $telegramMsg = $telegramMsg -replace ':white_check_mark:', '✅'
    $telegramMsg = $telegramMsg -replace ':warning:', '⚠️'
    $telegramMsg = $telegramMsg -replace ':gear:', '⚙️'
    $telegramMsg = $telegramMsg -replace ':robot_face:', '🤖'
    $telegramMsg = $telegramMsg -replace ':x:', '❌'
    $telegramMsg = $telegramMsg -replace ':clipboard:', '📋'

    # Escape special characters for Telegram MarkdownV2
    $telegramMsg = $telegramMsg -replace '\.', '\.'
    $telegramMsg = $telegramMsg -replace '!', '\!'
    $telegramMsg = $telegramMsg -replace '-', '\-'
    $telegramMsg = $telegramMsg -replace '=', '\='
    $telegramMsg = $telegramMsg -replace '\|', '\|'
    $telegramMsg = $telegramMsg -replace '\{', '\{'
    $telegramMsg = $telegramMsg -replace '\}', '\}'
    $telegramMsg = $telegramMsg -replace '\(', '\('
    $telegramMsg = $telegramMsg -replace '\)', '\)'
    $telegramMsg = $telegramMsg -replace '\[', '\['
    $telegramMsg = $telegramMsg -replace '\]', '\]'

    $apiUrl = "https://api.telegram.org/bot$($env:RALPH_TELEGRAM_BOT_TOKEN)/sendMessage"

    # Build JSON payload
    $payload = @{
        chat_id = $env:RALPH_TELEGRAM_CHAT_ID
        text = $telegramMsg
        parse_mode = "MarkdownV2"
    } | ConvertTo-Json -Compress

    try {
        $response = Invoke-RestMethod -Uri $apiUrl `
            -Method Post `
            -ContentType "application/json" `
            -Body $payload `
            -TimeoutSec 10 `
            -ErrorAction Stop

        $script:SENT_ANY = $true
        if ($TEST_MODE) {
            Write-Host "  Telegram: sent"
        }
        return $true
    } catch {
        if ($TEST_MODE) {
            Write-Host "  Telegram: FAILED"
        }
        return $false
    }
}

# ============================================
# EMAIL
# ============================================
function Send-Email {
    param([string]$Msg)

    if (-not $env:RALPH_EMAIL_TO -or -not $env:RALPH_EMAIL_FROM) {
        return $true
    }

    $to = $env:RALPH_EMAIL_TO
    $from = $env:RALPH_EMAIL_FROM
    $subject = if ($env:RALPH_EMAIL_SUBJECT) { $env:RALPH_EMAIL_SUBJECT } else { "Ralph Notification" }

    # Determine message type from content
    $msgType = "info"
    if ($Msg -match "(?i)(error|failed|critical)") {
        $msgType = "error"
        $subject = "$subject - Error"
    } elseif ($Msg -match "(?i)warning") {
        $msgType = "warning"
        $subject = "$subject - Warning"
    } elseif ($Msg -match "(?i)(success|completed|done)") {
        $msgType = "success"
        $subject = "$subject - Success"
    } elseif ($Msg -match "(?i)(progress|running|processing)") {
        $msgType = "progress"
        $subject = "$subject - Progress Update"
    }

    # Prepare email body (use template if available)
    $templatePath = Join-Path $RALPH_DIR "templates\email-notification.html"
    $textTemplatePath = Join-Path $RALPH_DIR "templates\email-notification.txt"

    $body = $Msg
    $isHtml = $false

    if (Test-Path $templatePath) {
        $template = Get-Content $templatePath -Raw
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss K"
        $hostname = $env:COMPUTERNAME
        $project = $env:RALPH_PROJECT_NAME

        # Determine type label
        $typeLabel = "Information"
        switch ($msgType) {
            "success" { $typeLabel = "Success" }
            "warning" { $typeLabel = "Warning" }
            "error" { $typeLabel = "Error" }
            "progress" { $typeLabel = "Progress Update" }
        }

        # Replace template variables
        $body = $template -replace '\{\{MESSAGE\}\}', ($Msg -replace '<', '&lt;' -replace '>', '&gt;')
        $body = $body -replace '\{\{TYPE\}\}', $msgType
        $body = $body -replace '\{\{TYPE_LABEL\}\}', $typeLabel
        $body = $body -replace '\{\{TIMESTAMP\}\}', $timestamp
        $body = $body -replace '\{\{HOSTNAME\}\}', $hostname

        # Handle project section
        if ($project) {
            $body = $body -replace '\{\{#HAS_PROJECT\}\}', ''
            $body = $body -replace '\{\{/HAS_PROJECT\}\}', ''
            $body = $body -replace '\{\{PROJECT\}\}', $project
        } else {
            $body = $body -replace '(?s)\{\{#HAS_PROJECT\}\}.*?\{\{/HAS_PROJECT\}\}', ''
        }

        # Remove batch sections (not implemented in PS version)
        $body = $body -replace '(?s)\{\{#HAS_BATCHED\}\}.*?\{\{/HAS_BATCHED\}\}', ''

        $isHtml = $true
    } elseif (Test-Path $textTemplatePath) {
        $template = Get-Content $textTemplatePath -Raw
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss K"
        $hostname = $env:COMPUTERNAME

        $body = $template -replace '\{\{MESSAGE\}\}', $Msg
        $body = $body -replace '\{\{TIMESTAMP\}\}', $timestamp
        $body = $body -replace '\{\{HOSTNAME\}\}', $hostname
    }

    try {
        # Try Send-MailMessage (built-in PowerShell cmdlet)
        if ($env:RALPH_EMAIL_SMTP_SERVER -and $env:RALPH_EMAIL_USER -and $env:RALPH_EMAIL_PASS) {
            $smtpServer = $env:RALPH_EMAIL_SMTP_SERVER
            $smtpPort = if ($env:RALPH_EMAIL_PORT) { [int]$env:RALPH_EMAIL_PORT } else { 587 }
            $useSSL = if ($env:RALPH_EMAIL_USE_SSL -eq "false") { $false } else { $true }

            $credential = New-Object System.Management.Automation.PSCredential(
                $env:RALPH_EMAIL_USER,
                (ConvertTo-SecureString $env:RALPH_EMAIL_PASS -AsPlainText -Force)
            )

            $mailParams = @{
                To = $to -split ','
                From = $from
                Subject = $subject
                Body = $body
                SmtpServer = $smtpServer
                Port = $smtpPort
                Credential = $credential
                UseSsl = $useSSL
            }

            if ($isHtml) {
                $mailParams.BodyAsHtml = $true
            }

            Send-MailMessage @mailParams -ErrorAction Stop

            $script:SENT_ANY = $true
            if ($TEST_MODE) {
                Write-Host "  Email: sent (to: $to)"
            }
            return $true
        } else {
            if ($TEST_MODE) {
                Write-Host "  Email: not configured (missing SMTP settings)"
            }
            return $true
        }
    } catch {
        if ($TEST_MODE) {
            Write-Host "  Email: FAILED ($($_.Exception.Message))"
        }
        return $false
    }
}

# ============================================
# CUSTOM SCRIPT
# ============================================
function Send-Custom {
    param([string]$Msg)

    if (-not $env:RALPH_CUSTOM_NOTIFY_SCRIPT) {
        return $true
    }

    # Verify script exists
    if (-not (Test-Path $env:RALPH_CUSTOM_NOTIFY_SCRIPT)) {
        if ($TEST_MODE) {
            Write-Host "  Custom: FAILED (script not found or not executable)"
        }
        return $false
    }

    # Strip Slack-style emoji codes for cleaner output
    $cleanMsg = $Msg
    $cleanMsg = $cleanMsg -replace ':rocket:', '🚀'
    $cleanMsg = $cleanMsg -replace ':white_check_mark:', '✅'
    $cleanMsg = $cleanMsg -replace ':warning:', '⚠️'
    $cleanMsg = $cleanMsg -replace ':gear:', '⚙️'
    $cleanMsg = $cleanMsg -replace ':robot_face:', '🤖'
    $cleanMsg = $cleanMsg -replace ':x:', '❌'

    try {
        # Detect script type and execute appropriately
        $ext = [System.IO.Path]::GetExtension($env:RALPH_CUSTOM_NOTIFY_SCRIPT)
        if ($ext -eq ".ps1") {
            & $env:RALPH_CUSTOM_NOTIFY_SCRIPT $cleanMsg 2>$null | Out-Null
        } else {
            # For .sh or other scripts on Windows (WSL or Git Bash)
            & bash $env:RALPH_CUSTOM_NOTIFY_SCRIPT $cleanMsg 2>$null | Out-Null
        }

        $script:SENT_ANY = $true
        if ($TEST_MODE) {
            Write-Host "  Custom: sent"
        }
        return $true
    } catch {
        if ($TEST_MODE) {
            Write-Host "  Custom: FAILED"
        }
        return $false
    }
}

# ============================================
# MAIN
# ============================================

if ($TEST_MODE) {
    Write-Host "Testing Ralph notifications..."
    Write-Host ""
    Write-Host "Configured platforms:"
    if ($env:RALPH_SLACK_WEBHOOK_URL) {
        Write-Host "  - Slack: configured"
    } else {
        Write-Host "  - Slack: not configured"
    }
    if ($env:RALPH_DISCORD_WEBHOOK_URL) {
        Write-Host "  - Discord: configured"
    } else {
        Write-Host "  - Discord: not configured"
    }
    if ($env:RALPH_TELEGRAM_BOT_TOKEN -and $env:RALPH_TELEGRAM_CHAT_ID) {
        Write-Host "  - Telegram: configured"
    } else {
        Write-Host "  - Telegram: not configured"
    }
    if ($env:RALPH_EMAIL_TO -and $env:RALPH_EMAIL_FROM) {
        $emailMethod = "SMTP"
        if ($env:RALPH_EMAIL_SMTP_SERVER) {
            $emailMethod = "SMTP ($($env:RALPH_EMAIL_SMTP_SERVER))"
        }
        Write-Host "  - Email: configured (to: $($env:RALPH_EMAIL_TO), method: $emailMethod)"
    } else {
        Write-Host "  - Email: not configured"
    }
    if ($env:RALPH_CUSTOM_NOTIFY_SCRIPT) {
        Write-Host "  - Custom: configured ($($env:RALPH_CUSTOM_NOTIFY_SCRIPT))"
    } else {
        Write-Host "  - Custom: not configured"
    }
    Write-Host ""
    Write-Host "Sending test message..."
}

# Send to all configured platforms
Send-Slack $Message | Out-Null
Send-Discord $Message | Out-Null
Send-Telegram $Message | Out-Null
Send-Email $Message | Out-Null
Send-Custom $Message | Out-Null

if ($TEST_MODE) {
    Write-Host ""
    if ($SENT_ANY) {
        Write-Host "Test complete! Check your notification channels."
    } else {
        Write-Host "No notifications sent. Configure at least one platform."
        Write-Host "Run: .\ralph.ps1 notify setup"
    }
}

exit 0
