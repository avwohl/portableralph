#!/usr/bin/env pwsh
# PowerShell Test Runner for Ralph
# Runs all test suites and reports results

<#
.SYNOPSIS
    Run all Ralph PowerShell tests

.DESCRIPTION
    Executes all test suites for Ralph on Windows PowerShell.
    Supports unit tests, integration tests, and security tests.

.PARAMETER UnitOnly
    Run only unit tests

.PARAMETER IntegrationOnly
    Run only integration tests

.PARAMETER SecurityOnly
    Run only security tests

.PARAMETER Verbose
    Show detailed test output

.PARAMETER StopOnFailure
    Stop execution after first test suite failure

.EXAMPLE
    .\run-all-tests.ps1
    Run all tests

.EXAMPLE
    .\run-all-tests.ps1 -UnitOnly -Verbose
    Run unit tests with verbose output
#>

param(
    [switch]$UnitOnly,
    [switch]$IntegrationOnly,
    [switch]$SecurityOnly,
    [switch]$Verbose,
    [switch]$StopOnFailure
)

$ErrorActionPreference = "Continue"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RalphDir = Split-Path -Parent $ScriptDir

# Colors for output
function Write-Success { param($Message) Write-Host "✓ $Message" -ForegroundColor Green }
function Write-Failure { param($Message) Write-Host "✗ $Message" -ForegroundColor Red }
function Write-Info { param($Message) Write-Host "ℹ $Message" -ForegroundColor Cyan }
function Write-Header { param($Message) Write-Host "`n=== $Message ===" -ForegroundColor Yellow }

# Test results
$Script:TotalTests = 0
$Script:TotalPassed = 0
$Script:TotalFailed = 0
$Script:SuitesRun = 0
$Script:SuitesPassed = 0
$Script:SuitesFailed = 0

# Run a test suite
function Invoke-TestSuite {
    param(
        [string]$TestScript,
        [string]$TestName
    )

    Write-Header "Running $TestName"

    if (-not (Test-Path $TestScript)) {
        Write-Failure "$TestName script not found: $TestScript"
        return $false
    }

    $Script:SuitesRun++

    try {
        $result = & $TestScript
        $exitCode = $LASTEXITCODE

        if ($Verbose) {
            Write-Host $result
        }

        # Parse results from output
        if ($result -match "Tests run:\s*(\d+)") {
            $testsRun = [int]$Matches[1]
            $Script:TotalTests += $testsRun
        }

        if ($result -match "Tests passed:\s*(\d+)") {
            $testsPassed = [int]$Matches[1]
            $Script:TotalPassed += $testsPassed
        }

        if ($result -match "Tests failed:\s*(\d+)") {
            $testsFailed = [int]$Matches[1]
            $Script:TotalFailed += $testsFailed
        }

        if ($exitCode -eq 0) {
            Write-Success "$TestName: PASSED"
            $Script:SuitesPassed++
            return $true
        } else {
            Write-Failure "$TestName: FAILED"
            $Script:SuitesFailed++
            return $false
        }
    }
    catch {
        Write-Failure "$TestName: ERROR - $_"
        $Script:SuitesFailed++
        return $false
    }
}

# Main execution
Write-Host @"

╔═══════════════════════════════════════════════════╗
║     Ralph PowerShell Test Suite Runner           ║
║     Testing Windows Compatibility                 ║
╚═══════════════════════════════════════════════════╝

"@ -ForegroundColor Cyan

$StartTime = Get-Date

# Determine which test suites to run
$RunUnit = -not $IntegrationOnly -and -not $SecurityOnly
$RunIntegration = -not $UnitOnly -and -not $SecurityOnly
$RunSecurity = -not $UnitOnly -and -not $IntegrationOnly

if ($UnitOnly) { $RunUnit = $true }
if ($IntegrationOnly) { $RunIntegration = $true }
if ($SecurityOnly) { $RunSecurity = $true }

# Unit Tests
if ($RunUnit) {
    Write-Header "UNIT TESTS"

    $testPassed = Invoke-TestSuite `
        -TestScript "$ScriptDir\test-ralph.ps1" `
        -TestName "Ralph Main Script Tests"

    if (-not $testPassed -and $StopOnFailure) {
        Write-Failure "Stopping due to test failure"
        exit 1
    }

    $testPassed = Invoke-TestSuite `
        -TestScript "$ScriptDir\test-notify.ps1" `
        -TestName "Notification System Tests"

    if (-not $testPassed -and $StopOnFailure) {
        Write-Failure "Stopping due to test failure"
        exit 1
    }

    $testPassed = Invoke-TestSuite `
        -TestScript "$ScriptDir\test-monitor.ps1" `
        -TestName "Progress Monitor Tests"

    if (-not $testPassed -and $StopOnFailure) {
        Write-Failure "Stopping due to test failure"
        exit 1
    }

    $testPassed = Invoke-TestSuite `
        -TestScript "$ScriptDir\test-powershell.ps1" `
        -TestName "PowerShell Library Tests"

    if (-not $testPassed -and $StopOnFailure) {
        Write-Failure "Stopping due to test failure"
        exit 1
    }
}

# Integration Tests
if ($RunIntegration) {
    Write-Header "INTEGRATION TESTS"

    if (Test-Path "$ScriptDir\test-integration.ps1") {
        $testPassed = Invoke-TestSuite `
            -TestScript "$ScriptDir\test-integration.ps1" `
            -TestName "Integration Tests"

        if (-not $testPassed -and $StopOnFailure) {
            Write-Failure "Stopping due to test failure"
            exit 1
        }
    } else {
        Write-Info "Integration tests not yet implemented for PowerShell"
    }
}

# Security Tests
if ($RunSecurity) {
    Write-Header "SECURITY TESTS"

    if (Test-Path "$ScriptDir\test-security.ps1") {
        $testPassed = Invoke-TestSuite `
            -TestScript "$ScriptDir\test-security.ps1" `
            -TestName "Security Tests"

        if (-not $testPassed -and $StopOnFailure) {
            Write-Failure "Stopping due to test failure"
            exit 1
        }
    } else {
        Write-Info "Security tests not yet implemented for PowerShell"
    }
}

# Calculate duration
$EndTime = Get-Date
$Duration = $EndTime - $StartTime

# Print summary
Write-Host @"

╔═══════════════════════════════════════════════════╗
║              TEST SUMMARY                          ║
╚═══════════════════════════════════════════════════╝

"@ -ForegroundColor Cyan

Write-Host "Test Suites:"
Write-Host "  Total:  $Script:SuitesRun"
if ($Script:SuitesPassed -gt 0) {
    Write-Host "  Passed: $Script:SuitesPassed" -ForegroundColor Green
}
if ($Script:SuitesFailed -gt 0) {
    Write-Host "  Failed: $Script:SuitesFailed" -ForegroundColor Red
}

Write-Host "`nIndividual Tests:"
Write-Host "  Total:  $Script:TotalTests"
if ($Script:TotalPassed -gt 0) {
    Write-Host "  Passed: $Script:TotalPassed" -ForegroundColor Green
}
if ($Script:TotalFailed -gt 0) {
    Write-Host "  Failed: $Script:TotalFailed" -ForegroundColor Red
}

Write-Host "`nDuration: $($Duration.TotalSeconds) seconds"

# Exit with appropriate code
if ($Script:SuitesFailed -eq 0) {
    Write-Host "`n✓ All test suites passed!" -ForegroundColor Green
    exit 0
} else {
    Write-Host "`n✗ Some test suites failed." -ForegroundColor Red
    exit 1
}
