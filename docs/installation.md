# Installation

Get PortableRalph up and running in under a minute on any platform.

## Quick Install

### Linux / macOS

The fastest way to get started:

```bash
curl -fsSL https://raw.githubusercontent.com/aaron777collins/portableralph/master/install.sh | bash
```

This will:

1. Clone PortableRalph to `~/ralph`
2. Set up the `ralph` alias in your shell
3. Optionally configure notifications

### Windows

**Option 1: WSL2 (Recommended)**

```bash
# In WSL Ubuntu terminal
curl -fsSL https://raw.githubusercontent.com/aaron777collins/portableralph/master/install.sh | bash
```

**Option 2: PowerShell**

```powershell
# Download and run installer
Invoke-WebRequest -Uri https://raw.githubusercontent.com/aaron777collins/portableralph/master/install.ps1 -OutFile install.ps1
.\install.ps1
```

**Option 3: Git Bash**

```bash
# In Git Bash terminal
curl -fsSL https://raw.githubusercontent.com/aaron777collins/portableralph/master/install.sh | bash
```

See [Windows Setup Guide](WINDOWS_SETUP.md) for detailed Windows installation instructions.

## Manual Installation

### Linux / macOS / Windows (WSL/Git Bash)

```bash
# Clone the repository
git clone https://github.com/aaron777collins/portableralph.git ~/ralph

# Make scripts executable
chmod +x ~/ralph/*.sh

# Add alias to your shell
echo 'alias ralph="~/ralph/ralph.sh"' >> ~/.bashrc
source ~/.bashrc
```

### Windows (PowerShell)

```powershell
# Clone the repository
cd $HOME
git clone https://github.com/aaron777collins/portableralph.git ralph

# Add to PowerShell profile
$ProfilePath = $PROFILE.CurrentUserAllHosts
if (-not (Test-Path $ProfilePath)) {
    New-Item -Path $ProfilePath -ItemType File -Force
}

Add-Content $ProfilePath @"
# Ralph alias
function ralph { & `$HOME\ralph\ralph.ps1 @args }
"@

# Reload profile
. $PROFILE
```

## Headless Installation

For CI/CD or automated setups, use command-line flags:

```bash
# Install with Slack notifications
curl -fsSL https://raw.githubusercontent.com/aaron777collins/portableralph/master/install.sh | \
  bash -s -- --headless --slack-webhook "https://hooks.slack.com/services/xxx"

# Install with Discord
curl -fsSL https://raw.githubusercontent.com/aaron777collins/portableralph/master/install.sh | \
  bash -s -- --headless --discord-webhook "https://discord.com/api/webhooks/xxx"

# Install with custom script
curl -fsSL https://raw.githubusercontent.com/aaron777collins/portableralph/master/install.sh | \
  bash -s -- --headless --custom-script "/path/to/notify.sh"
```

### Headless Flags

| Flag | Description |
|:-----|:------------|
| `--headless` | Non-interactive mode |
| `--slack-webhook URL` | Configure Slack webhook |
| `--discord-webhook URL` | Configure Discord webhook |
| `--telegram-token TOKEN` | Configure Telegram bot token |
| `--telegram-chat ID` | Configure Telegram chat ID |
| `--custom-script PATH` | Configure custom notification script |

## Requirements

### All Platforms

| Requirement | Description |
|:------------|:------------|
| **Claude Code CLI** | [Install from Anthropic](https://platform.claude.com/docs/en/get-started) |
| **Git** | For auto-commits (optional) |
| **curl** | For notifications (optional) |

### Platform-Specific

**Linux / macOS:**
- Bash 4.0+ (usually pre-installed)
- Standard Unix tools (sed, awk, grep)

**Windows:**
- One of:
  - WSL2 with Ubuntu (recommended)
  - PowerShell 5.0+ (Windows 10/11 built-in)
  - Git Bash (from Git for Windows)
- Windows 10/11 (64-bit)

### Verify Claude CLI

**Linux / macOS / Windows (WSL/Git Bash):**
```bash
claude --version
```

**Windows (PowerShell):**
```powershell
claude --version
```

If this doesn't work, install Claude Code first from the [official documentation](https://docs.anthropic.com/en/docs/claude-code).

## Post-Installation

### Verify Installation

**Linux / macOS / Windows (WSL/Git Bash):**
```bash
ralph --version
```

**Windows (PowerShell):**
```powershell
ralph --version
```

You should see output like: `PortableRalph v1.6.0`

### Set Up Notifications (Optional)

**Linux / macOS / Windows (WSL/Git Bash):**
```bash
ralph notify setup
```

**Windows (PowerShell):**
```powershell
# PowerShell notification setup (if available)
# Otherwise use bash setup through Git Bash
```

### Test Notifications

**Linux / macOS / Windows (WSL/Git Bash):**
```bash
ralph notify test
```

**Windows (PowerShell):**
```powershell
# Test through bash or PowerShell implementation
```

### Run Test Suite

Verify everything works correctly:

**Linux / macOS / Windows (WSL/Git Bash):**
```bash
cd ~/ralph/tests
./run-all-tests.sh
```

**Windows (PowerShell):**
```powershell
cd $HOME\ralph\tests
.\run-all-tests.ps1
```

See [TESTING.md](../TESTING.md) for comprehensive testing documentation.

## Upgrading

Ralph has a built-in self-update system for easy upgrades:

```bash
# Update to the latest version
ralph update

# Check for updates without installing
ralph update --check

# List all available versions
ralph update --list

# Install a specific version
ralph update 1.5.0
```

### Rollback

If an update causes issues, you can rollback to the previous version:

```bash
ralph rollback
```

The previous version is automatically backed up before each update to `~/.ralph_backup/`.

### Version History

Your update history is tracked in `~/.ralph_version_history`.

## Uninstalling

### Linux / macOS / Windows (WSL/Git Bash)

```bash
# Remove the directory
rm -rf ~/ralph

# Remove the alias from your shell config
# Edit ~/.bashrc or ~/.zshrc and remove the ralph alias line

# Remove config file (optional)
rm ~/.ralph.env

# Remove backup directory (optional)
rm -rf ~/.ralph_backup
```

### Windows (PowerShell)

```powershell
# Remove the directory
Remove-Item -Path $HOME\ralph -Recurse -Force

# Remove the alias from PowerShell profile
# Edit PowerShell profile and remove ralph function

# Remove config file (optional)
Remove-Item -Path $HOME\.ralph.env -Force

# Remove backup directory (optional)
Remove-Item -Path $HOME\.ralph_backup -Recurse -Force
```

## Platform-Specific Notes

### Windows Users

Ralph supports three Windows environments:

1. **WSL2** (Recommended): Best compatibility, full bash support
2. **PowerShell**: Native Windows, some features may be limited
3. **Git Bash**: Good compatibility, Unix-like environment

See [Windows Setup Guide](WINDOWS_SETUP.md) for:
- Detailed installation steps for each environment
- Troubleshooting common Windows issues
- Performance optimization tips
- Path handling and line ending management

### macOS Users

macOS uses BSD command-line tools by default. For best compatibility:

```bash
# Install GNU tools (optional but recommended)
brew install coreutils gnu-sed gnu-grep bash
```

### Testing Your Installation

After installation, verify everything works:

```bash
# Linux/macOS/WSL/Git Bash
cd ~/ralph/tests
./run-all-tests.sh --unit-only

# Windows PowerShell
cd $HOME\ralph\tests
.\run-all-tests.ps1 -UnitOnly
```

See [TESTING.md](../TESTING.md) for comprehensive testing documentation.

## Next Steps

- **Configuration**: [Notifications Guide](notifications.md)
- **Email Setup**: [Email Notifications](EMAIL_NOTIFICATIONS.md)
- **Windows Guide**: [Windows Setup](WINDOWS_SETUP.md)
- **Usage**: [Command Reference](usage.md)
- **Writing Plans**: [Plan Writing Guide](writing-plans.md)
- **Testing**: [Testing Guide](../TESTING.md)
- **CI/CD**: [CI/CD Examples](CI_CD_EXAMPLES.md)
- **Security**: [Security Best Practices](SECURITY.md)
- **Troubleshooting**: [Common Issues](TROUBLESHOOTING.md)
