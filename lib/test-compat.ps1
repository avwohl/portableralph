# test-compat.ps1 - Test Windows compatibility utilities for PowerShell
# Tests all functions in compat-utils.ps1

param(
    [switch]$Verbose
)

$ErrorActionPreference = "Stop"

# Load the compatibility utilities
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. "$scriptDir\compat-utils.ps1"

# Test counters
$script:TestsRun = 0
$script:TestsPassed = 0
$script:TestsFailed = 0

# Test function
function Test-Function {
    param(
        [string]$Name,
        [object]$Expected,
        [object]$Actual
    )

    $script:TestsRun++

    if ($Expected -eq $Actual) {
        Write-Host "✓ $Name" -ForegroundColor Green
        $script:TestsPassed++
        return $true
    } else {
        Write-Host "✗ $Name" -ForegroundColor Red
        Write-Host "  Expected: $Expected" -ForegroundColor Yellow
        Write-Host "  Actual:   $Actual" -ForegroundColor Yellow
        $script:TestsFailed++
        return $false
    }
}

# Test boolean function
function Test-Bool {
    param(
        [string]$Name,
        [bool]$Actual,
        [bool]$Expected
    )

    Test-Function -Name $Name -Expected $Expected -Actual $Actual
}

# Test that function doesn't throw
function Test-NoThrow {
    param(
        [string]$Name,
        [scriptblock]$ScriptBlock
    )

    $script:TestsRun++

    try {
        & $ScriptBlock | Out-Null
        Write-Host "✓ $Name" -ForegroundColor Green
        $script:TestsPassed++
        return $true
    } catch {
        Write-Host "✗ $Name" -ForegroundColor Red
        Write-Host "  Error: $_" -ForegroundColor Yellow
        $script:TestsFailed++
        return $false
    }
}

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "Testing PowerShell Compatibility Utilities" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# Test Get-UnixStylePath
Write-Host "Path Conversion Tests:" -ForegroundColor Yellow
Write-Host "----------------------" -ForegroundColor Yellow

$winPath = Get-UnixStylePath "/c/Users/john/file.txt"
Test-Function "Git Bash path conversion" "C:\Users\john\file.txt" $winPath

$winPath = Get-UnixStylePath "/mnt/c/Users/john/file.txt"
Test-Function "WSL path conversion" "C:\Users\john\file.txt" $winPath

$winPath = Get-UnixStylePath "C:\Windows\System32"
Test-Function "Windows path unchanged" "C:\Windows\System32" $winPath

$winPath = Get-UnixStylePath "relative/path/file.txt"
$expectedRelative = "relative\path\file.txt"
Test-Function "Relative path conversion" $expectedRelative $winPath

Write-Host ""

# Test Process Functions
Write-Host "Process Management Tests:" -ForegroundColor Yellow
Write-Host "-------------------------" -ForegroundColor Yellow

# Test Get-ProcessByName
$psPids = Get-ProcessByName "powershell*"
Test-Bool "Get-ProcessByName returns PIDs" ($psPids.Count -gt 0) $true

$psProcs = Get-ProcessByName "powershell*" -Full
Test-Bool "Get-ProcessByName -Full returns process objects" ($psProcs.Count -gt 0) $true
if ($psProcs.Count -gt 0) {
    Test-Bool "Process object has Id property" ($psProcs[0].PSObject.Properties.Name -contains "Id") $true
}

# Test Stop-ProcessByName (non-destructive - don't actually kill processes)
Write-Host "  Skipping Stop-ProcessByName (would terminate processes)" -ForegroundColor Gray

# Test Start-BackgroundProcess (create a simple background task)
$tempScript = [System.IO.Path]::GetTempFileName() + ".ps1"
"Start-Sleep -Seconds 2; Write-Output 'Done'" | Out-File -FilePath $tempScript -Encoding UTF8

Test-NoThrow "Start-BackgroundProcess" {
    $proc = Start-BackgroundProcess -Command "powershell.exe" -Arguments @("-File", $tempScript, "-NonInteractive")
    if ($proc) {
        Start-Sleep -Milliseconds 500
        Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
    }
}

Remove-Item -Path $tempScript -Force -ErrorAction SilentlyContinue

Write-Host ""

# Test Search-FileContent
Write-Host "File Search Tests:" -ForegroundColor Yellow
Write-Host "------------------" -ForegroundColor Yellow

# Create temp file for testing
$tempFile = [System.IO.Path]::GetTempFileName()
@"
Line 1: This is a test
Line 2: ERROR occurred
Line 3: Another line
Line 4: error in lowercase
Line 5: Final line
"@ | Out-File -FilePath $tempFile -Encoding UTF8

$results = Search-FileContent -Pattern "ERROR" -Path $tempFile
Test-Bool "Search-FileContent finds pattern" ($results.Count -gt 0) $true

$results = Search-FileContent -Pattern "error" -Path $tempFile -IgnoreCase
Test-Bool "Search-FileContent case-insensitive" ($results.Count -ge 2) $true

$fileResults = Search-FileContent -Pattern "Line" -Path $tempFile -FilesOnly
Test-Bool "Search-FileContent -FilesOnly returns file path" ($fileResults -like "*$tempFile*") $true

Remove-Item -Path $tempFile -Force

Write-Host ""

# Test Select-FilesByPattern
Write-Host "File Pattern Tests:" -ForegroundColor Yellow
Write-Host "-------------------" -ForegroundColor Yellow

# Test in current directory
$ps1Files = Select-FilesByPattern -Path $scriptDir -Name "*.ps1" -Type 'f'
Test-Bool "Select-FilesByPattern finds .ps1 files" ($ps1Files.Count -gt 0) $true

# Test directory search
$dirs = Select-FilesByPattern -Path (Split-Path $scriptDir) -Type 'd'
Test-Bool "Select-FilesByPattern finds directories" ($dirs.Count -gt 0) $true

Write-Host ""

# Test Format-TextWithAwk
Write-Host "Text Processing Tests:" -ForegroundColor Yellow
Write-Host "----------------------" -ForegroundColor Yellow

$result = "one two three" | Format-TextWithAwk -Fields @(1, 3)
Test-Function "Format-TextWithAwk extracts fields" ("one`tthree") $result

$result = "alpha:beta:gamma" | Format-TextWithAwk -FieldSeparator ":" -Fields @(1, 2)
Test-Function "Format-TextWithAwk with custom separator" ("alpha`tbeta") $result

$result = "test line" | Format-TextWithAwk -ScriptBlock { $_.ToUpper() }
Test-Function "Format-TextWithAwk with ScriptBlock" "TEST LINE" $result

Write-Host ""

# Test Count-Lines
Write-Host "Line Counting Tests:" -ForegroundColor Yellow
Write-Host "--------------------" -ForegroundColor Yellow

$tempFile = [System.IO.Path]::GetTempFileName()
@"
Line 1
Line 2
Line 3
Line 4
Line 5
"@ | Out-File -FilePath $tempFile -Encoding UTF8

$lineCount = Count-Lines -Path $tempFile -Lines
Test-Function "Count-Lines counts lines" 5 $lineCount

$stats = Count-Lines -Path $tempFile
Test-Bool "Count-Lines returns stats object" ($stats.Lines -eq 5) $true
Test-Bool "Count-Lines includes word count" ($stats.Words -gt 0) $true

Remove-Item -Path $tempFile -Force

Write-Host ""

# Test Get-FileStats
Write-Host "File Stats Tests:" -ForegroundColor Yellow
Write-Host "-----------------" -ForegroundColor Yellow

$tempFile = [System.IO.Path]::GetTempFileName()
"Test content" | Out-File -FilePath $tempFile -Encoding UTF8

$stats = Get-FileStats -Path $tempFile
Test-Bool "Get-FileStats returns object" ($null -ne $stats) $true
Test-Bool "Get-FileStats has Size property" ($stats.PSObject.Properties.Name -contains "Size") $true
Test-Function "Get-FileStats Type is File" "File" $stats.Type

Remove-Item -Path $tempFile -Force

Write-Host ""

# Test Set-FilePermission
Write-Host "File Permission Tests:" -ForegroundColor Yellow
Write-Host "----------------------" -ForegroundColor Yellow

$tempFile = [System.IO.Path]::GetTempFileName()
"Test" | Out-File -FilePath $tempFile

Test-NoThrow "Set-FilePermission -ReadOnly" {
    Set-FilePermission -Path $tempFile -ReadOnly
}

$item = Get-Item -Path $tempFile
Test-Bool "File is marked as read-only" (($item.Attributes -band [System.IO.FileAttributes]::ReadOnly) -ne 0) $true

# Clean up (remove read-only first)
$item.Attributes = $item.Attributes -bxor [System.IO.FileAttributes]::ReadOnly
Remove-Item -Path $tempFile -Force

Write-Host ""

# Performance Test
Write-Host "Performance Tests:" -ForegroundColor Yellow
Write-Host "------------------" -ForegroundColor Yellow

$sw = [System.Diagnostics.Stopwatch]::StartNew()
1..100 | ForEach-Object {
    Get-UnixStylePath "/c/Users/test/file$_.txt" | Out-Null
}
$sw.Stop()
Write-Host "  100 path conversions: $($sw.ElapsedMilliseconds)ms" -ForegroundColor Gray

$sw.Restart()
1..10 | ForEach-Object {
    Get-ProcessByName "powershell*" | Out-Null
}
$sw.Stop()
Write-Host "  10 process lookups: $($sw.ElapsedMilliseconds)ms" -ForegroundColor Gray

Write-Host ""

# Summary
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "Test Summary" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "Tests run:    $script:TestsRun"
Write-Host "Tests passed: $script:TestsPassed" -ForegroundColor Green
if ($script:TestsFailed -gt 0) {
    Write-Host "Tests failed: $script:TestsFailed" -ForegroundColor Red
} else {
    Write-Host "Tests failed: 0"
}
Write-Host ""

if ($script:TestsFailed -eq 0) {
    Write-Host "All tests passed!" -ForegroundColor Green
    exit 0
} else {
    Write-Host "Some tests failed!" -ForegroundColor Red
    exit 1
}
