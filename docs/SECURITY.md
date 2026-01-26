# Security Best Practices

This guide covers security considerations when using PortableRalph.

## Overview

Ralph is an autonomous AI agent that:
- Reads and writes code in your repository
- Executes commands via Claude CLI
- Sends notifications with repository information
- Stores API credentials and webhook URLs

**Security is your responsibility.** Follow these best practices to minimize risks.

---

## Critical Security Principles

### 1. Never Trust AI-Generated Code Blindly

**Risk:** AI can introduce vulnerabilities, backdoors, or insecure patterns.

**Mitigation:**

```bash
# Always review commits
git log --oneline -10
git show HEAD

# Run security scans
npm audit          # Node.js
pip-audit          # Python
cargo audit        # Rust

# Use code review
# Create PR instead of direct commit
ralph ./plan.md build 10  # Limited iterations
# Review changes, then merge
```

### 2. Protect API Credentials

**Risk:** Exposed credentials allow unauthorized API access and potential data breaches.

**Mitigation:**

```bash
# Secure config file
chmod 600 ~/.ralph.env
ls -la ~/.ralph.env  # Should show: -rw-------

# Never commit credentials
echo ".ralph.env" >> .gitignore
echo "~/.ralph.env" >> ~/.gitignore

# Use environment-specific configs
# Production: Use secrets manager (AWS Secrets Manager, HashiCorp Vault)
# Development: Use ~/.ralph.env locally
```

### 3. Limit Ralph's Scope

**Risk:** Unrestricted execution can cause widespread damage.

**Mitigation:**

```bash
# Use max iterations
ralph ./plan.md build 10  # Stop after 10 tasks

# Disable auto-commit for review
ralph config commit off
# Or per-plan:
# Add "DO_NOT_COMMIT" to plan file

# Run in branches
git checkout -b ralph-feature
ralph ./plan.md build
# Review before merging to main

# Use plan mode first
ralph ./plan.md plan  # Review task list
# If looks good:
ralph ./plan.md build
```

### 4. Protect Webhook URLs

**Risk:** Webhook URLs are bearer tokens - anyone with the URL can send messages.

**Mitigation:**

```bash
# Secure storage
chmod 600 ~/.ralph.env

# Rotate regularly
# Recreate webhooks every 90 days

# Use IP allowlisting (if platform supports)
# Slack: Workspace settings → Permissions → IP ranges

# Monitor for abuse
# Check Slack/Discord for unexpected messages
```

---

## Configuration Security

### Environment Variables

**Good Practices:**

```bash
# Store in secure file
cat > ~/.ralph.env << 'EOF'
export RALPH_SLACK_WEBHOOK_URL="https://hooks.slack.com/services/xxx"
export RALPH_DISCORD_WEBHOOK_URL="https://discord.com/api/webhooks/xxx"
export RALPH_TELEGRAM_BOT_TOKEN="xxx"
export RALPH_TELEGRAM_CHAT_ID="xxx"
EOF

# Set restrictive permissions
chmod 600 ~/.ralph.env

# Verify
ls -la ~/.ralph.env
# Should show: -rw------- (600)
```

**Bad Practices (DON'T DO THIS):**

```bash
# Don't hardcode in scripts
SLACK_URL="https://hooks.slack.com/..."  # BAD

# Don't commit to git
git add .ralph.env  # BAD

# Don't use world-readable permissions
chmod 644 ~/.ralph.env  # BAD

# Don't share via insecure channels
email .ralph.env  # BAD
slack .ralph.env  # BAD
```

### Secrets Management in CI/CD

**GitHub Actions:**

```yaml
# Store as repository secrets
env:
  CLAUDE_API_KEY: ${{ secrets.CLAUDE_API_KEY }}
  RALPH_SLACK_WEBHOOK_URL: ${{ secrets.RALPH_SLACK_WEBHOOK }}

# Never log secrets
- run: echo "Webhook: $RALPH_SLACK_WEBHOOK_URL"  # BAD
```

**GitLab CI:**

```yaml
# Use masked variables
variables:
  CLAUDE_API_KEY:
    value: "xxx"
    masked: true
    protected: true
```

**Jenkins:**

```groovy
// Use credentials plugin
environment {
    CLAUDE_API_KEY = credentials('claude-api-key')
}
```

---

## Code Execution Security

### Validate AI Output

**Risk:** AI-generated code may contain vulnerabilities.

**Mitigation:**

```bash
# Run linters
eslint .                    # JavaScript/TypeScript
pylint **/*.py              # Python
clippy                      # Rust

# Run security scanners
npm audit                   # Node.js dependencies
safety check                # Python dependencies
cargo audit                 # Rust dependencies

# Static analysis
semgrep --config auto .     # Multi-language
bandit -r .                 # Python security
brakeman                    # Ruby on Rails

# Run tests before accepting
npm test
pytest
cargo test
```

### Sandbox Execution

**For Untrusted Execution:**

```bash
# Use Docker container
docker run --rm -v $(pwd):/workspace \
    -e RALPH_SLACK_WEBHOOK_URL="$RALPH_SLACK_WEBHOOK_URL" \
    ralph-image ./plan.md build 10

# Or use VM
# Or use separate git worktree
git worktree add ../ralph-sandbox
cd ../ralph-sandbox
ralph ./plan.md build
# Review before merging
```

### Restrict File Access

**Use .gitignore to protect sensitive files:**

```gitignore
# Don't let Ralph read/write these
*.env
*.pem
*.key
*secret*
*credential*
.aws/
.ssh/
```

**Verify Ralph doesn't access:**

```bash
# Check commits
git log --stat | grep -E "\.(env|key|pem)"

# If found, remove from history
git filter-branch --index-filter 'git rm --cached --ignore-unmatch .env'
```

---

## Network Security

### Webhook Security

**Slack:**

1. **Regenerate webhooks periodically:**
   - Delete old webhook
   - Create new webhook
   - Update `~/.ralph.env`

2. **Limit webhook permissions:**
   - Only grant posting permissions
   - Don't use admin tokens

3. **Monitor for abuse:**
   - Check channel for unexpected messages
   - Review Slack audit logs

**Discord:**

1. **Use rate limiting:**
   - Discord auto-rate-limits webhooks
   - Don't bypass limits

2. **Regenerate tokens:**
   - Delete webhook → Create new
   - Update config

3. **Restrict channel permissions:**
   - Webhook can only post to specific channel
   - Can't read messages or access other channels

**Telegram:**

1. **Bot token security:**
   ```bash
   # Revoke compromised token
   # Message @BotFather: /revoke

   # Create new bot
   # Update RALPH_TELEGRAM_BOT_TOKEN
   ```

2. **Chat ID privacy:**
   - Don't share chat IDs publicly
   - Use group IDs instead of personal IDs in shared configs

### Proxy/Firewall

**Behind corporate firewall:**

```bash
# Configure proxy
export http_proxy="http://proxy.company.com:8080"
export https_proxy="http://proxy.company.com:8080"

# Or use authenticated proxy
export http_proxy="http://user:pass@proxy:8080"
```

**Allowlist outbound connections:**

- `api.anthropic.com` (Claude API)
- `hooks.slack.com` (Slack webhooks)
- `discord.com` (Discord webhooks)
- `api.telegram.org` (Telegram API)
- `api.github.com` (Ralph updates)

---

## Access Control

### File Permissions

**Ralph installation:**

```bash
# Scripts executable by owner only
chmod 700 ~/ralph/*.sh

# Config readable by owner only
chmod 600 ~/.ralph.env

# Verify
ls -la ~/ralph/
# Scripts: -rwx------
# Config:  -rw-------
```

**Repository:**

```bash
# Don't run Ralph as root
whoami  # Should NOT be root

# Use dedicated user (optional)
useradd -m ralphuser
su - ralphuser
# Install Ralph as ralphuser
```

### Git Security

**Commit Signing:**

```bash
# Generate GPG key
gpg --gen-key

# Configure git
git config --global user.signingkey YOUR_KEY_ID
git config --global commit.gpgsign true

# Ralph commits will be signed
# Verify:
git log --show-signature
```

**Protected Branches:**

```yaml
# .github/workflows protection
# Require reviews for Ralph PRs
on:
  pull_request:
    branches: [main]

# Don't allow direct push to main
# Force Ralph to create PR
```

---

## Monitoring and Auditing

### Track Ralph Activity

**Git audit:**

```bash
# See all Ralph commits
git log --author="Ralph" --oneline

# See what files Ralph modified
git log --author="Ralph" --name-only

# See code changes
git log --author="Ralph" -p
```

**Notification audit:**

```bash
# Monitor notification logs
tail -f ~/ralph/monitor.log

# Check for suspicious activity
grep -i "error\|fail\|unauthorized" ~/ralph/monitor.log
```

### Alert on Suspicious Behavior

**File modifications:**

```bash
# Watch for changes to sensitive files
git diff HEAD --name-only | grep -E "\.(env|key|pem)"
if [ $? -eq 0 ]; then
    echo "ALERT: Sensitive file modified!"
    exit 1
fi
```

**Unexpected API calls:**

```bash
# Monitor outbound connections
tcpdump -i any host api.anthropic.com

# Alert on unexpected destinations
tcpdump -i any not \( host api.anthropic.com or host hooks.slack.com \)
```

---

## Incident Response

### If Credentials Are Compromised

1. **Immediately revoke:**
   ```bash
   # Slack: Delete webhook
   # Discord: Delete webhook
   # Telegram: /revoke with @BotFather
   # Claude: Revoke API key in dashboard
   ```

2. **Rotate all credentials:**
   ```bash
   # Create new webhooks
   # Update ~/.ralph.env
   # Reload config
   source ~/.ralph.env
   ```

3. **Review logs:**
   ```bash
   # Check Slack messages
   # Review git commits
   git log --since="2024-01-01" --author="Ralph"

   # Check for data exfiltration
   grep -r "password\|secret\|key" .
   ```

4. **Assess impact:**
   - What repositories were accessed?
   - What data was exposed?
   - What code was committed?

### If Malicious Code Is Committed

1. **Stop Ralph immediately:**
   ```bash
   # Find process
   ps aux | grep ralph

   # Kill it
   kill <PID>
   ```

2. **Revert commits:**
   ```bash
   # Identify bad commits
   git log --oneline -20

   # Revert range
   git revert HEAD~5..HEAD

   # Or hard reset (if not pushed)
   git reset --hard HEAD~5
   ```

3. **Scan for backdoors:**
   ```bash
   # Search for suspicious patterns
   grep -r "eval\|exec\|system" .
   grep -r "password\|secret" .

   # Run security scanner
   semgrep --config auto .
   ```

4. **Notify stakeholders:**
   - Security team
   - Repository owners
   - Affected users

---

## Secure Deployment Patterns

### Development Environment

```bash
# Use separate Claude API key
# Don't use production key in dev

# Disable notifications in dev
unset RALPH_SLACK_WEBHOOK_URL

# Use short iteration limits
ralph ./plan.md build 5

# Review all changes
git diff
```

### Staging Environment

```bash
# Use staging webhooks
export RALPH_SLACK_WEBHOOK_URL="https://hooks.slack.com/staging/..."

# Auto-commit enabled
# But require PR review before merge

# Moderate iteration limits
ralph ./plan.md build 20
```

### Production Environment

```bash
# Use production webhooks
# Load from secrets manager

# Disable auto-commit
ralph config commit off

# Always create PR
# Require 2+ reviews

# Strict iteration limits
ralph ./plan.md build 10
```

---

## Compliance Considerations

### GDPR / Data Privacy

**Risk:** Ralph may process personal data in code/comments.

**Mitigation:**

- Don't include personal data in plan files
- Review commits for PII before pushing
- Use pseudonymization in test data
- Maintain audit logs (git history)

### SOC 2 / Security Certifications

**Requirements:**

- **Access Control:** Limit who can run Ralph
- **Audit Logging:** Enable git commit signing
- **Encryption:** Use HTTPS for all webhooks
- **Incident Response:** Document Ralph in IR plan
- **Change Management:** Require reviews for Ralph commits

### Industry-Specific

**Healthcare (HIPAA):**
- Don't process PHI with Ralph
- Use PHI-sanitized test datasets
- Audit all code changes

**Finance (PCI-DSS):**
- Don't process payment card data
- Separate environments (dev/prod)
- Regular security reviews

---

## Security Checklist

Use this checklist before deploying Ralph:

- [ ] `~/.ralph.env` has `600` permissions
- [ ] Webhook URLs not committed to git
- [ ] `.gitignore` excludes sensitive files
- [ ] Auto-commit disabled or PR-based workflow
- [ ] Max iterations set (`ralph build 20`)
- [ ] Plan mode used first (`ralph plan`)
- [ ] Git commit signing enabled
- [ ] Regular credential rotation (90 days)
- [ ] Monitoring enabled (notifications, logs)
- [ ] Incident response plan documented
- [ ] Security scanning in CI/CD
- [ ] Code review required for merges
- [ ] Separate dev/staging/prod configs
- [ ] Claude API key is production-ready
- [ ] Team trained on Ralph security

---

## Reporting Security Issues

Found a security vulnerability in Ralph?

**Do NOT create a public GitHub issue.**

Instead:

1. Email security contact (check README)
2. Include:
   - Description of vulnerability
   - Steps to reproduce
   - Potential impact
   - Suggested fix (if any)
3. Wait for response before disclosure
4. Allow 90 days for fix before public disclosure

---

## Additional Resources

### Security Tools

- **Secrets Scanning:** [git-secrets](https://github.com/awslabs/git-secrets)
- **SAST:** [Semgrep](https://semgrep.dev/)
- **Dependency Scanning:** `npm audit`, `pip-audit`, `cargo audit`
- **Git Auditing:** [GitLeaks](https://github.com/gitleaks/gitleaks)

### Security Standards

- **OWASP Top 10:** [owasp.org/top10](https://owasp.org/www-project-top-ten/)
- **CWE Top 25:** [cwe.mitre.org/top25](https://cwe.mitre.org/top25/)
- **NIST Cybersecurity:** [nist.gov/cyberframework](https://www.nist.gov/cyberframework)

### Training

- **Secure Coding:** OWASP Secure Coding Practices
- **AI Security:** AI Red Team training
- **Git Security:** GitHub Advanced Security

---

## Security Fixes and Hardening

Ralph has been hardened against several security vulnerabilities identified in security audits. This section documents the implemented fixes.

### Sed Injection Prevention

**Vulnerability:** Unsanitized input to `sed` commands could allow arbitrary command execution.

**Fix:** All user-controlled input passed to `sed` is now properly escaped using `sed 's/[\/&]/\\&/g'` before use in sed expressions.

**Impact:** Prevents command injection through malicious plan files or configuration values.

**Test Coverage:** `tests/test-security.sh` includes sed injection tests.

### Custom Script Validation

**Vulnerability:** Custom notification scripts could be executed from untrusted paths without validation.

**Fix:** Custom scripts are now validated before execution:
- Path must exist and be readable
- Script must have execute permissions
- Execution is subject to timeout (30 seconds default)
- Script receives sanitized input only
- Exit codes are checked and logged

**Configuration:** Set `RALPH_CUSTOM_NOTIFY_SCRIPT` to an absolute path only.

**Example:**
```bash
# Safe
export RALPH_CUSTOM_NOTIFY_SCRIPT="/home/user/scripts/notify.sh"

# Unsafe - will be rejected
export RALPH_CUSTOM_NOTIFY_SCRIPT="../../malicious.sh"
```

**Test Coverage:** `tests/test-security.sh` includes custom script validation tests.

### Enhanced Path Traversal Protection

**Vulnerability:** Insufficient validation of file paths could allow access outside intended directories.

**Fix:** The new `lib/validation.sh` library provides `validate_path()` function:
- Canonicalize paths using `realpath`
- Block paths containing `..`, `~`, or absolute paths when relative paths are expected
- Validate files exist and are readable/writable as needed
- Prevent symlink attacks through canonicalization

**Usage:**
```bash
source "${RALPH_DIR}/lib/validation.sh"

# Validate file exists and is readable
if ! validate_path "/path/to/file" "config file" "read"; then
    echo "Invalid path"
    exit 1
fi
```

**Test Coverage:** `tests/test-security.sh` includes path traversal tests.

### Improved Encryption Key Derivation

**Vulnerability:** Weak or predictable encryption keys could compromise credential storage.

**Fix:** Enhanced key derivation for encrypted configuration:
- Uses system-specific entropy sources
- Combines multiple factors (hostname, user, salt)
- Implements proper key stretching
- Validates key strength before use

**Action Required:** If you have encrypted credentials, you must re-encrypt them:
```bash
# Backup existing credentials
cp ~/.ralph.env ~/.ralph.env.backup

# Re-run setup to re-encrypt with stronger keys
ralph notify setup

# Verify new credentials work
ralph notify test

# If successful, remove backup
rm ~/.ralph.env.backup
```

### Config File Validation

**Vulnerability:** Malformed or malicious configuration files could cause unexpected behavior.

**Fix:** All configuration files are validated on load:
- Syntax validation (no bash syntax errors)
- Format validation (proper export statements)
- Value validation (URLs, tokens, numeric values)
- Permission checking (must be 600 or stricter)
- Owner validation (must be owned by current user)

**Validation Functions:**
```bash
source "${RALPH_DIR}/lib/validation.sh"

# Validate URL with SSRF protection
validate_url "$WEBHOOK_URL" "webhook URL"

# Validate email address
validate_email "$EMAIL" "notification email"

# Validate numeric with range
validate_numeric "$TIMEOUT" "timeout" 1 3600
```

**Implementation:** The validation library (`lib/validation.sh`) provides:
- `validate_url()` - SSRF-protected URL validation
- `validate_email()` - RFC-compliant email validation
- `validate_numeric()` - Range-checked numeric validation
- `validate_path()` - Secure path validation
- `json_escape()` - Safe JSON string escaping
- `mask_token()` - Sensitive data masking for logs

**Test Coverage:**
- `tests/test-security.sh` - Security vulnerability tests
- `lib/test-compat.sh` - Validation library unit tests

### SSRF Protection

**Vulnerability:** Server-Side Request Forgery through webhook URLs pointing to internal resources.

**Fix:** URL validation now includes SSRF protection:
- Block localhost URLs (127.0.0.1, ::1, localhost)
- Block private IP ranges (10.0.0.0/8, 172.16.0.0/12, 192.168.0.0/16)
- Block link-local addresses (169.254.0.0/16)
- Block metadata service URLs (169.254.169.254)
- Require HTTPS for production webhooks

**Example:**
```bash
# These URLs will be rejected
export RALPH_SLACK_WEBHOOK_URL="http://localhost/attack"
export RALPH_SLACK_WEBHOOK_URL="http://192.168.1.1/internal"
export RALPH_SLACK_WEBHOOK_URL="http://169.254.169.254/metadata"

# These URLs will be accepted
export RALPH_SLACK_WEBHOOK_URL="https://hooks.slack.com/services/..."
export RALPH_DISCORD_WEBHOOK_URL="https://discord.com/api/webhooks/..."
```

### Security Testing

Ralph now includes comprehensive security tests in `tests/test-security.sh`:

```bash
# Run security tests
cd ~/ralph
./tests/test-security.sh

# Tests include:
# - Command injection prevention
# - Path traversal attacks
# - SSRF protection
# - Input validation
# - Token masking
# - Custom script validation
```

### Security Constants

Security-related constants are centralized in `lib/constants.sh`:

```bash
HTTP_MAX_TIME=10                    # HTTP request timeout
HTTP_CONNECT_TIMEOUT=5              # Connection timeout
CUSTOM_SCRIPT_TIMEOUT=30            # Custom script execution timeout
CONFIG_FILE_MODE=600                # Required config file permissions
RATE_LIMIT_MAX=60                   # Max notifications per minute
TOKEN_MASK_PREFIX_LENGTH=8          # Characters to show in masked tokens
```

These can be customized by overriding in your `~/.ralph.env`:

```bash
# Stricter timeouts for security-conscious environments
export HTTP_MAX_TIME=5
export CUSTOM_SCRIPT_TIMEOUT=15
```

### Security Audit Compliance

The following security issues have been addressed:

| Severity | Issue | Status | Fix Location |
|:---------|:------|:-------|:------------|
| CRITICAL | Command injection via sed | Fixed | `lib/validation.sh`, all scripts |
| CRITICAL | Unsafe custom script execution | Fixed | `notify.sh`, `lib/validation.sh` |
| HIGH | Path traversal vulnerabilities | Fixed | `lib/validation.sh` |
| HIGH | SSRF via webhook URLs | Fixed | `lib/validation.sh` |
| HIGH | Weak encryption key derivation | Fixed | `setup-notifications.sh` |
| MEDIUM | Missing input validation | Fixed | `lib/validation.sh` |
| MEDIUM | Config file permission issues | Fixed | All scripts |

---

## See Also

- [Usage Guide](usage.md) - Safe Ralph usage
- [CI/CD Examples](CI_CD_EXAMPLES.md) - Secure CI/CD patterns
- [Troubleshooting](TROUBLESHOOTING.md) - Security-related issues
- [Notifications](notifications.md) - Webhook security
- [Testing Guide](TESTING.md) - Security testing
