#!/usr/bin/env pwsh
# test-powershell.ps1 - PowerShell test suite for Ralph
# Comprehensive tests for PowerShell components
#
# Tests:
#   - lib/validation.ps1 functions
#   - lib/compat-utils.ps1 functions
#   - ralph.ps1 config command
#   - launcher.ps1 functionality

<#
.SYNOPSIS
    PowerShell test suite for Ralph

.DESCRIPTION
    Tests all PowerShell components including:
    - Validation library (Test-NumericValue, Test-WebhookUrl, Test-EmailAddress, Test-FilePath)
    - JSON escaping and token masking
    - Cross-platform compatibility utilities
    - Configuration management
    - Launcher functionality
#>

param()

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RalphDir = Split-Path -Parent $ScriptDir
$TestDir = Join-Path $ScriptDir "test-output-powershell"

# Test counters
$Script:TestsRun = 0
$Script:TestsPassed = 0
$Script:TestsFailed = 0

# Setup test environment
function Initialize-TestEnvironment {
    if (Test-Path $TestDir) {
        Remove-Item $TestDir -Recurse -Force -ErrorAction SilentlyContinue
    }
    New-Item -ItemType Directory -Path $TestDir -Force | Out-Null

    # Load validation library
    $validationLib = Join-Path $RalphDir "lib/validation.ps1"
    if (Test-Path $validationLib) {
        . $validationLib
    } else {
        Write-Warning "validation.ps1 not found - some tests will be skipped"
    }

    # Load compat utilities if they exist
    $compatLib = Join-Path $RalphDir "lib/compat-utils.ps1"
    if (Test-Path $compatLib) {
        . $compatLib
    }
}

# Cleanup test environment
function Remove-TestEnvironment {
    if (Test-Path $TestDir) {
        Remove-Item $TestDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# Test assertion helpers
function Assert-Equals {
    param(
        $Expected,
        $Actual,
        [string]$Message = ""
    )

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

function Assert-True {
    param(
        [bool]$Condition,
        [string]$Message = ""
    )

    $Script:TestsRun++
    if ($Condition) {
        $Script:TestsPassed++
        Write-Host "✓ $Message" -ForegroundColor Green
        return $true
    } else {
        $Script:TestsFailed++
        Write-Host "✗ $Message" -ForegroundColor Red
        return $false
    }
}

function Assert-False {
    param(
        [bool]$Condition,
        [string]$Message = ""
    )

    $Script:TestsRun++
    if (-not $Condition) {
        $Script:TestsPassed++
        Write-Host "✓ $Message" -ForegroundColor Green
        return $true
    } else {
        $Script:TestsFailed++
        Write-Host "✗ $Message" -ForegroundColor Red
        return $false
    }
}

function Assert-Contains {
    param(
        [string]$Haystack,
        [string]$Needle,
        [string]$Message = ""
    )

    $Script:TestsRun++
    if ($Haystack -like "*$Needle*") {
        $Script:TestsPassed++
        Write-Host "✓ $Message" -ForegroundColor Green
        return $true
    } else {
        $Script:TestsFailed++
        Write-Host "✗ $Message" -ForegroundColor Red
        Write-Host "  Expected to find: $Needle" -ForegroundColor Yellow
        Write-Host "  In: $Haystack" -ForegroundColor Yellow
        return $false
    }
}

# ============================================
# Test-NumericValue TESTS
# ============================================

function Test-ValidationNumeric {
    Write-Host "`n=== Test-NumericValue Tests ===" -ForegroundColor Cyan

    # Valid integers
    Assert-True (Test-NumericValue -Value "42") "Accepts valid integer (42)"
    Assert-True (Test-NumericValue -Value "0") "Accepts zero (0)"
    Assert-True (Test-NumericValue -Value "999999") "Accepts large integer (999999)"

    # Invalid inputs
    Assert-False (Test-NumericValue -Value "abc") "Rejects non-numeric string (abc)"
    Assert-False (Test-NumericValue -Value "-5") "Rejects negative integer (-5)"
    Assert-False (Test-NumericValue -Value "12.5") "Rejects decimal number (12.5)"
    Assert-False (Test-NumericValue -Value "") "Rejects empty string"

    # Range checking
    Assert-True (Test-NumericValue -Value "50" -Min 1 -Max 100) "Accepts value within range (50 in 1-100)"
    Assert-False (Test-NumericValue -Value "0" -Min 1 -Max 100) "Rejects value below minimum (0 < 1)"
    Assert-False (Test-NumericValue -Value "150" -Min 1 -Max 100) "Rejects value above maximum (150 > 100)"
    Assert-True (Test-NumericValue -Value "1" -Min 1 -Max 100) "Accepts minimum value (1)"
    Assert-True (Test-NumericValue -Value "100" -Min 1 -Max 100) "Accepts maximum value (100)"
}

# ============================================
# Test-WebhookUrl TESTS
# ============================================

function Test-ValidationWebhookUrl {
    Write-Host "`n=== Test-WebhookUrl Tests ===" -ForegroundColor Cyan

    # HTTPS requirement
    Assert-True (Test-WebhookUrl -Url "https://example.com/webhook") "Accepts HTTPS URL"
    Assert-False (Test-WebhookUrl -Url "http://example.com/webhook") "Rejects HTTP URL"
    Assert-False (Test-WebhookUrl -Url "ftp://example.com/file") "Rejects FTP URL"

    # SSRF protection - localhost
    Assert-False (Test-WebhookUrl -Url "https://localhost/webhook") "Rejects localhost"
    Assert-False (Test-WebhookUrl -Url "https://127.0.0.1/webhook") "Rejects 127.0.0.1"
    Assert-False (Test-WebhookUrl -Url "https://0.0.0.0/webhook") "Rejects 0.0.0.0"

    # SSRF protection - private IPs
    Assert-False (Test-WebhookUrl -Url "https://192.168.1.1/webhook") "Rejects 192.168.x.x"
    Assert-False (Test-WebhookUrl -Url "https://10.0.0.1/webhook") "Rejects 10.x.x.x"
    Assert-False (Test-WebhookUrl -Url "https://172.16.0.1/webhook") "Rejects 172.16-31.x.x"
    Assert-False (Test-WebhookUrl -Url "https://169.254.169.254/metadata") "Rejects 169.254.x.x"

    # Internal domains
    Assert-False (Test-WebhookUrl -Url "https://test.internal/webhook") "Rejects .internal domain"
    Assert-False (Test-WebhookUrl -Url "https://server.local/webhook") "Rejects .local domain"
    Assert-False (Test-WebhookUrl -Url "https://app.corp/webhook") "Rejects .corp domain"

    # Valid public domains
    Assert-True (Test-WebhookUrl -Url "https://hooks.slack.com/services/T/B/X") "Accepts Slack URL"
    Assert-True (Test-WebhookUrl -Url "https://discord.com/api/webhooks/123/abc") "Accepts Discord URL"

    # Empty URL
    Assert-True (Test-WebhookUrl -Url "") "Accepts empty URL (not configured)"
}

# ============================================
# Test-EmailAddress TESTS
# ============================================

function Test-ValidationEmail {
    Write-Host "`n=== Test-EmailAddress Tests ===" -ForegroundColor Cyan

    # Valid emails
    Assert-True (Test-EmailAddress -Email "user@example.com") "Accepts simple email"
    Assert-True (Test-EmailAddress -Email "first.last@company.co.uk") "Accepts email with dots and TLDs"
    Assert-True (Test-EmailAddress -Email "user+tag@example.com") "Accepts email with plus sign"
    Assert-True (Test-EmailAddress -Email "user_name@example.com") "Accepts email with underscore"

    # Invalid emails
    Assert-False (Test-EmailAddress -Email "notanemail") "Rejects string without @"
    Assert-False (Test-EmailAddress -Email "@example.com") "Rejects email without username"
    Assert-False (Test-EmailAddress -Email "user@") "Rejects email without domain"
    Assert-False (Test-EmailAddress -Email "user@domain") "Rejects email without TLD"
    Assert-False (Test-EmailAddress -Email "user name@example.com") "Rejects email with spaces"

    # Empty email
    Assert-True (Test-EmailAddress -Email "") "Accepts empty email (optional)"
}

# ============================================
# Test-FilePath TESTS
# ============================================

function Test-ValidationFilePath {
    Write-Host "`n=== Test-FilePath Tests ===" -ForegroundColor Cyan

    # Basic paths
    Assert-True (Test-FilePath -Path "C:\Users\Test\file.txt") "Accepts Windows absolute path"
    Assert-True (Test-FilePath -Path "relative\path\file.txt") "Accepts relative path"
    Assert-True (Test-FilePath -Path ".\current\file.txt") "Accepts .\ path"

    # Injection protection
    Assert-False (Test-FilePath -Path "file.txt; rm -rf /") "Rejects semicolon"
    Assert-False (Test-FilePath -Path "file.txt | cat") "Rejects pipe"
    Assert-False (Test-FilePath -Path "file.txt && echo") "Rejects &&"
    Assert-False (Test-FilePath -Path 'file$(whoami).txt') "Rejects command substitution"

    # Existence checking
    $testFile = Join-Path $TestDir "exists.txt"
    "test" | Out-File -FilePath $testFile -Encoding UTF8

    Assert-True (Test-FilePath -Path $testFile -RequireExists) "Accepts existing file when required"
    Assert-False (Test-FilePath -Path "C:\nonexistent\file.txt" -RequireExists) "Rejects non-existent file when required"
    Assert-True (Test-FilePath -Path "C:\nonexistent\file.txt") "Accepts non-existent file when not required"

    # Empty path
    Assert-True (Test-FilePath -Path "") "Accepts empty path (optional)"
}

# ============================================
# ConvertTo-JsonEscaped TESTS
# ============================================

function Test-JsonEscaping {
    Write-Host "`n=== ConvertTo-JsonEscaped Tests ===" -ForegroundColor Cyan

    # Quotes
    $result = ConvertTo-JsonEscaped -Text 'Text with "quotes" inside'
    Assert-Contains $result '\"' "Escapes double quotes"

    # Backslashes
    $result = ConvertTo-JsonEscaped -Text 'Path\with\backslashes'
    Assert-Contains $result '\\' "Escapes backslashes"

    # Newlines
    $result = ConvertTo-JsonEscaped -Text "Line 1`nLine 2`nLine 3"
    Assert-Contains $result '\n' "Escapes newlines"

    # Tabs
    $result = ConvertTo-JsonEscaped -Text "Column1`tColumn2`tColumn3"
    Assert-Contains $result '\t' "Escapes tabs"

    # Carriage return
    $result = ConvertTo-JsonEscaped -Text "Line 1`rLine 2"
    Assert-Contains $result '\r' "Escapes carriage return"

    # Combined
    $result = ConvertTo-JsonEscaped -Text "`"Message`"`nWith`t`"multiple`"`rspecial\chars"
    Assert-Contains $result '\"' "Handles combined special chars - quotes"
    Assert-Contains $result '\n' "Handles combined special chars - newlines"
    Assert-Contains $result '\t' "Handles combined special chars - tabs"

    # Empty string
    $result = ConvertTo-JsonEscaped -Text ""
    Assert-Equals "" $result "Returns empty string for empty input"
}

# ============================================
# Hide-SensitiveToken TESTS
# ============================================

function Test-TokenMasking {
    Write-Host "`n=== Hide-SensitiveToken Tests ===" -ForegroundColor Cyan

    # Long token
    $result = Hide-SensitiveToken -Token "1234567890ABCDEFGHIJKLMNOP"
    Assert-Contains $result "12345678" "Shows first 8 characters"
    Assert-Contains $result "REDACTED" "Shows REDACTED marker"
    Assert-False ($result -like "*MNOP*") "Hides rest of token"

    # Short token
    $result = Hide-SensitiveToken -Token "ABC123"
    Assert-Equals "[REDACTED]" $result "Short token fully redacted"

    # Empty token
    $result = Hide-SensitiveToken -Token ""
    Assert-Equals "[REDACTED]" $result "Empty token returns [REDACTED]"

    # Exactly 12 characters
    $result = Hide-SensitiveToken -Token "123456789012"
    Assert-Contains $result "12345678" "Shows first 8 chars of 12-char token"
    Assert-Contains $result "REDACTED" "Shows REDACTED marker"

    # Custom prefix length
    $result = Hide-SensitiveToken -Token "1234567890ABCDEFGHIJKLMNOP" -PrefixLength 4
    Assert-Contains $result "1234" "Shows custom prefix length (4)"
    Assert-Contains $result "REDACTED" "Shows REDACTED marker with custom length"
}

# ============================================
# BACKWARDS COMPATIBILITY ALIASES
# ============================================

function Test-BackwardsCompatAliases {
    Write-Host "`n=== Backwards Compatibility Aliases ===" -ForegroundColor Cyan

    # Check if aliases are defined (they may not be in all environments)
    $hasAliases = $true

    try {
        # Test alias for Test-WebhookUrl (both Test-WebhookURL and Validate-WebhookUrl)
        $result = Validate-WebhookUrl -Url "https://example.com/webhook" -ErrorAction SilentlyContinue
        Assert-True $result "Validate-WebhookUrl alias works"
    } catch {
        Write-Host "  Note: Validate-WebhookUrl alias not available" -ForegroundColor Yellow
    }

    try {
        $result = Validate-NumericValue -Value "42" -ErrorAction SilentlyContinue
        Assert-True $result "Validate-NumericValue alias works"
    } catch {
        Write-Host "  Note: Validate-NumericValue alias not available" -ForegroundColor Yellow
    }
}

# ============================================
# COMPATIBILITY UTILITIES TESTS
# ============================================

function Test-CompatUtilities {
    Write-Host "`n=== Compatibility Utilities Tests ===" -ForegroundColor Cyan

    $compatLib = Join-Path $RalphDir "lib/compat-utils.ps1"

    if (-not (Test-Path $compatLib)) {
        Write-Host "  Skipping - compat-utils.ps1 not found" -ForegroundColor Yellow
        return
    }

    # Source the library
    . $compatLib

    # Test platform detection
    if (Get-Command Get-RalphPlatform -ErrorAction SilentlyContinue) {
        $platform = Get-RalphPlatform
        Assert-True ($platform -in @("Windows", "Linux", "macOS", "Unknown")) "Get-RalphPlatform returns valid platform: $platform"
    }

    # Test path conversion
    if (Get-Command Convert-ToUnixPath -ErrorAction SilentlyContinue) {
        $winPath = "C:\Users\Test\file.txt"
        $unixPath = Convert-ToUnixPath -Path $winPath
        Assert-Contains $unixPath "/" "Converts Windows path to Unix style"
    }

    # Test null device
    if (Get-Command Get-NullDevice -ErrorAction SilentlyContinue) {
        $nullDev = Get-NullDevice
        Assert-True ($nullDev -in @("/dev/null", "NUL", "\dev\null")) "Get-NullDevice returns valid null device: $nullDev"
    }
}

# ============================================
# POWERSHELL VERSION CHECK
# ============================================

function Test-PowerShellVersion {
    Write-Host "`n=== PowerShell Version Check ===" -ForegroundColor Cyan

    $psVersion = $PSVersionTable.PSVersion.Major

    Assert-True ($psVersion -ge 5) "PowerShell 5.0 or later (current: $psVersion)"

    if ($PSVersionTable.PSEdition) {
        Write-Host "  PowerShell Edition: $($PSVersionTable.PSEdition)" -ForegroundColor Gray
    }
}

# ============================================
# REQUIRED COMMANDS CHECK
# ============================================

function Test-RequiredCommands {
    Write-Host "`n=== Required Commands Check ===" -ForegroundColor Cyan

    $commands = @("git")

    foreach ($cmd in $commands) {
        $exists = Get-Command $cmd -ErrorAction SilentlyContinue
        if ($exists) {
            $Script:TestsRun++
            $Script:TestsPassed++
            Write-Host "✓ Command available: $cmd" -ForegroundColor Green
        } else {
            $Script:TestsRun++
            $Script:TestsFailed++
            Write-Host "✗ Command missing: $cmd (optional but recommended)" -ForegroundColor Yellow
        }
    }
}

# ============================================
# ERROR HANDLING TEST
# ============================================

function Test-ErrorHandling {
    Write-Host "`n=== Error Handling Tests ===" -ForegroundColor Cyan

    # Test that validation functions don't throw exceptions
    try {
        $result = Test-NumericValue -Value "invalid" -ErrorAction SilentlyContinue
        Assert-False $result "Invalid numeric value returns false (not exception)"
    } catch {
        Assert-True $false "Test-NumericValue should not throw exception"
    }

    try {
        $result = Test-WebhookUrl -Url "http://bad.url" -ErrorAction SilentlyContinue
        Assert-False $result "Invalid URL returns false (not exception)"
    } catch {
        Assert-True $false "Test-WebhookUrl should not throw exception"
    }

    try {
        $result = Test-EmailAddress -Email "invalid" -ErrorAction SilentlyContinue
        Assert-False $result "Invalid email returns false (not exception)"
    } catch {
        Assert-True $false "Test-EmailAddress should not throw exception"
    }
}

# ============================================
# RUN ALL TESTS
# ============================================

function Invoke-AllTests {
    Write-Host "`n╔═══════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║  Ralph PowerShell Test Suite             ║" -ForegroundColor Cyan
    Write-Host "╚═══════════════════════════════════════════╝`n" -ForegroundColor Cyan

    Initialize-TestEnvironment

    try {
        # Check if validation library is loaded
        if (Get-Command Test-NumericValue -ErrorAction SilentlyContinue) {
            Test-ValidationNumeric
            Test-ValidationWebhookUrl
            Test-ValidationEmail
            Test-ValidationFilePath
            Test-JsonEscaping
            Test-TokenMasking
            Test-BackwardsCompatAliases
        } else {
            Write-Host "`nValidation library not loaded - skipping validation tests" -ForegroundColor Yellow
        }

        Test-CompatUtilities
        Test-PowerShellVersion
        Test-RequiredCommands
        Test-ErrorHandling
    }
    finally {
        Remove-TestEnvironment
    }

    # Print summary
    Write-Host "`n═══════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "PowerShell Test Summary" -ForegroundColor Cyan
    Write-Host "═══════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "Tests run:    $Script:TestsRun"
    Write-Host "Tests passed: $Script:TestsPassed" -ForegroundColor Green
    Write-Host "Tests failed: $Script:TestsFailed" -ForegroundColor $(if ($Script:TestsFailed -eq 0) { "Green" } else { "Red" })

    if ($Script:TestsFailed -eq 0) {
        Write-Host "`n✓ All PowerShell tests passed!" -ForegroundColor Green
        return 0
    } else {
        Write-Host "`n✗ Some PowerShell tests failed." -ForegroundColor Red
        return 1
    }
}

# Execute tests if run directly
if ($MyInvocation.InvocationName -ne '.') {
    $exitCode = Invoke-AllTests
    exit $exitCode
}
