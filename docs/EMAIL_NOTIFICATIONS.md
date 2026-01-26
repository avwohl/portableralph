# Email Notifications for Ralph

Ralph supports email notifications through three delivery methods:

1. **SMTP** - Traditional mail servers (Gmail, Outlook, etc.)
2. **SendGrid API** - Cloud email service
3. **AWS SES** - Amazon Simple Email Service

## Features

- **HTML & Plain Text Emails** - Beautiful HTML templates with plain text fallback
- **Smart Batching** - Reduces email spam by grouping non-critical notifications
- **Multiple Delivery Methods** - Automatic fallback between configured methods
- **Template-based** - Customizable email templates
- **Event Filtering** - Critical messages (errors, warnings) are sent immediately

## Quick Start

### 1. Interactive Setup (Recommended)

```bash
cd ~/ralph
./setup-notifications.sh
```

Choose option 4 for Email, then follow the prompts.

### 2. Manual Configuration

Edit `~/.ralph.env` and add your email settings:

```bash
# Basic settings (required)
export RALPH_EMAIL_TO="your-email@example.com"
export RALPH_EMAIL_FROM="ralph@example.com"

# Choose ONE delivery method below
```

## Delivery Methods

### Option 1: SMTP (Gmail, Outlook, etc.)

Best for: Using existing email accounts

```bash
export RALPH_SMTP_HOST="smtp.gmail.com"
export RALPH_SMTP_PORT="587"
export RALPH_SMTP_USER="your-email@gmail.com"
export RALPH_SMTP_PASSWORD="your-app-password"
export RALPH_SMTP_TLS="true"
```

#### Gmail Setup

1. Enable 2-factor authentication on your Google account
2. Go to [Google App Passwords](https://myaccount.google.com/apppasswords)
3. Create a new app password for "Mail"
4. Use the generated password in `RALPH_SMTP_PASSWORD`

#### Outlook/Office 365 Setup

```bash
export RALPH_SMTP_HOST="smtp-mail.outlook.com"
export RALPH_SMTP_PORT="587"
export RALPH_SMTP_USER="your-email@outlook.com"
export RALPH_SMTP_PASSWORD="your-password"
export RALPH_SMTP_TLS="true"
```

#### Yahoo Mail Setup

```bash
export RALPH_SMTP_HOST="smtp.mail.yahoo.com"
export RALPH_SMTP_PORT="587"
export RALPH_SMTP_USER="your-email@yahoo.com"
export RALPH_SMTP_PASSWORD="your-app-password"
export RALPH_SMTP_TLS="true"
```

### Option 2: SendGrid API

Best for: High-volume emails, better deliverability

**Setup:**

1. Sign up at [SendGrid](https://sendgrid.com)
2. Go to Settings > API Keys
3. Create a new API key with "Mail Send" permission
4. Copy the key (starts with `SG.`)

**Configuration:**

```bash
export RALPH_SENDGRID_API_KEY="SG.your-api-key-here"
```

**Advantages:**
- No SMTP configuration needed
- Better deliverability rates
- Free tier: 100 emails/day
- Detailed analytics dashboard

### Option 3: AWS SES

Best for: AWS-integrated infrastructure, cost-effective at scale

**Prerequisites:**

```bash
# Install AWS CLI
sudo apt-get install awscli

# Verify your sender email in AWS SES
# 1. Go to AWS SES Console
# 2. Verify email address or domain
# 3. Request production access (to send to any email)
```

**Setup IAM User:**

1. Create IAM user with `AmazonSESFullAccess` policy
2. Generate access keys

**Configuration:**

```bash
export RALPH_AWS_SES_REGION="us-east-1"
export RALPH_AWS_ACCESS_KEY_ID="AKIAIOSFODNN7EXAMPLE"
export RALPH_AWS_SECRET_KEY="wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
```

**Advantages:**
- Very low cost ($0.10 per 1,000 emails)
- High deliverability
- Integrates with AWS infrastructure
- Detailed metrics in CloudWatch

## Email Options

### Subject Line Customization

```bash
export RALPH_EMAIL_SUBJECT="MyApp Alerts"
```

The subject will be: "MyApp Alerts - Success" or "MyApp Alerts - Error", etc.

### HTML vs Plain Text

```bash
# Send HTML emails (default: true)
export RALPH_EMAIL_HTML="true"

# Plain text only
export RALPH_EMAIL_HTML="false"
```

### Batching Configuration

Batching groups non-critical notifications to reduce email noise:

```bash
# Wait 5 minutes before sending batched emails
export RALPH_EMAIL_BATCH_DELAY="300"

# Maximum 10 notifications per batch
export RALPH_EMAIL_BATCH_MAX="10"

# Disable batching (send all immediately)
export RALPH_EMAIL_BATCH_DELAY="0"
```

**How it works:**
- Critical messages (errors, warnings) are sent immediately
- Info/progress messages are queued
- Batch is sent when delay expires OR max count is reached

### Multiple Recipients

```bash
# Comma-separated list
export RALPH_EMAIL_TO="admin@example.com,devops@example.com,alerts@example.com"
```

## Testing

After configuration, test your email setup:

```bash
cd ~/ralph
./notify.sh --test
```

You should see:

```
Testing Ralph notifications...

Configured platforms:
  - Email: configured (to: your-email@example.com, method: SendGrid API)

Sending test message...
  Email: sent

Test complete! Check your notification channels.
```

## Email Templates

Ralph includes professional HTML and plain text templates.

### Template Location

```
~/ralph/templates/
├── email-notification.html  # HTML template
└── email-notification.txt   # Plain text template
```

### Customizing Templates

You can edit the templates to match your branding:

```bash
nano ~/ralph/templates/email-notification.html
```

**Template Variables:**

- `{{MESSAGE}}` - The notification message
- `{{TYPE}}` - Notification type (info, success, warning, error, progress)
- `{{TYPE_LABEL}}` - Human-readable type label
- `{{TIMESTAMP}}` - When the notification was sent
- `{{HOSTNAME}}` - Server hostname
- `{{PROJECT}}` - Project name (if set via RALPH_PROJECT_NAME)
- `{{BATCH_COUNT}}` - Number of batched messages (if applicable)

## Advanced Configuration

### Project Name

Add context to your emails:

```bash
export RALPH_PROJECT_NAME="Production API Server"
```

This will appear in the email metadata.

### Custom Notification Frequency

Control how often Ralph sends notifications:

```bash
# Send every 5th notification (default)
export RALPH_NOTIFY_FREQUENCY=5

# Send every notification
export RALPH_NOTIFY_FREQUENCY=1
```

### Security Best Practices

1. **Use App Passwords** - Never use your main password for SMTP
2. **Encrypt Credentials** - The setup wizard encrypts sensitive values
3. **Restrict File Permissions** - Ralph sets `chmod 600` on config files
4. **Use TLS** - Always enable `RALPH_SMTP_TLS="true"`
5. **IAM Least Privilege** - For AWS SES, use minimal required permissions

## Troubleshooting

### Email Not Sending

1. **Check configuration:**
   ```bash
   source ~/.ralph.env
   echo $RALPH_EMAIL_TO
   echo $RALPH_EMAIL_FROM
   ```

2. **Test with verbose output:**
   ```bash
   bash -x ~/ralph/notify.sh --test
   ```

3. **Check logs:**
   ```bash
   # If running as a service
   journalctl -u ralph -n 50
   ```

### SMTP Authentication Errors

**Gmail:**
- Enable 2FA and use App Password
- Allow "Less secure apps" is deprecated - must use App Password

**Outlook:**
- Check if account has 2FA enabled
- May need app-specific password

**Corporate Email:**
- Check SMTP server and port with IT
- May need VPN connection
- May require OAuth instead of password

### SendGrid Issues

**"Unauthorized" Error:**
- Verify API key has "Mail Send" permission
- Check key wasn't accidentally truncated

**"Bad Request" Error:**
- Verify sender email is verified in SendGrid
- Check recipient email format

### AWS SES Issues

**"Email address not verified" Error:**
- Verify sender email in SES Console
- If in sandbox, verify recipient too
- Request production access to send to any email

**"Access Denied" Error:**
- Check IAM user has SES permissions
- Verify access keys are correct
- Check region matches SES configuration

**AWS CLI Not Found:**
```bash
sudo apt-get update
sudo apt-get install awscli
```

### Rate Limiting

Ralph has built-in rate limiting (60 notifications/minute) to prevent spam. If exceeded:

```
Rate limit exceeded (max 60 notifications per minute)
```

Adjust your notification frequency or batching settings.

## Integration Examples

### With Cron Jobs

```bash
#!/bin/bash
# my-backup.sh

source ~/.ralph.env

if backup-command; then
    ~/ralph/notify.sh "Backup completed successfully"
else
    ~/ralph/notify.sh "Backup FAILED - check logs"
fi
```

### With Monitoring Scripts

```bash
#!/bin/bash
# monitor-disk.sh

source ~/.ralph.env

USAGE=$(df -h / | tail -1 | awk '{print $5}' | sed 's/%//')

if [ $USAGE -gt 90 ]; then
    ~/ralph/notify.sh "WARNING: Disk usage at ${USAGE}%"
fi
```

### With CI/CD Pipelines

```yaml
# .github/workflows/deploy.yml
- name: Notify on Success
  if: success()
  run: |
    source ~/.ralph.env
    ~/ralph/notify.sh "Deployment to production completed successfully"

- name: Notify on Failure
  if: failure()
  run: |
    source ~/.ralph.env
    ~/ralph/notify.sh "ERROR: Deployment to production failed"
```

## Email HTML Template Preview

The default HTML template includes:

- **Gradient Header** - Purple/blue gradient with Ralph branding
- **Type Badge** - Color-coded badge (info/success/warning/error)
- **Message Box** - Formatted message with syntax highlighting
- **Metadata Section** - Timestamp, hostname, project info
- **Batched Messages** - If applicable, shows all queued notifications
- **Footer** - Links and credits
- **Mobile Responsive** - Looks great on all devices

## Cost Comparison

| Method | Cost | Free Tier | Best For |
|--------|------|-----------|----------|
| SMTP (Gmail) | Free | Yes | Personal projects, low volume |
| SMTP (Corporate) | Included | N/A | Company infrastructure |
| SendGrid | $0 - $15/mo | 100/day | Startups, medium volume |
| AWS SES | $0.10/1K | 62K/month (if on EC2) | High volume, AWS users |

## Next Steps

- [Main Documentation](../README.md)
- [Notification Setup](notifications.md)
- [Usage Guide](usage.md)
- [Writing Plans](writing-plans.md)

## Support

For issues or questions:

1. Check [Troubleshooting](#troubleshooting) section above
2. Review email provider documentation
3. Open an issue on GitHub
4. Check existing discussions

---

**Note:** Email delivery can take a few seconds to several minutes depending on your mail server and recipient's server. If using batching, emails are delayed by design (default 5 minutes).
