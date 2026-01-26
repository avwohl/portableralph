# Launch Scripts Documentation

This guide documents the Ralph progress monitoring and launcher scripts.

## Overview

Ralph includes monitoring scripts that track progress across multiple plans and send notifications to configured platforms (Slack, Discord, Telegram).

| Script | Purpose | Usage |
|:-------|:--------|:------|
| `start-monitor.sh` | Launch monitoring daemon | `./start-monitor.sh [interval]` |
| `monitor-progress.sh` | Monitor and report progress | `./monitor-progress.sh [interval] [repo_dir]` |

## start-monitor.sh

### Description

Starts the Ralph progress monitor in the background using `nohup`. This allows the monitor to run continuously, even after you log out.

### Usage

```bash
~/ralph/start-monitor.sh [interval_seconds]
```

### Parameters

| Parameter | Description | Default |
|:----------|:------------|:--------|
| `interval_seconds` | How often to check progress | 300 (5 minutes) |

### Examples

```bash
# Start with default 5-minute interval
~/ralph/start-monitor.sh

# Check progress every 2 minutes
~/ralph/start-monitor.sh 120

# Check progress every 30 seconds (for active development)
~/ralph/start-monitor.sh 30
```

### What It Does

1. Validates parameters and sets defaults
2. Changes to the script directory
3. Launches `monitor-progress.sh` via `nohup`
4. Redirects output to `monitor.log`
5. Saves the process ID to `monitor.pid`
6. Returns control to your terminal

### Output

```
Starting Ralph Progress Monitor...
Interval: 300s

✅ Monitor started with PID: 12345
Log file: /home/ubuntu/ralph/monitor.log

To view logs: tail -f /home/ubuntu/ralph/monitor.log
To stop: kill 12345

PID saved to: /home/ubuntu/ralph/monitor.pid
```

### Managing the Monitor

**View logs:**
```bash
tail -f ~/ralph/monitor.log
```

**Stop the monitor:**
```bash
# Using the saved PID
kill $(cat ~/ralph/monitor.pid)

# Or find and kill the process
pkill -f monitor-progress.sh
```

**Check if running:**
```bash
ps aux | grep monitor-progress.sh
```

**Restart the monitor:**
```bash
# Stop it first
kill $(cat ~/ralph/monitor.pid)

# Start with new settings
~/ralph/start-monitor.sh 60
```

## monitor-progress.sh

### Description

The core monitoring daemon that tracks Ralph progress files, calculates completion percentages, and sends notifications to Slack/Discord/Telegram.

### Usage

```bash
~/ralph/monitor-progress.sh [interval_seconds] [repo_directory]
```

### Parameters

| Parameter | Description | Default |
|:----------|:------------|:--------|
| `interval_seconds` | Polling interval | 300 (5 minutes) |
| `repo_directory` | Directory to scan for progress files | `/home/ubuntu/repos/RecursiveManager` |

### Examples

```bash
# Monitor with defaults
~/ralph/monitor-progress.sh

# Monitor current directory every minute
~/ralph/monitor-progress.sh 60 "$(pwd)"

# Monitor specific repo every 10 minutes
~/ralph/monitor-progress.sh 600 /home/ubuntu/my-project
```

### How It Works

#### 1. Initialization

- Loads `~/.ralph.env` for notification configuration
- Validates Slack webhook is configured
- Sets up color codes for terminal output
- Initializes progress tracking state

#### 2. Progress File Parsing

Scans for files matching `*_PROGRESS.md` pattern:

```markdown
## Status
IN_PROGRESS

## Task List
- [x] Task 1: Completed
- [ ] Task 2: In progress
- [ ] Task 3: Todo
```

Calculates:
- Total tasks (both `[ ]` and `[x]`)
- Completed tasks (`[x]`)
- Completion percentage
- Last update time

#### 3. Change Detection

Tracks previous state to avoid notification spam:
- Only notifies on 5% or greater progress change
- Always notifies on status changes
- First iteration sends baseline status

#### 4. Notification Dispatch

Sends formatted updates to Slack:

```
📊 Ralph Progress Update - 2026-01-23 14:30:00

🚧 my-feature: 3/10 tasks (30%) - IN_PROGRESS - Last: 2m ago
✅ auth-system: 8/8 tasks (100%) - DONE - Last: 1h ago
```

### Status Emojis

| Status | Emoji | Meaning |
|:-------|:------|:--------|
| `COMPLETED`, `DONE` | ✅ | All tasks complete |
| `IN_PROGRESS` | 🚧 | Actively being worked on |
| `FAILED`, `ERROR` | ❌ | Encountered errors |
| `STALLED` | ⚠️ | No progress recently |
| Other | 🔄 | Unknown/custom status |

### Configuration

The monitor requires Slack webhook configuration in `~/.ralph.env`:

```bash
export RALPH_SLACK_WEBHOOK_URL="https://hooks.slack.com/services/T00/B00/xxxx"
```

See [Notifications Guide](notifications.md) for setup instructions.

### Error Handling

**Slack Notification Failures:**

The monitor includes robust error handling:

- Tracks consecutive failures
- Logs detailed error information
- Continues monitoring even if notifications fail
- Shows warnings after 3 consecutive failures

**Common errors:**

| Error | Cause | Solution |
|:------|:------|:---------|
| `RALPH_SLACK_WEBHOOK_URL not set` | Missing configuration | Run `ralph notify setup` |
| `DNS resolution failed` | Network issue | Check internet connection |
| `HTTP 404` | Invalid webhook URL | Recreate webhook in Slack |
| `request timeout` | Slack API slow/down | Wait and monitor will retry |

### Performance

**Resource Usage:**
- CPU: Negligible (sleeps between checks)
- Memory: ~5-10 MB
- Disk I/O: Minimal (only reads progress files)

**Recommended Intervals:**

| Scenario | Interval | Reason |
|:---------|:---------|:-------|
| Active development | 30-60s | Quick feedback |
| Normal monitoring | 300s (5m) | Balanced |
| Overnight runs | 600-900s (10-15m) | Reduce noise |
| Long-term tracking | 1800s (30m) | Minimal overhead |

### Log Files

The monitor generates detailed logs in `monitor.log`:

```
Ralph Progress Monitor Started
Interval: 300s
Repo: /home/ubuntu/repos/RecursiveManager
Slack: Enabled

[2026-01-23 14:30:00] Iteration 1
  my-feature: 3/10 (30%) - IN_PROGRESS - 2m ago
  ✓ Posted to Slack

[2026-01-23 14:35:00] Iteration 2
  my-feature: 5/10 (50%) - IN_PROGRESS - 1m ago
  ✓ Posted to Slack

[2026-01-23 14:40:00] Iteration 3
  No significant changes
```

**Log rotation** (recommended):

```bash
# Add to crontab for daily rotation
0 0 * * * mv ~/ralph/monitor.log ~/ralph/monitor.log.$(date +\%Y\%m\%d) && touch ~/ralph/monitor.log
```

### Advanced Usage

#### Multiple Repository Monitoring

Create a wrapper script to monitor multiple repos:

```bash
#!/bin/bash
# multi-monitor.sh

~/ralph/monitor-progress.sh 300 /home/user/project1 &
~/ralph/monitor-progress.sh 300 /home/user/project2 &
~/ralph/monitor-progress.sh 300 /home/user/project3 &

echo "Monitoring 3 repositories"
```

#### Custom Notifications

The monitor uses Ralph's notification system, so all configured platforms receive updates:

```bash
# Configure multiple platforms
export RALPH_SLACK_WEBHOOK_URL="https://..."
export RALPH_DISCORD_WEBHOOK_URL="https://..."
export RALPH_TELEGRAM_BOT_TOKEN="..."
export RALPH_TELEGRAM_CHAT_ID="..."
```

#### Integration with CI/CD

```bash
# In your CI pipeline
- name: Start Progress Monitor
  run: |
    ~/ralph/start-monitor.sh 60 &
    echo $! > /tmp/monitor.pid

- name: Run Ralph
  run: ralph ./plan.md build 50

- name: Stop Monitor
  run: kill $(cat /tmp/monitor.pid) || true
```

### Troubleshooting

**Monitor not sending notifications:**

1. Check Slack webhook is configured:
   ```bash
   echo $RALPH_SLACK_WEBHOOK_URL
   ```

2. Verify the webhook works:
   ```bash
   ralph notify test
   ```

3. Check the monitor logs:
   ```bash
   tail -f ~/ralph/monitor.log
   ```

**No progress files found:**

1. Verify you're monitoring the correct directory:
   ```bash
   ls /path/to/repo/*_PROGRESS.md
   ```

2. Check the repo path parameter:
   ```bash
   ~/ralph/monitor-progress.sh 300 "$(pwd)"
   ```

**Monitor stopped unexpectedly:**

1. Check system logs:
   ```bash
   journalctl -xe | grep monitor
   ```

2. Verify disk space:
   ```bash
   df -h
   ```

3. Check for out-of-memory:
   ```bash
   dmesg | grep -i kill
   ```

### Security Considerations

**Webhook URLs:**
- Store in `~/.ralph.env` with `chmod 600` permissions
- Never commit webhook URLs to git
- Rotate webhooks if exposed

**Log Files:**
- May contain sensitive information
- Rotate regularly to prevent disk filling
- Set appropriate permissions: `chmod 640 monitor.log`

**Process Management:**
- Monitor runs with user privileges
- Store PID file securely
- Use systemd for production deployments (see [DEPLOYMENT.md](DEPLOYMENT.md))

## Production Deployment

For production use, consider using systemd instead of nohup:

### Create systemd service

```ini
# /etc/systemd/system/ralph-monitor.service
[Unit]
Description=Ralph Progress Monitor
After=network.target

[Service]
Type=simple
User=ubuntu
WorkingDirectory=/home/ubuntu/ralph
ExecStart=/home/ubuntu/ralph/monitor-progress.sh 300 /home/ubuntu/repos/RecursiveManager
Restart=on-failure
RestartSec=30
StandardOutput=append:/home/ubuntu/ralph/monitor.log
StandardError=append:/home/ubuntu/ralph/monitor.log

[Install]
WantedBy=multi-user.target
```

### Enable and start:

```bash
sudo systemctl daemon-reload
sudo systemctl enable ralph-monitor
sudo systemctl start ralph-monitor

# Check status
sudo systemctl status ralph-monitor

# View logs
sudo journalctl -u ralph-monitor -f
```

## See Also

- [Notifications Guide](notifications.md) - Configure Slack, Discord, Telegram
- [Usage Guide](usage.md) - Ralph command reference
- [Troubleshooting](TROUBLESHOOTING.md) - Common issues and solutions
