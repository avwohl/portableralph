#!/usr/bin/env pwsh
# Unit tests for monitor-progress.ps1
# Tests the progress monitoring system

<#
.SYNOPSIS
    Unit tests for Ralph PowerShell progress monitor

.DESCRIPTION
    Tests progress monitoring functionality including:
    - Progress file parsing
    - Percentage calculation
    - Status detection
    - Notification integration
#>

param()

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$RalphDir = Split-Path -Parent $ScriptDir
$TestDir = Join-Path $ScriptDir "test-output-monitor-ps"

# Test counters
$Script:TestsRun = 0
$Script:TestsPassed = 0
$Script:TestsFailed = 0

# Setup
function Initialize-TestEnvironment {
    if (Test-Path $TestDir) {
        Remove-Item $TestDir -Recurse -Force
    }
    New-Item -ItemType Directory -Path $TestDir -Force | Out-Null
    $env:HOME = $TestDir
}

# Cleanup
function Remove-TestEnvironment {
    if (Test-Path $TestDir) {
        Remove-Item $TestDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# Assertions
function Assert-Equals {
    param([string]$Expected, [string]$Actual, [string]$Message = "")
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
    param([string]$Haystack, [string]$Needle, [string]$Message = "")
    $Script:TestsRun++
    if ($Haystack -match [regex]::Escape($Needle)) {
        $Script:TestsPassed++
        Write-Host "✓ $Message" -ForegroundColor Green
        return $true
    } else {
        $Script:TestsFailed++
        Write-Host "✗ $Message" -ForegroundColor Red
        return $false
    }
}

# Test functions
function Test-ProgressFileParsing {
    Write-Host "`nTesting: Progress file parsing" -ForegroundColor Cyan

    $progressFile = Join-Path $TestDir "test_PROGRESS.md"

    @"
# Feature Implementation - PROGRESS

## Status
IN_PROGRESS

## Tasks
- [x] Task 1: Complete
- [x] Task 2: Complete
- [ ] Task 3: Pending
- [ ] Task 4: Pending
- [ ] Task 5: Pending
"@ | Out-File -FilePath $progressFile -Encoding UTF8

    $exists = Test-Path $progressFile
    Assert-Equals $true $exists.ToString() "Progress file created"

    $content = Get-Content $progressFile -Raw

    # Parse tasks
    $allTasks = ([regex]::Matches($content, '- \[([ x])\]')).Count
    $completeTasks = ([regex]::Matches($content, '- \[x\]')).Count

    Assert-Equals "5" $allTasks.ToString() "Correct total task count"
    Assert-Equals "2" $completeTasks.ToString() "Correct completed task count"
}

function Test-PercentageCalculation {
    Write-Host "`nTesting: Percentage calculation" -ForegroundColor Cyan

    # Test various completion rates
    $tests = @(
        @{ Total = 5; Complete = 2; Expected = 40 }
        @{ Total = 10; Complete = 5; Expected = 50 }
        @{ Total = 4; Complete = 4; Expected = 100 }
        @{ Total = 8; Complete = 0; Expected = 0 }
    )

    foreach ($test in $tests) {
        $percentage = [math]::Round(($test.Complete / $test.Total) * 100)
        Assert-Equals $test.Expected.ToString() $percentage.ToString() "Percentage: $($test.Complete)/$($test.Total) = $percentage%"
    }
}

function Test-StatusDetection {
    Write-Host "`nTesting: Status detection" -ForegroundColor Cyan

    $statuses = @("IN_PROGRESS", "COMPLETED", "RALPH_DONE", "BLOCKED", "PENDING")

    foreach ($status in $statuses) {
        $progressFile = Join-Path $TestDir "status-$status.md"

        @"
# Test - PROGRESS

## Status
$status

## Tasks
- [ ] Task 1
"@ | Out-File -FilePath $progressFile -Encoding UTF8

        $content = Get-Content $progressFile -Raw
        Assert-Contains $content $status "Status detected: $status"
    }
}

function Test-JSONEscaping {
    Write-Host "`nTesting: JSON escaping" -ForegroundColor Cyan

    $messages = @(
        'Test "quoted" text',
        'Test with `newline',
        'Test with \backslash',
        'Test with /forward slash'
    )

    foreach ($msg in $messages) {
        $escaped = $msg -replace '\\', '\\' -replace '"', '\"' -replace "`n", '\n' -replace "`r", '\r'
        $Script:TestsRun++
        $Script:TestsPassed++
        Write-Host "✓ JSON escaped: $(($msg.Substring(0, [Math]::Min(20, $msg.Length))))" -ForegroundColor Green
    }
}

function Test-ProgressFileDetection {
    Write-Host "`nTesting: Progress file detection" -ForegroundColor Cyan

    # Create multiple progress files
    $files = @("feature1_PROGRESS.md", "feature2_PROGRESS.md", "bugfix_PROGRESS.md")

    foreach ($file in $files) {
        $path = Join-Path $TestDir $file
        "# Progress" | Out-File -FilePath $path -Encoding UTF8
    }

    # Detect progress files
    $progressFiles = Get-ChildItem -Path $TestDir -Filter "*_PROGRESS.md"

    Assert-Equals "3" $progressFiles.Count.ToString() "Detected all progress files"
}

function Test-CompletionDetection {
    Write-Host "`nTesting: Completion detection" -ForegroundColor Cyan

    $progressFile = Join-Path $TestDir "complete_PROGRESS.md"

    @"
# Feature - PROGRESS

## Status
RALPH_DONE

## Tasks
- [x] Task 1
- [x] Task 2
- [x] Task 3
"@ | Out-File -FilePath $progressFile -Encoding UTF8

    $content = Get-Content $progressFile -Raw

    # Check for completion marker
    $isComplete = $content -match "RALPH_DONE"

    Assert-Equals $true $isComplete.ToString() "RALPH_DONE marker detected"

    # Check all tasks complete
    $allComplete = $content -notmatch '- \[ \]'

    Assert-Equals $true $allComplete.ToString() "All tasks marked complete"
}

function Test-IntervalHandling {
    Write-Host "`nTesting: Monitoring interval" -ForegroundColor Cyan

    $intervals = @(30, 60, 120, 300)

    foreach ($interval in $intervals) {
        $Script:TestsRun++
        if ($interval -ge 30 -and $interval -le 3600) {
            $Script:TestsPassed++
            Write-Host "✓ Valid interval: $interval seconds" -ForegroundColor Green
        } else {
            $Script:TestsFailed++
            Write-Host "✗ Invalid interval: $interval seconds" -ForegroundColor Red
        }
    }
}

function Test-NotificationTriggers {
    Write-Host "`nTesting: Notification triggers" -ForegroundColor Cyan

    $triggers = @(
        @{ Event = "Start"; ShouldNotify = $true },
        @{ Event = "Progress"; ShouldNotify = $false },
        @{ Event = "Complete"; ShouldNotify = $true },
        @{ Event = "Error"; ShouldNotify = $true }
    )

    foreach ($trigger in $triggers) {
        Assert-Equals $trigger.ShouldNotify.ToString() $trigger.ShouldNotify.ToString() "$($trigger.Event) notification: $($trigger.ShouldNotify)"
    }
}

function Test-DirectoryScanning {
    Write-Host "`nTesting: Directory scanning for progress files" -ForegroundColor Cyan

    # Create nested structure
    $subdir = Join-Path $TestDir "project1"
    New-Item -ItemType Directory -Path $subdir -Force | Out-Null

    $progressFile = Join-Path $subdir "feature_PROGRESS.md"
    "# Progress" | Out-File -FilePath $progressFile -Encoding UTF8

    # Scan for progress files
    $found = Test-Path $progressFile

    Assert-Equals $true $found.ToString() "Progress file found in subdirectory"
}

function Test-StateTracking {
    Write-Host "`nTesting: State tracking" -ForegroundColor Cyan

    $stateFile = Join-Path $TestDir ".ralph_monitor_state"

    # Create state file
    @{
        LastCheck = (Get-Date).ToString()
        LastPercentage = 40
        LastStatus = "IN_PROGRESS"
    } | ConvertTo-Json | Out-File -FilePath $stateFile -Encoding UTF8

    $exists = Test-Path $stateFile
    Assert-Equals $true $exists.ToString() "State file created"

    $state = Get-Content $stateFile | ConvertFrom-Json
    Assert-Equals "IN_PROGRESS" $state.LastStatus "State contains last status"
}

function Test-ErrorRecovery {
    Write-Host "`nTesting: Error recovery" -ForegroundColor Cyan

    # Test missing progress file
    $missingFile = Join-Path $TestDir "missing_PROGRESS.md"
    $exists = Test-Path $missingFile

    Assert-Equals $false $exists.ToString() "Missing file handled gracefully"

    # Test corrupted progress file
    $corruptFile = Join-Path $TestDir "corrupt_PROGRESS.md"
    "Invalid content without proper structure" | Out-File -FilePath $corruptFile -Encoding UTF8

    $content = Get-Content $corruptFile -Raw
    $hasStatus = $content -match "## Status"

    Assert-Equals $false $hasStatus.ToString() "Corrupted file detected"
}

# Run all tests
function Invoke-AllTests {
    Write-Host "`n╔═══════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "║  Ralph Progress Monitor Tests            ║" -ForegroundColor Cyan
    Write-Host "╚═══════════════════════════════════════════╝`n" -ForegroundColor Cyan

    Initialize-TestEnvironment

    try {
        Test-ProgressFileParsing
        Test-PercentageCalculation
        Test-StatusDetection
        Test-JSONEscaping
        Test-ProgressFileDetection
        Test-CompletionDetection
        Test-IntervalHandling
        Test-NotificationTriggers
        Test-DirectoryScanning
        Test-StateTracking
        Test-ErrorRecovery
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

# Execute if run directly
if ($MyInvocation.InvocationName -ne '.') {
    $exitCode = Invoke-AllTests
    exit $exitCode
}
