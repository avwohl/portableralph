#!/bin/bash
# setup-notifications.sh - Interactive setup wizard for Ralph notifications
# Supports: Slack, Discord, and Telegram
#
# Usage:
#   ~/ralph/setup-notifications.sh
#
# This wizard will:
# 1. Ask which platforms you want to configure
# 2. Guide you through getting the credentials for each
# 3. Save configuration to ~/.ralph.env
# 4. Test the notifications

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color
BOLD='\033[1m'

RALPH_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_FILE="$HOME/.ralph.env"

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}  Ralph Notifications Setup Wizard${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "This wizard will help you configure notifications for Ralph."
echo "Your settings will be saved to: ${CYAN}$CONFIG_FILE${NC}"
echo ""

# Load existing config if present
if [ -f "$CONFIG_FILE" ]; then
    echo -e "${YELLOW}Existing configuration found.${NC}"
    read -p "Do you want to reconfigure? (y/N): " RECONFIGURE
    if [[ ! "$RECONFIGURE" =~ ^[Yy]$ ]]; then
        echo "Keeping existing configuration."
        echo ""
        echo "To test notifications, run:"
        echo -e "  ${CYAN}~/ralph/ralph.sh --test-notify${NC}"
        exit 0
    fi
    echo ""
fi

# Initialize config
SLACK_URL=""
DISCORD_URL=""
TELEGRAM_TOKEN=""
TELEGRAM_CHAT=""

# ============================================
# PLATFORM SELECTION
# ============================================
echo -e "${BOLD}Which platforms do you want to configure?${NC}"
echo ""
echo "  1) Slack"
echo "  2) Discord"
echo "  3) Telegram"
echo "  4) All of the above"
echo "  5) Cancel"
echo ""
read -p "Enter your choice (1-5): " PLATFORM_CHOICE

case "$PLATFORM_CHOICE" in
    1) SETUP_SLACK=true; SETUP_DISCORD=false; SETUP_TELEGRAM=false ;;
    2) SETUP_SLACK=false; SETUP_DISCORD=true; SETUP_TELEGRAM=false ;;
    3) SETUP_SLACK=false; SETUP_DISCORD=false; SETUP_TELEGRAM=true ;;
    4) SETUP_SLACK=true; SETUP_DISCORD=true; SETUP_TELEGRAM=true ;;
    5) echo "Setup cancelled."; exit 0 ;;
    *) echo -e "${RED}Invalid choice. Exiting.${NC}"; exit 1 ;;
esac

# ============================================
# SLACK SETUP
# ============================================
if [ "$SETUP_SLACK" = true ]; then
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}Slack Setup${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo "To get a Slack webhook URL:"
    echo ""
    echo "  1. Go to: ${CYAN}https://api.slack.com/apps${NC}"
    echo "  2. Click 'Create New App' > 'From scratch'"
    echo "  3. Name it 'Ralph' and select your workspace"
    echo "  4. Go to 'Incoming Webhooks' in the sidebar"
    echo "  5. Toggle 'Activate Incoming Webhooks' ON"
    echo "  6. Click 'Add New Webhook to Workspace'"
    echo "  7. Select the channel and click 'Allow'"
    echo "  8. Copy the webhook URL"
    echo ""
    read -p "Paste your Slack webhook URL (or press Enter to skip): " SLACK_URL

    if [ -n "$SLACK_URL" ]; then
        echo -e "${GREEN}Slack webhook configured.${NC}"
    else
        echo -e "${YELLOW}Slack skipped.${NC}"
    fi
fi

# ============================================
# DISCORD SETUP
# ============================================
if [ "$SETUP_DISCORD" = true ]; then
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}Discord Setup${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo "To get a Discord webhook URL:"
    echo ""
    echo "  1. Open your Discord server"
    echo "  2. Right-click the channel > 'Edit Channel'"
    echo "  3. Go to 'Integrations' > 'Webhooks'"
    echo "  4. Click 'New Webhook'"
    echo "  5. Name it 'Ralph' and click 'Copy Webhook URL'"
    echo ""
    read -p "Paste your Discord webhook URL (or press Enter to skip): " DISCORD_URL

    if [ -n "$DISCORD_URL" ]; then
        echo -e "${GREEN}Discord webhook configured.${NC}"
    else
        echo -e "${YELLOW}Discord skipped.${NC}"
    fi
fi

# ============================================
# TELEGRAM SETUP
# ============================================
if [ "$SETUP_TELEGRAM" = true ]; then
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}Telegram Setup${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo "To set up Telegram notifications:"
    echo ""
    echo "  ${BOLD}Step 1: Create a bot${NC}"
    echo "  1. Open Telegram and search for @BotFather"
    echo "  2. Send /newbot and follow the prompts"
    echo "  3. Copy the bot token (looks like: 123456789:ABCdefGHI...)"
    echo ""
    read -p "Paste your bot token (or press Enter to skip): " TELEGRAM_TOKEN

    if [ -n "$TELEGRAM_TOKEN" ]; then
        echo ""
        echo "  ${BOLD}Step 2: Get your chat ID${NC}"
        echo "  1. Start a chat with your new bot (search for it and click Start)"
        echo "  2. Send any message to the bot"
        echo "  3. Visit this URL in your browser:"
        echo "     ${CYAN}https://api.telegram.org/bot${TELEGRAM_TOKEN}/getUpdates${NC}"
        echo "  4. Look for \"chat\":{\"id\":YOUR_CHAT_ID}"
        echo ""
        echo "  For group chats: Add the bot to the group, send a message,"
        echo "  then check getUpdates. Group IDs are negative numbers."
        echo ""
        read -p "Paste your chat ID: " TELEGRAM_CHAT

        if [ -n "$TELEGRAM_CHAT" ]; then
            echo -e "${GREEN}Telegram configured.${NC}"
        else
            echo -e "${YELLOW}Telegram skipped (no chat ID).${NC}"
            TELEGRAM_TOKEN=""
        fi
    else
        echo -e "${YELLOW}Telegram skipped.${NC}"
    fi
fi

# ============================================
# SAVE CONFIGURATION
# ============================================
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}Saving Configuration${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Check if anything was configured
if [ -z "$SLACK_URL" ] && [ -z "$DISCORD_URL" ] && [ -z "$TELEGRAM_TOKEN" ]; then
    echo -e "${YELLOW}No platforms were configured.${NC}"
    echo "Run this wizard again when you're ready."
    exit 0
fi

# Write config file
cat > "$CONFIG_FILE" << EOF
# Ralph Notification Configuration
# Generated by setup-notifications.sh on $(date)
# Source this file in your shell: source ~/.ralph.env

EOF

if [ -n "$SLACK_URL" ]; then
    echo "# Slack" >> "$CONFIG_FILE"
    echo "export RALPH_SLACK_WEBHOOK_URL=\"$SLACK_URL\"" >> "$CONFIG_FILE"
    echo "" >> "$CONFIG_FILE"
fi

if [ -n "$DISCORD_URL" ]; then
    echo "# Discord" >> "$CONFIG_FILE"
    echo "export RALPH_DISCORD_WEBHOOK_URL=\"$DISCORD_URL\"" >> "$CONFIG_FILE"
    echo "" >> "$CONFIG_FILE"
fi

if [ -n "$TELEGRAM_TOKEN" ]; then
    echo "# Telegram" >> "$CONFIG_FILE"
    echo "export RALPH_TELEGRAM_BOT_TOKEN=\"$TELEGRAM_TOKEN\"" >> "$CONFIG_FILE"
    echo "export RALPH_TELEGRAM_CHAT_ID=\"$TELEGRAM_CHAT\"" >> "$CONFIG_FILE"
    echo "" >> "$CONFIG_FILE"
fi

chmod 600 "$CONFIG_FILE"
echo -e "${GREEN}Configuration saved to: $CONFIG_FILE${NC}"

# ============================================
# SOURCE AND TEST
# ============================================
echo ""
echo -e "${BOLD}Loading configuration...${NC}"
source "$CONFIG_FILE"

echo ""
read -p "Do you want to send a test notification? (Y/n): " TEST_NOW
if [[ ! "$TEST_NOW" =~ ^[Nn]$ ]]; then
    echo ""
    "$RALPH_DIR/notify.sh" --test
fi

# ============================================
# FINAL INSTRUCTIONS
# ============================================
echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}Setup Complete!${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "To enable notifications in new terminal sessions, add this to your"
echo "shell profile (~/.bashrc or ~/.zshrc):"
echo ""
echo -e "  ${CYAN}source ~/.ralph.env${NC}"
echo ""
echo "Or run this command now:"
echo ""
echo -e "  ${CYAN}echo 'source ~/.ralph.env' >> ~/.bashrc${NC}"
echo ""
echo "Test notifications anytime with:"
echo ""
echo -e "  ${CYAN}~/ralph/ralph.sh --test-notify${NC}"
echo ""
