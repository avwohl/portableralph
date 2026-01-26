# Windows Installation Guide

This guide walks you through installing and using PortableRalph on Windows.

## Prerequisites

### Required Software

1. **Windows 10/11** (64-bit)
2. **Git for Windows** - [Download](https://git-scm.com/download/win)
3. **Claude Code CLI** - [Installation Guide](https://docs.anthropic.com/en/docs/claude-code)

### Optional But Recommended

- **Windows Terminal** - [Microsoft Store](https://aka.ms/terminal)
- **Visual Studio Code** - [Download](https://code.visualstudio.com/)
- **WSL2** (Windows Subsystem for Linux) - For best compatibility

---

## Installation Methods

### Method 1: WSL2 (Recommended)

WSL2 provides the best compatibility with Ralph's bash scripts.

#### Step 1: Install WSL2

Open PowerShell as Administrator:

```powershell
# Enable WSL
wsl --install

# Restart computer when prompted
```

After restart:

```powershell
# Install Ubuntu
wsl --install -d Ubuntu

# Launch Ubuntu
wsl
```

#### Step 2: Install Ralph in WSL

Inside the WSL Ubuntu terminal:

```bash
# Update package list
sudo apt update
sudo apt install -y curl git

# Install Claude CLI
curl -fsSL https://claude.ai/download/cli/install.sh | bash

# Install Ralph
curl -fsSL https://raw.githubusercontent.com/aaron777collins/portableralph/master/install.sh | bash

# Configure shell
echo 'alias ralph="$HOME/ralph/ralph.sh"' >> ~/.bashrc
source ~/.bashrc

# Verify installation
ralph --version
```

#### Step 3: Access Windows Files

WSL can access Windows files:

```bash
# Windows C: drive is at /mnt/c/
cd /mnt/c/Users/YourUsername/Projects

# Run Ralph on Windows files
ralph ./plan.md
```

Access WSL files from Windows:
- Open File Explorer
- Type `\\wsl$\Ubuntu\home\yourusername` in address bar

### Method 2: Git Bash (Native Windows)

Git Bash provides a Unix-like environment on Windows.

#### Step 1: Install Git for Windows

1. Download from [git-scm.com](https://git-scm.com/download/win)
2. Run installer
3. **Important:** Select "Use Git and optional Unix tools from the Command Prompt"
4. Complete installation

#### Step 2: Install Ralph

Open **Git Bash**:

```bash
# Install Claude CLI (follow official docs for Windows)
# Then install Ralph

cd ~
git clone https://github.com/aaron777collins/portableralph.git ralph
chmod +x ~/ralph/*.sh

# Add to PATH
echo 'export PATH="$HOME/ralph:$PATH"' >> ~/.bashrc
echo 'alias ralph="~/ralph/ralph.sh"' >> ~/.bashrc
source ~/.bashrc

# Verify
ralph --version
```

#### Step 3: Handle Line Endings

Windows uses CRLF, Unix uses LF. Configure git:

```bash
# Configure git to handle line endings
cd ~/ralph
git config core.autocrlf input

# Convert existing files
find ~/ralph -name "*.sh" -exec dos2unix {} \;
```

If `dos2unix` isn't available:

```bash
# Install via Git Bash package manager
pacman -S dos2unix

# Or manually fix line endings
sed -i 's/\r$//' ~/ralph/*.sh
```

### Method 3: PowerShell (Enhanced Support)

Ralph now includes enhanced PowerShell support with cross-platform compatibility utilities.

#### Step 1: Enable Linux-like Commands

```powershell
# Install Scoop (package manager)
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
irm get.scoop.sh | iex

# Install Unix tools
scoop install git curl grep sed
```

#### Step 2: Install Ralph

```powershell
# Clone repository
cd $HOME
git clone https://github.com/aaron777collins/portableralph.git ralph

# Create PowerShell wrapper
New-Item -Path "$HOME\ralph\ralph.ps1" -ItemType File -Force
```

Add to `ralph.ps1`:

```powershell
#!/usr/bin/env pwsh
# Ralph PowerShell wrapper

$RalphDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$BashScript = Join-Path $RalphDir "ralph.sh"

# Run with Git Bash
& "C:\Program Files\Git\bin\bash.exe" $BashScript $args
```

#### Step 3: Add to PATH

```powershell
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

#### Step 4: PowerShell Compatibility Utilities

Ralph includes `lib/compat-utils.ps1` with cross-platform functions:

```powershell
# Import compatibility utilities
. "$HOME\ralph\lib\compat-utils.ps1"

# Available functions:
Get-UnixPath              # Convert Windows path to Unix path
Get-WindowsPath           # Convert Unix path to Windows path
Test-CommandExists        # Check if command is available
Invoke-SafeCommand        # Execute command with error handling
Get-RalphConfig           # Read Ralph configuration
Set-RalphConfig           # Update Ralph configuration
Test-RalphDependencies    # Verify all dependencies installed
```

**Example Usage:**

```powershell
# Convert paths for WSL
$unixPath = Get-UnixPath "C:\Users\name\project"
# Returns: /mnt/c/Users/name/project

# Check dependencies
if (Test-RalphDependencies) {
    Write-Host "All dependencies installed"
}

# Safe command execution
Invoke-SafeCommand "git status" -WorkingDirectory $ProjectPath
```

---

## Configuration

### Environment Variables

Ralph uses `~/.ralph.env` for configuration. On Windows:

- **WSL:** `~/.ralph.env` = `/home/username/.ralph.env`
- **Git Bash:** `~/.ralph.env` = `C:\Users\Username\.ralph.env`
- **PowerShell:** `~/.ralph.env` = `C:\Users\Username\.ralph.env`

### Creating Configuration

```bash
# Run setup wizard
ralph notify setup

# Or create manually
cat > ~/.ralph.env << 'EOF'
# Ralph Configuration
export RALPH_SLACK_WEBHOOK_URL="https://hooks.slack.com/services/..."
export RALPH_DISCORD_WEBHOOK_URL="https://discord.com/api/webhooks/..."
export RALPH_AUTO_COMMIT="true"
EOF

chmod 600 ~/.ralph.env
```

### Loading Configuration

**WSL/Git Bash:**
```bash
echo 'source ~/.ralph.env' >> ~/.bashrc
source ~/.bashrc
```

**PowerShell (Enhanced):**
```powershell
# Import compatibility utilities
. "$HOME\ralph\lib\compat-utils.ps1"

# Load Ralph configuration
$config = Get-RalphConfig

# Access configuration values
Write-Host "Slack webhook: $($config.RALPH_SLACK_WEBHOOK_URL)"

# Or convert to environment variables:
Get-Content $HOME\.ralph.env | ForEach-Object {
    if ($_ -match '^export\s+([^=]+)="([^"]*)"') {
        [Environment]::SetEnvironmentVariable($matches[1], $matches[2], "User")
    }
}

# Using the new config command (PowerShell support)
ralph config commit on    # Enable auto-commit
ralph config commit off   # Disable auto-commit
ralph config commit status # Check status
```

### Cross-Platform Path Handling

Ralph's PowerShell utilities handle path conversions automatically:

```powershell
# Import utilities
. "$HOME\ralph\lib\compat-utils.ps1"

# Windows to Unix path (for WSL)
$unixPath = Get-UnixPath "C:\Users\name\project\plan.md"
# Result: /mnt/c/Users/name/project/plan.md

# Unix to Windows path
$winPath = Get-WindowsPath "/mnt/c/Users/name/project"
# Result: C:\Users\name\project

# Normalize path for current platform
$normalized = Normalize-RalphPath "C:\Users\name\project"
# On Windows: C:\Users\name\project
# On WSL: /mnt/c/Users/name/project
```

### PowerShell Config Command

The `config` command now works in PowerShell:

```powershell
# Check auto-commit status
ralph config commit status

# Enable auto-commit
ralph config commit on

# Disable auto-commit
ralph config commit off

# View all configuration
ralph config show
```

---

## New PowerShell Features

### Platform Detection

```powershell
# Import utilities
. "$HOME\ralph\lib\compat-utils.ps1"

# Detect platform
$platform = Get-RalphPlatform
# Returns: "Windows", "WSL", "Linux", "macOS"

# Check if running in WSL
if (Test-IsWSL) {
    Write-Host "Running in WSL environment"
}
```

### Process Management

```powershell
# Check if Ralph is running
$isRunning = Test-RalphProcess
if ($isRunning) {
    Write-Host "Ralph is currently running"
}

# Start Ralph in background
Start-RalphBackground -PlanFile "plan.md" -MaxIterations 20

# Stop Ralph process
Stop-RalphProcess -Graceful
```

### Dependency Checking

```powershell
# Verify all dependencies
if (Test-RalphDependencies -Verbose) {
    Write-Host "All dependencies satisfied"
} else {
    Write-Host "Missing dependencies - run setup"
}

# Check specific dependency
if (Test-CommandExists "git") {
    Write-Host "Git is installed"
}
```

### Configuration Management

```powershell
# Get configuration value
$webhookUrl = Get-RalphConfigValue "RALPH_SLACK_WEBHOOK_URL"

# Set configuration value
Set-RalphConfigValue "RALPH_AUTO_COMMIT" "true"

# Validate configuration
if (Test-RalphConfig) {
    Write-Host "Configuration is valid"
}
```

---

## Common Windows-Specific Issues

### Issue 1: Line Ending Errors

**Symptoms:**
```
bash: '\r': command not found
```

**Cause:** Windows CRLF line endings in bash scripts.

**Solution:**

```bash
# Convert all scripts to Unix line endings
cd ~/ralph
find . -name "*.sh" -exec sed -i 's/\r$//' {} \;

# Or use dos2unix
find . -name "*.sh" -exec dos2unix {} \;

# Prevent future issues
git config --global core.autocrlf input
```

### Issue 2: Permission Denied

**Symptoms:**
```
Permission denied: ~/ralph/ralph.sh
```

**Solution:**

```bash
# Make scripts executable
chmod +x ~/ralph/*.sh

# Verify permissions
ls -la ~/ralph/*.sh
```

### Issue 3: Path Issues

**Symptoms:**
```
Error: Plan file not found: C:\Users\...\plan.md
```

**Cause:** Mixing Windows and Unix paths.

**Solution:**

```bash
# Use Unix-style paths in WSL/Git Bash
ralph ./plan.md              # Good
ralph /c/Users/me/plan.md   # Good (Git Bash)
ralph C:\Users\me\plan.md   # Bad - don't use Windows paths

# In WSL, convert paths:
cd /mnt/c/Users/YourName/Projects
ralph ./plan.md
```

### Issue 4: Claude CLI Not Found

**Symptoms:**
```
claude: command not found
```

**Solution:**

```bash
# Verify Claude is installed
which claude

# If not found, check PATH
echo $PATH

# Add Claude to PATH (adjust path as needed)
export PATH="$HOME/.local/bin:$PATH"
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
```

### Issue 5: Antivirus Blocking

**Symptoms:**
Scripts hang or fail with access denied.

**Cause:** Windows Defender or antivirus blocking bash scripts.

**Solution:**

1. Add exclusion for `~/ralph` directory:
   - Open Windows Security
   - Virus & threat protection
   - Manage settings
   - Add exclusion → Folder
   - Select `C:\Users\YourName\ralph` or WSL path

2. Or temporarily disable real-time protection (not recommended)

### Issue 6: Unicode/Encoding Issues

**Symptoms:**
```
Invalid character in file
```

**Solution:**

```bash
# Set UTF-8 encoding
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

# Add to ~/.bashrc
echo 'export LANG=en_US.UTF-8' >> ~/.bashrc
echo 'export LC_ALL=en_US.UTF-8' >> ~/.bashrc
```

**PowerShell:**
```powershell
# Set UTF-8 encoding for PowerShell
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::InputEncoding = [System.Text.Encoding]::UTF8

# Add to PowerShell profile
Add-Content $PROFILE @"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::InputEncoding = [System.Text.Encoding]::UTF8
"@
```

### Issue 7: PowerShell Execution Policy

**Symptoms:**
```
cannot be loaded because running scripts is disabled on this system
```

**Solution:**

```powershell
# Check current policy
Get-ExecutionPolicy

# Set policy for current user
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser

# Verify
Get-ExecutionPolicy -List
```

### Issue 8: Git Bash vs PowerShell Path Differences

**Symptoms:**
Paths work in Git Bash but not PowerShell or vice versa.

**Solution:**

```powershell
# Use the compatibility utilities
. "$HOME\ralph\lib\compat-utils.ps1"

# Normalize paths for current environment
$normalizedPath = Normalize-RalphPath $yourPath

# Or convert explicitly
$unixPath = Get-UnixPath "C:\Users\name\project"
$winPath = Get-WindowsPath "/mnt/c/Users/name/project"
```

---

## Windows Terminal Setup

For the best experience, use Windows Terminal.

### Install Windows Terminal

```powershell
# Install from Microsoft Store
# Or via winget:
winget install Microsoft.WindowsTerminal
```

### Configure for WSL

1. Open Windows Terminal
2. Click ▼ (dropdown) → Settings
3. Add new profile:

```json
{
    "guid": "{YOUR-GUID}",
    "name": "Ralph (WSL)",
    "commandline": "wsl.exe ~",
    "hidden": false,
    "startingDirectory": "\\\\wsl$\\Ubuntu\\home\\yourusername",
    "colorScheme": "One Half Dark"
}
```

### Configure for Git Bash

```json
{
    "guid": "{YOUR-GUID}",
    "name": "Ralph (Git Bash)",
    "commandline": "C:\\Program Files\\Git\\bin\\bash.exe -i -l",
    "icon": "C:\\Program Files\\Git\\mingw64\\share\\git\\git-for-windows.ico",
    "startingDirectory": "%USERPROFILE%"
}
```

---

## VS Code Integration

### Install VS Code Extensions

1. **WSL Extension** - Work with WSL projects
2. **GitLens** - Git integration
3. **Remote - SSH** - Remote development

### Open WSL Projects

```bash
# In WSL terminal
cd /mnt/c/Users/YourName/Projects/myproject
code .
```

VS Code will:
- Open in Windows
- Access files via WSL
- Run terminals in WSL
- Use WSL for git operations

### Configure Terminal

Add to `.vscode/settings.json`:

```json
{
    "terminal.integrated.defaultProfile.windows": "Git Bash",
    "terminal.integrated.profiles.windows": {
        "Git Bash": {
            "path": "C:\\Program Files\\Git\\bin\\bash.exe",
            "args": ["-i", "-l"]
        }
    }
}
```

---

## Performance Optimization

### WSL2 Performance

1. **Store files in WSL filesystem:**
   ```bash
   # Fast
   cd ~/projects
   ralph ./plan.md

   # Slow (crosses filesystem boundary)
   cd /mnt/c/Users/me/projects
   ralph ./plan.md
   ```

2. **Increase WSL memory:**

   Create `C:\Users\YourName\.wslconfig`:
   ```ini
   [wsl2]
   memory=8GB
   processors=4
   ```

3. **Disable Windows Defender for WSL:**
   ```powershell
   Add-MpPreference -ExclusionProcess wsl.exe
   ```

### Git Bash Performance

1. **Disable antivirus for Git directory:**
   - Add `C:\Program Files\Git` to exclusions

2. **Use SSD for repositories:**
   - Store projects on SSD, not HDD

---

## Troubleshooting Windows Issues

### Enable Bash Debugging

```bash
# Add to top of ralph.sh temporarily
set -x  # Print commands
set -v  # Print input lines

# Run Ralph
ralph ./plan.md plan 2>&1 | tee debug.log
```

### Check File Permissions

```bash
# List permissions
ls -la ~/ralph

# Fix if needed
chmod -R u+rwx ~/ralph
```

### Verify Dependencies

```bash
# Check all required tools
command -v git && echo "Git: OK" || echo "Git: MISSING"
command -v claude && echo "Claude: OK" || echo "Claude: MISSING"
command -v curl && echo "curl: OK" || echo "curl: MISSING"
command -v jq && echo "jq: OK" || echo "jq: MISSING (optional)"
```

### Network Issues

```bash
# Test connectivity
curl -I https://api.github.com

# If behind proxy
export http_proxy="http://proxy.company.com:8080"
export https_proxy="http://proxy.company.com:8080"
```

---

## Migration from Linux/Mac

### Transferring Configuration

From Linux/Mac:
```bash
# Copy config
scp ~/.ralph.env windows-machine:/mnt/c/Users/YourName/
```

On Windows (WSL):
```bash
cp /mnt/c/Users/YourName/.ralph.env ~/.ralph.env
chmod 600 ~/.ralph.env
```

### Path Translation

| Linux/Mac | Windows (WSL) | Windows (Git Bash) |
|:----------|:--------------|:-------------------|
| `/home/user/project` | `/home/user/project` | `/c/Users/user/project` |
| `~/ralph` | `~/ralph` | `~/ralph` |
| `/tmp` | `/tmp` | `/tmp` (temporary) |

---

## Docker Alternative

If native installation is problematic, use Docker:

### Install Docker Desktop

1. Download from [docker.com](https://www.docker.com/products/docker-desktop/)
2. Enable WSL2 backend
3. Start Docker Desktop

### Create Dockerfile

```dockerfile
FROM ubuntu:22.04

RUN apt-get update && apt-get install -y \
    curl \
    git \
    ca-certificates

# Install Claude CLI
RUN curl -fsSL https://claude.ai/download/cli/install.sh | bash

# Install Ralph
RUN curl -fsSL https://raw.githubusercontent.com/aaron777collins/portableralph/master/install.sh | bash -s -- --headless

# Set up environment
ENV PATH="/root/ralph:${PATH}"

WORKDIR /workspace

ENTRYPOINT ["/root/ralph/ralph.sh"]
```

### Build and Use

```powershell
# Build image
docker build -t ralph .

# Run Ralph
docker run -v ${PWD}:/workspace ralph plan.md

# With environment variables
docker run -v ${PWD}:/workspace `
    -e RALPH_SLACK_WEBHOOK_URL="https://..." `
    ralph plan.md build 20
```

---

## Best Practices for Windows

1. **Use WSL2 when possible** - Best compatibility
2. **Store repos in WSL filesystem** - Better performance
3. **Use Windows Terminal** - Better experience
4. **Keep Git Bash updated** - Latest features
5. **Configure line endings** - Prevent issues
6. **Use environment variables** - Not hardcoded paths
7. **Regular updates** - Keep Ralph updated
8. **Use PowerShell compatibility utilities** - For cross-platform scripts
9. **Normalize paths** - Use `Get-UnixPath`/`Get-WindowsPath` helpers
10. **Test in both environments** - Verify Git Bash and PowerShell compatibility

---

## Getting Help

### Windows-Specific Resources

- **WSL Documentation:** [docs.microsoft.com/wsl](https://docs.microsoft.com/windows/wsl/)
- **Git for Windows:** [gitforwindows.org](https://gitforwindows.org/)
- **Windows Terminal:** [github.com/microsoft/terminal](https://github.com/microsoft/terminal)

### Community Support

- **GitHub Issues:** Tag with `windows` label
- **Discord:** #windows channel (if available)

### Reporting Windows Issues

Include in issue reports:
```powershell
# System info
systeminfo | findstr /B /C:"OS Name" /C:"OS Version"

# WSL version (if applicable)
wsl --version

# Git Bash version
bash --version

# Ralph version
ralph --version
```

---

## See Also

- [Installation Guide](installation.md) - General installation
- [Usage Guide](usage.md) - Command reference
- [Troubleshooting](TROUBLESHOOTING.md) - Common issues
- [CI/CD Examples](CI_CD_EXAMPLES.md) - Windows CI/CD
