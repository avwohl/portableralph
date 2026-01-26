# Ralph Progress Monitor - Posts updates to Slack
# PowerShell version for Windows support
# Usage: .\monitor-progress.ps1 [interval_seconds] [repo_dir]

param(
    [int]$Interval = 300,  # Default: 5 minutes (300 seconds)
    [string]$RepoDir = $PWD.Path
)

$ErrorActionPreference = "Continue"

# Get script directory and load validation library
$SCRIPT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path
. "$SCRIPT_DIR\lib\validation.ps1"

# Load Ralph config for Slack webhook
$CONFIG_FILE = Join-Path $env:USERPROFILE ".ralph.env"

if (Test-Path $CONFIG_FILE) {
    Get-Content $CONFIG_FILE | ForEach-Object {
        $line = $_.Trim()
        if ($line -and !$line.StartsWith('#')) {
            if ($line -match '^(?:export\s+)?(\w+)="?([^"]*)"?$') {
                $varName = $matches[1]
                $varValue = $matches[2]
                Set-Item -Path "env:$varName" -Value $varValue -ErrorAction SilentlyContinue
            }
        }
    }
}

$SLACK_WEBHOOK = $env:RALPH_SLACK_WEBHOOK_URL

if (-not $SLACK_WEBHOOK) {
    Write-Host "❌ Error: RALPH_SLACK_WEBHOOK_URL not set in $CONFIG_FILE" -ForegroundColor Red
    Write-Host "Set it by adding to the file: export RALPH_SLACK_WEBHOOK_URL=`"https://hooks.slack.com/services/YOUR/WEBHOOK/URL`""
    exit 1
}

Write-Host "Ralph Progress Monitor Started" -ForegroundColor Green
Write-Host "Interval: ${Interval}s"
Write-Host "Repo: $RepoDir"
Write-Host "Slack: Enabled"
Write-Host ""

# Parse a progress file and return: @{Total=N; Completed=N; Status="..."}
function Get-ProgressInfo {
    param([string]$FilePath)

    if (-not (Test-Path $FilePath)) {
        return @{Total=0; Completed=0; Status="NOT_FOUND"}
    }

    $content = Get-Content $FilePath -Raw
    $lines = Get-Content $FilePath

    # Extract status
    $status = "UNKNOWN"
    $statusSection = $false
    foreach ($line in $lines) {
        if ($line -match '^## Status') {
            $statusSection = $true
            continue
        }
        if ($statusSection -and $line.Trim()) {
            $status = $line.Trim()
            break
        }
    }

    # Count tasks (checkbox format: - [ ] or - [x])
    $total = ([regex]::Matches($content, '(?m)^- \[(x| )\]')).Count
    $completed = ([regex]::Matches($content, '(?m)^- \[x\]')).Count

    # If no checkboxes found, try task list format
    if ($total -eq 0) {
        $total = ([regex]::Matches($content, '(?m)^(Task|Phase) [0-9]')).Count
        $completed = ([regex]::Matches($content, '(?m)^(Task|Phase) [0-9].*✅')).Count
    }

    return @{Total=$total; Completed=$completed; Status=$status}
}

# Calculate percentage
function Get-Percent {
    param([int]$Completed, [int]$Total)

    if ($Total -eq 0) {
        return 0
    }

    return [math]::Floor($Completed * 100 / $Total)
}

# Get last update time
function Get-LastUpdate {
    param([string]$FilePath)

    if (-not (Test-Path $FilePath)) {
        return "N/A"
    }

    $mtime = (Get-Item $FilePath).LastWriteTime
    $diff = (Get-Date) - $mtime
    $totalSeconds = [int]$diff.TotalSeconds

    if ($totalSeconds -lt 60) {
        return "${totalSeconds}s ago"
    } elseif ($totalSeconds -lt 3600) {
        return "$([math]::Floor($totalSeconds / 60))m ago"
    } else {
        return "$([math]::Floor($totalSeconds / 3600))h ago"
    }
}

# ConvertTo-JsonEscaped is now loaded from lib\validation.ps1

# Track consecutive notification failures
$SLACK_FAILURE_COUNT = 0
$SLACK_MAX_FAILURES = 3

# Send to Slack with error handling
function Send-SlackMessage {
    param([string]$Message)

    # Build JSON payload safely
    $payload = @{text = $Message} | ConvertTo-Json -Compress

    try {
        $response = Invoke-RestMethod -Uri $SLACK_WEBHOOK `
            -Method Post `
            -ContentType "application/json" `
            -Body $payload `
            -TimeoutSec 10 `
            -ErrorAction Stop

        $script:SLACK_FAILURE_COUNT = 0
        return $true
    } catch {
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $script:SLACK_FAILURE_COUNT++

        $errorType = "unknown"
        if ($_.Exception.Message) {
            $errorType = $_.Exception.Message
        }

        Write-Host "[$timestamp] Slack notification failed: $errorType (failure #$SLACK_FAILURE_COUNT)" -ForegroundColor Red

        if ($SLACK_FAILURE_COUNT -ge $SLACK_MAX_FAILURES) {
            Write-Host "[$timestamp] WARNING: $SLACK_FAILURE_COUNT consecutive Slack notification failures" -ForegroundColor Red
            Write-Host "[$timestamp] Check webhook URL: $SLACK_WEBHOOK" -ForegroundColor Red
            Write-Host "[$timestamp] Monitoring will continue, but notifications are not being delivered" -ForegroundColor Red
        }

        return $false
    }
}

# Track previous state to avoid spam
$PREV_PERCENT = @{}
$PREV_STATUS = @{}

# Main monitoring loop
$iteration = 0
while ($true) {
    $iteration++
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

    Write-Host "[$timestamp] Iteration $iteration" -ForegroundColor Yellow

    $updates = ""

    # Find all progress files
    $progressFiles = Get-ChildItem -Path $RepoDir -Filter "*_PROGRESS.md" -File

    foreach ($progressFile in $progressFiles) {
        $planName = $progressFile.BaseName -replace '_PROGRESS$', ''

        $info = Get-ProgressInfo $progressFile.FullName
        $percent = Get-Percent $info.Completed $info.Total
        $lastUpdate = Get-LastUpdate $progressFile.FullName

        # Determine status emoji
        $statusEmoji = "🔄"
        switch ($info.Status) {
            {$_ -in "COMPLETED", "DONE"} { $statusEmoji = "✅" }
            "IN_PROGRESS" { $statusEmoji = "🚧" }
            {$_ -in "FAILED", "ERROR"} { $statusEmoji = "❌" }
            "STALLED" { $statusEmoji = "⚠️" }
        }

        # Check if there's a significant change
        $prevPercent = if ($PREV_PERCENT.ContainsKey($planName)) { $PREV_PERCENT[$planName] } else { 0 }
        $prevStatus = if ($PREV_STATUS.ContainsKey($planName)) { $PREV_STATUS[$planName] } else { "" }

        $significantChange = $false
        if (($percent - $prevPercent) -ge 5 -or $info.Status -ne $prevStatus) {
            $significantChange = $true
        }

        # Build update message
        $updateLine = "$statusEmoji *$planName*: $($info.Completed)/$($info.Total) tasks ($percent%) - _$($info.Status)_ - Last: $lastUpdate"

        Write-Host "  $planName: $($info.Completed)/$($info.Total) ($percent%) - $($info.Status) - $lastUpdate"

        # Add to updates if significant or first iteration
        if ($iteration -eq 1 -or $significantChange) {
            $updates += "$updateLine`n"
            $PREV_PERCENT[$planName] = $percent
            $PREV_STATUS[$planName] = $info.Status
        }
    }

    # Send Slack update if there are changes
    if ($updates) {
        $slackMessage = "📊 *Ralph Progress Update* - $timestamp`n`n$updates"
        if (Send-SlackMessage $slackMessage) {
            Write-Host "  ✓ Posted to Slack" -ForegroundColor Green
        } else {
            Write-Host "  ⚠ Failed to post to Slack (monitoring continues)" -ForegroundColor Yellow
        }
    } else {
        Write-Host "  No significant changes"
    }

    Write-Host ""

    # Sleep until next check
    Start-Sleep -Seconds $Interval
}
