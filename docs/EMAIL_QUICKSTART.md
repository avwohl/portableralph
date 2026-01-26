# Email Notifications - Quick Start Guide

Get email notifications from Ralph in 5 minutes.

## Option 1: Interactive Setup (Easiest)

```bash
cd ~/ralph
./setup-notifications.sh
```

1. Choose option **4** (Email)
2. Enter recipient email
3. Enter sender email
4. Choose delivery method:
   - **1** for SMTP (Gmail, Outlook, etc.)
   - **2** for SendGrid
   - **3** for AWS SES
5. Enter credentials
6. Test: `./notify.sh --test`

## Option 2: Manual Setup

### Gmail SMTP (Recommended for personal use)

1. **Get App Password:**
   - Go to https://myaccount.google.com/apppasswords
   - Create password for "Mail"

2. **Configure:**
```bash
cat >> ~/.ralph.env << 'EOF'
export RALPH_EMAIL_TO="your-email@gmail.com"
export RALPH_EMAIL_FROM="your-email@gmail.com"
export RALPH_SMTP_HOST="smtp.gmail.com"
export RALPH_SMTP_PORT="587"
export RALPH_SMTP_USER="your-email@gmail.com"
export RALPH_SMTP_PASSWORD="your-app-password"
export RALPH_SMTP_TLS="true"
