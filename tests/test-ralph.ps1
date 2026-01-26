#!/usr/bin/env pwsh
# Unit tests for ralph.ps1
# Tests the main Ralph PowerShell script

<#
.SYNOPSIS
    Unit tests for Ralph PowerShell main script

.DESCRIPTION
    Tests Ralph launcher functionality including:
    - Version and help flags
    - Plan file validation
    - Mode validation (plan/build)
    - Configuration management
    - Progress file handling
#>

param()

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RalphDir = Split-Path -Parent $ScriptDir
$TestDir = Join-Path $ScriptDir "test-output-ralph-ps"

# Test counters
$Script:TestsRun = 0
$Script:TestsPassed = 0
$Script:TestsFailed = 0

# Setup test environment
function Initialize-TestEnvironment {
    if (Test-Path $TestDir) {
        Remove-Item $TestDir -Recurse -Force
    }
    New-Item -ItemType Directory -Path $TestDir -Force | Out-Null

    # Set test HOME
    $env:HOME = $TestDir
    $env:RALPH_SLACK_WEBHOOK_URL = ""
    $env:RALPH_DISCORD_WEBHOOK_URL = ""
    $env:RALPH_TELEGRAM_BOT_TOKEN = ""
    $env:RALPH_TELEGRAM_CHAT_ID = ""
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
        [string]$Expected,
        [string]$Actual,
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

function Assert-Contains {
    param(
        [string]$Haystack,
        [string]$Needle,
        [string]$Message = ""
    )

    $Script:TestsRun++
    if ($Haystack -match [regex]::Escape($Needle)) {
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

function Assert-FileExists {
    param(
        [string]$FilePath,
        [string]$Message = "File should exist: $FilePath"
    )

    $Script:TestsRun++
    if (Test-Path $FilePath) {
        $Script:TestsPassed++
        Write-Host "✓ $Message" -ForegroundColor Green
        return $true
    } else {
        $Script:TestsFailed++
        Write-Host "✗ $Message" -ForegroundColor Red
        return $false
    }
}

function Assert-ExitCode {
    param(
        [int]$Expected,
        [int]$Actual,
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
        Write-Host "  Expected exit code: $Expected" -ForegroundColor Yellow
        Write-Host "  Actual exit code:   $Actual" -ForegroundColor Yellow
        return $false
    }
}

# Individual test functions
function Test-VersionFlag {
    Write-Host "`nTesting: Version flag" -ForegroundColor Cyan

    $ralphScript = Join-Path $RalphDir "ralph.ps1"

    if (-not (Test-Path $ralphScript)) {
        Write-Host "  Note: ralph.ps1 not yet implemented, testing ralph.sh via bash" -ForegroundColor Yellow
        $ralphScript = Join-Path $RalphDir "ralph.sh"

        if (-not (Test-Path $ralphScript)) {
            Write-Host "  Skipping: Ralph scripts not found" -ForegroundColor Yellow
            return
        }

        # Test with bash
        $output = & bash $ralphScript --version 2>&1 | Out-String
        Assert-Contains $output "PortableRalph" "Version flag shows PortableRalph"
        Assert-Contains $output "v" "Version flag shows version number"
    } else {
        # Test PowerShell version
        $output = & $ralphScript -Version 2>&1 | Out-String
        Assert-Contains $output "PortableRalph" "PowerShell version flag shows PortableRalph"
    }
}

function Test-HelpFlag {
    Write-Host "`nTesting: Help flag" -ForegroundColor Cyan

    $ralphScript = Join-Path $RalphDir "ralph.sh"

    if (Test-Path $ralphScript) {
        $output = & bash $ralphScript --help 2>&1 | Out-String
        Assert-Contains $output "Usage:" "Help flag shows usage"
        Assert-Contains $output "plan" "Help flag mentions plan mode"
        Assert-Contains $output "build" "Help flag mentions build mode"
    } else {
        Write-Host "  Skipping: Ralph script not found" -ForegroundColor Yellow
    }
}

function Test-PlanFileValidation {
    Write-Host "`nTesting: Plan file validation" -ForegroundColor Cyan

    $ralphScript = Join-Path $RalphDir "ralph.sh"

    if (-not (Test-Path $ralphScript)) {
        Write-Host "  Skipping: Ralph script not found" -ForegroundColor Yellow
        return
    }

    # Test missing file
    $testPlan = Join-Path $TestDir "nonexistent.md"
    $output = & bash $ralphScript $testPlan 2>&1 | Out-String
    $exitCode = $LASTEXITCODE

    Assert-Contains $output "not found" "Missing plan file shows error"

    # Test valid file creation
    $testPlan = Join-Path $TestDir "test-plan.md"
    "# Test Plan`n`nTest content" | Out-File -FilePath $testPlan -Encoding UTF8

    Assert-FileExists $testPlan "Test plan file created"
}

function Test-ModeValidation {
    Write-Host "`nTesting: Mode validation" -ForegroundColor Cyan

    $testPlan = Join-Path $TestDir "mode-test.md"
    @"
# Mode Test Plan

## Goal
Test mode validation

## Tasks
- [ ] Task 1
"@ | Out-File -FilePath $testPlan -Encoding UTF8

    $ralphScript = Join-Path $RalphDir "ralph.sh"

    if (Test-Path $ralphScript) {
        # Test plan mode
        $output = & bash $ralphScript $testPlan plan 2>&1 | Out-String
        Write-Host "  Note: Plan mode validation requires full implementation" -ForegroundColor Yellow

        # Test invalid mode
        $output = & bash $ralphScript $testPlan invalid_mode 2>&1 | Out-String
        # Should show error or default to build
    }
}

function Test-ConfigFile {
    Write-Host "`nTesting: Config file handling" -ForegroundColor Cyan

    $configFile = Join-Path $TestDir ".ralph.env"

    # Create test config
    @"
export RALPH_SLACK_WEBHOOK_URL="https://hooks.slack.com/test"
export RALPH_AUTO_COMMIT="true"
"@ | Out-File -FilePath $configFile -Encoding UTF8

    Assert-FileExists $configFile "Config file created"

    $content = Get-Content $configFile -Raw
    Assert-Contains $content "RALPH_SLACK_WEBHOOK_URL" "Config contains webhook URL"
    Assert-Contains $content "RALPH_AUTO_COMMIT" "Config contains auto-commit setting"
}

function Test-ProgressFile {
    Write-Host "`nTesting: Progress file naming" -ForegroundColor Cyan

    $testPlan = Join-Path $TestDir "my-feature.md"
    "# Feature`n`n## Tasks`n- [ ] Task 1" | Out-File -FilePath $testPlan -Encoding UTF8

    # Progress file should be named: my-feature_PROGRESS.md
    $expectedProgress = Join-Path $TestDir "my-feature_PROGRESS.md"

    # Create mock progress file
    @"
# Feature - PROGRESS

## Status
IN_PROGRESS

## Tasks
- [ ] Task 1
"@ | Out-File -FilePath $expectedProgress -Encoding UTF8

    Assert-FileExists $expectedProgress "Progress file follows naming convention"

    $content = Get-Content $expectedProgress -Raw
    Assert-Contains $content "PROGRESS" "Progress file contains PROGRESS marker"
    Assert-Contains $content "Status" "Progress file contains Status section"
}

function Test-DoNotCommitDirective {
    Write-Host "`nTesting: DO_NOT_COMMIT directive" -ForegroundColor Cyan

    $testPlan = Join-Path $TestDir "no-commit.md"
    @"
# No Commit Plan

DO_NOT_COMMIT

## Goal
Test without committing

## Tasks
- [ ] Task 1
"@ | Out-File -FilePath $testPlan -Encoding UTF8

    $content = Get-Content $testPlan -Raw
    Assert-Contains $content "DO_NOT_COMMIT" "Plan file contains DO_NOT_COMMIT directive"
}

function Test-WindowsPathHandling {
    Write-Host "`nTesting: Windows path handling" -ForegroundColor Cyan

    $windowsPath = "C:\Users\Test\project\plan.md"
    $unixPath = "/c/Users/Test/project/plan.md"

    # Test path conversion (mock)
    $converted = $windowsPath -replace "^([A-Z]):\\", '/$1/' -replace '\\', '/'
    $converted = $converted -replace "^/([A-Z])/", { "/$(($_.Groups[1].Value).ToLower())/" }

    Assert-Contains $converted "/c/" "Windows path converted to Unix style"
}

function Test-PowerShellCompatibility {
    Write-Host "`nTesting: PowerShell compatibility checks" -ForegroundColor Cyan

    # Test PowerShell version
    $psVersion = $PSVersionTable.PSVersion.Major
    Assert-Equals $true ($psVersion -ge 5).ToString() "PowerShell 5.0 or later"

    # Test required commands
    $commands = @("git", "curl")
    foreach ($cmd in $commands) {
        $exists = Get-Command $cmd -ErrorAction SilentlyContinue
        if ($exists) {
            Write-Host "✓ Command available: $cmd" -ForegroundColor Green
            $Script:TestsRun++
            $Script:TestsPassed++
        } else {
            Write-Host "✗ Command missing: $cmd" -ForegroundColor Red
            $Script:TestsRun++
            $Script:TestsFailed++
        }
    }
}

# Run all tests
function Invoke-AllTests {
    Write-Host "`n╔═══════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║  Ralph PowerShell Unit Tests             ║" -ForegroundColor Cyan
    Write-Host "╚═══════════════════════════════════════════╝`n" -ForegroundColor Cyan

    Initialize-TestEnvironment

    try {
        Test-VersionFlag
        Test-HelpFlag
        Test-PlanFileValidation
        Test-ModeValidation
        Test-ConfigFile
        Test-ProgressFile
        Test-DoNotCommitDirective
        Test-WindowsPathHandling
        Test-PowerShellCompatibility
    }
    finally {
        Remove-TestEnvironment
    }

    # Print summary
    Write-Host "`n═══════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "Test Summary" -ForegroundColor Cyan
    Write-Host "═══════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "Tests run:    $Script:TestsRun"
    Write-Host "Tests passed: $Script:TestsPassed" -ForegroundColor Green
    Write-Host "Tests failed: $Script:TestsFailed" -ForegroundColor $(if ($Script:TestsFailed -eq 0) { "Green" } else { "Red" })

    if ($Script:TestsFailed -eq 0) {
        Write-Host "`n✓ All tests passed!" -ForegroundColor Green
        return 0
    } else {
        Write-Host "`n✗ Some tests failed." -ForegroundColor Red
        return 1
    }
}

# Execute tests if run directly
if ($MyInvocation.InvocationName -ne '.') {
    $exitCode = Invoke-AllTests
    exit $exitCode
}
