# PortableRalph v1.7.0 Release Plan

**Created:** 2026-01-25
**Status:** IN_PROGRESS
**Goal:** Merge all unreleased changes, fix concurrency issues, add full cross-platform support, comprehensive testing in Docker

---

## Executive Summary

### What We Have
1. **Main repo** (`/home/ubuntu/repos/portableralph`) - Clean, at v1.6.0
2. **Working copy** (`/home/ubuntu/ralph`) - 70+ new files, 2,756 insertions, major features:
   - Full Windows PowerShell support
   - Security hardening (SSRF protection, input validation, token masking)
   - Email notification system (SMTP, SendGrid, AWS SES)
   - Comprehensive test suite (150+ test cases)
   - New documentation (10+ files)
3. **AICEO submodule** (`/home/ubuntu/repos/AICEO/ralph`) - 12 commits ahead, AICEO-specific integrations (DO NOT MERGE)

### GitHub Issue #1: Concurrency Issues
- **Problem:** API Error 400 due to tool use concurrency, race conditions on macOS
- **Root Cause:** No file locking, concurrent Claude CLI calls conflict
- **Solution:** Implement file locking, retry logic with exponential backoff, platform-aware process management

---

## Phase 1: Setup & Preparation

### 1.1 Create AICEO Branch (Separate AICEO-specific work)
- [ ] Create `aiceo-integration` branch in main repo
- [ ] Document that AICEO-specific changes stay in AICEO submodule
- [ ] Ensure clean separation

### 1.2 Prepare Working Environment
- [ ] Ensure main repo is clean
- [ ] Create feature branch `feature/v1.7.0-release`
- [ ] Set up progress tracking

---

## Phase 2: Merge Unreleased Changes (From /home/ubuntu/ralph)

### 2.1 Core Script Updates
- [ ] Merge `ralph.sh` changes (validation, retry logic, error handling)
- [ ] Merge `notify.sh` changes (email support, security hardening)
- [ ] Merge `install.sh` changes (headless mode, platform detection)
- [ ] Merge `setup-notifications.sh` changes (interactive wizard)
- [ ] Merge `update.sh` changes (self-update system)
- [ ] Merge `.env.example` changes (email config, new options)

### 2.2 New Library Files (lib/)
- [ ] Add `lib/constants.sh` - Centralized configuration
- [ ] Add `lib/validation.sh` - Input validation functions
- [ ] Add `lib/platform-utils.sh` - Cross-platform utilities
- [ ] Add `lib/process-mgmt.sh` - Process management

### 2.3 Windows Support (PowerShell)
- [ ] Add `ralph.ps1` - Main loop
- [ ] Add `notify.ps1` - Notifications
- [ ] Add `update.ps1` - Self-update
- [ ] Add `install.ps1` - Installer
- [ ] Add `uninstall.ps1` - Uninstaller
- [ ] Add `configure.ps1` - Configuration
- [ ] Add `launcher.ps1` - Auto-detection
- [ ] Add `lib/*.ps1` - Library files
- [ ] Add `launcher.bat` - Windows batch launcher
- [ ] Add `.gitattributes` - Line ending config

### 2.4 Email Templates
- [ ] Add `templates/email-notification.html`
- [ ] Add `templates/email-notification.txt`
- [ ] Add `templates/email_error.html`
- [ ] Add `templates/email_error.txt`
- [ ] Add `templates/email_iteration.html`
- [ ] Add `templates/email_iteration.txt`

### 2.5 Documentation
- [ ] Update `README.md` - Windows support, email notifications
- [ ] Update `docs/installation.md` - Multi-platform instructions
- [ ] Update `docs/notifications.md` - Email setup
- [ ] Update `docs/usage.md` - New commands
- [ ] Add `docs/SECURITY.md` - Security best practices
- [ ] Add `docs/WINDOWS_SETUP.md` - Windows guide
- [ ] Add `docs/EMAIL_NOTIFICATIONS.md` - Email config
- [ ] Add `docs/TROUBLESHOOTING.md` - Common issues
- [ ] Add `docs/TESTING.md` - Test documentation

### 2.6 Test Suite
- [ ] Add `tests/run-all-tests.sh` - Test runner
- [ ] Add `tests/test-ralph.sh` - Core tests
- [ ] Add `tests/test-notify.sh` - Notification tests
- [ ] Add `tests/test-security.sh` - Security tests (42 cases)
- [ ] Add `tests/test-validation-lib.sh` - Validation tests (35+ cases)
- [ ] Add `tests/test-constants-lib.sh` - Constants tests
- [ ] Add `tests/test-integration.sh` - Integration tests
- [ ] Add PowerShell test equivalents

### 2.7 CI/CD Workflows
- [ ] Add `.github/workflows/ci.yml` - Continuous integration
- [ ] Add `.github/workflows/test.yml` - Automated testing

---

## Phase 3: Fix Concurrency Issues (GitHub Issue #1)

### 3.1 File Locking Implementation
- [ ] Implement `flock` based locking for progress file
- [ ] Add lock timeout handling
- [ ] Platform-specific locking (macOS vs Linux)
- [ ] Windows-compatible locking via PowerShell

### 3.2 Retry Logic with Exponential Backoff
- [ ] Add `CLAUDE_MAX_RETRIES` config (default: 3)
- [ ] Add `CLAUDE_RETRY_DELAY` config (default: 2s)
- [ ] Implement exponential backoff (2s, 4s, 8s)
- [ ] Detect retryable errors (rate limit, network, API 400)
- [ ] Add jitter to prevent thundering herd

### 3.3 Process Management
- [ ] Single instance enforcement via PID file
- [ ] Graceful shutdown handling
- [ ] Orphan process cleanup
- [ ] Platform-aware process detection

### 3.4 Error Classification
- [ ] Auth errors (non-retryable)
- [ ] Rate limit errors (retryable with backoff)
- [ ] Network errors (retryable)
- [ ] API 400 errors (retryable with lock release)
- [ ] Not found errors (non-retryable)

---

## Phase 4: Docker Testing Environment

### 4.1 Create Docker Compose File
- [ ] Create `docker-compose.yml`
- [ ] Container name: `ralphcontainer`
- [ ] Mount repo as volume
- [ ] Configure OpenRouter with DeepSeek as default model
- [ ] Ensure API keys not in compose file (use env vars)

### 4.2 Dockerfile
- [ ] Base image: Ubuntu 22.04
- [ ] Install dependencies (bash, curl, jq, git)
- [ ] Install Claude Code CLI
- [ ] Copy test scripts
- [ ] Set up environment

### 4.3 Environment Security
- [ ] Use `.env` file (gitignored)
- [ ] Document required env vars
- [ ] No hardcoded API keys
- [ ] Add `.env.docker.example`

---

## Phase 5: Comprehensive Testing

### 5.1 Unit Tests (in Docker)
- [ ] Test validation functions
- [ ] Test platform detection
- [ ] Test config loading
- [ ] Test notification formatting
- [ ] Test email templating

### 5.2 Integration Tests (in Docker)
- [ ] Test plan mode execution
- [ ] Test build mode execution
- [ ] Test notification delivery (mocked)
- [ ] Test update system
- [ ] Test error recovery

### 5.3 Security Tests
- [ ] Test SSRF protection
- [ ] Test path traversal prevention
- [ ] Test command injection prevention
- [ ] Test token masking
- [ ] Test config file permissions

### 5.4 Platform Tests
- [ ] Test on Linux (Docker)
- [ ] Test on macOS (if available)
- [ ] Test Windows via Git Bash
- [ ] Test Windows PowerShell scripts

### 5.5 Concurrency Tests
- [ ] Test file locking under load
- [ ] Test retry logic
- [ ] Test multiple instance prevention
- [ ] Test graceful degradation

---

## Phase 6: Release

### 6.1 Pre-Release Checklist
- [ ] All tests passing
- [ ] No API keys in codebase
- [ ] Documentation updated
- [ ] CHANGELOG.md updated
- [ ] Version bumped to 1.7.0
- [ ] GitHub issue #1 addressed

### 6.2 Create Release
- [ ] Merge feature branch to master
- [ ] Tag v1.7.0
- [ ] Push tag to GitHub
- [ ] Verify GitHub Actions release workflow
- [ ] Verify release artifacts

### 6.3 Post-Release
- [ ] Close GitHub issue #1
- [ ] Post Slack notification
- [ ] Update documentation site
- [ ] Verify install script works

---

## Risk Assessment & Contingencies

### Risk 1: Merge Conflicts
- **Mitigation:** Cherry-pick changes carefully, test each merge
- **Contingency:** Manual conflict resolution, incremental merges

### Risk 2: Concurrency Fix Breaks Existing Functionality
- **Mitigation:** Comprehensive test suite, backwards compatibility
- **Contingency:** Feature flag to disable locking

### Risk 3: Platform-Specific Bugs
- **Mitigation:** Test on all platforms before release
- **Contingency:** Platform-specific patches, quick follow-up release

### Risk 4: Docker Environment Issues
- **Mitigation:** Document all requirements, use stable base image
- **Contingency:** Alternative testing approaches

### Risk 5: API Key Exposure
- **Mitigation:** Multiple security scans, .gitignore review
- **Contingency:** Immediate secret rotation if exposed

---

## Dependencies

```
Phase 1 (Setup) → Phase 2 (Merge) → Phase 3 (Concurrency Fix) → Phase 4 (Docker) → Phase 5 (Testing) → Phase 6 (Release)
```

- Phase 2 depends on Phase 1 completion
- Phase 3 can partially run in parallel with Phase 2
- Phase 4 can start after Phase 2 core merges
- Phase 5 requires Phase 4 Docker environment
- Phase 6 requires all previous phases

---

## Progress Tracking

| Phase | Status | Progress |
|-------|--------|----------|
| Phase 1: Setup | NOT_STARTED | 0% |
| Phase 2: Merge | NOT_STARTED | 0% |
| Phase 3: Concurrency | NOT_STARTED | 0% |
| Phase 4: Docker | NOT_STARTED | 0% |
| Phase 5: Testing | NOT_STARTED | 0% |
| Phase 6: Release | NOT_STARTED | 0% |

**Overall Progress:** 0%

---

## Commands Reference

```bash
# Send Slack update
/home/ubuntu/repos/AICEO/send-slack-message.sh "PortableRalph: [status message]"

# Run tests
cd /home/ubuntu/repos/portableralph && ./tests/run-all-tests.sh

# Docker testing
docker-compose up ralphcontainer
docker exec -it ralphcontainer ./tests/run-all-tests.sh

# Create release
git tag -a v1.7.0 -m "Release v1.7.0"
git push origin v1.7.0
```
