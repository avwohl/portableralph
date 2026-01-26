# example-usage.ps1 - Example demonstrating PowerShell compatibility utilities
# Shows how to write cross-platform PowerShell scripts using compat-utils.ps1

# Load the compatibility utilities
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. "$scriptDir\compat-utils.ps1"

Write-Host ""
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "PowerShell Cross-Platform Script Example" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host ""

# 1. Path Conversion
Write-Host "1. Path Conversion" -ForegroundColor Yellow
Write-Host "   ---------------" -ForegroundColor Yellow

$unixPaths = @(
    "/c/Users/john/Documents/file.txt",
    "/mnt/c/Windows/System32",
    "C:\Program Files\App",
    "relative/path/to/file.txt"
)

foreach ($path in $unixPaths) {
    $converted = Get-UnixStylePath $path
    Write-Host "   $path"
    Write-Host "   -> $converted" -ForegroundColor Gray
}
Write-Host ""

# 2. Process Management
Write-Host "2. Process Management" -ForegroundColor Yellow
Write-Host "   ------------------" -ForegroundColor Yellow

# Get PowerShell processes
$psPids = Get-ProcessByName "powershell*"
Write-Host "   Found $($psPids.Count) PowerShell process(es)"
Write-Host "   PIDs: $($psPids -join ', ')" -ForegroundColor Gray

# Get full process info
$psProcs = Get-ProcessByName "powershell*" -Full
if ($psProcs.Count -gt 0) {
    Write-Host "   First process details:"
    Write-Host "     PID: $($psProcs[0].Id)" -ForegroundColor Gray
    Write-Host "     Name: $($psProcs[0].Name)" -ForegroundColor Gray
    Write-Host "     Memory: $([math]::Round($psProcs[0].WorkingSet64 / 1MB, 2)) MB" -ForegroundColor Gray
}
Write-Host ""

# 3. Background Process Example
Write-Host "3. Background Process" -ForegroundColor Yellow
Write-Host "   ------------------" -ForegroundColor Yellow

# Create a simple PowerShell script to run in background
$tempScript = [System.IO.Path]::GetTempFileName() + ".ps1"
@"
Write-Output "Background task started at: `$(Get-Date)"
Start-Sleep -Seconds 2
Write-Output "Background task completed at: `$(Get-Date)"
"@ | Out-File -FilePath $tempScript -Encoding UTF8

$outputFile = [System.IO.Path]::GetTempFileName()

Write-Host "   Starting background process..."
$bgProc = Start-BackgroundProcess -Command "powershell.exe" `
    -Arguments @("-File", $tempScript, "-NonInteractive") `
    -OutputFile $outputFile

if ($bgProc) {
    Write-Host "   Background process started with PID: $($bgProc.Id)" -ForegroundColor Green
    Start-Sleep -Seconds 3

    # Check if process completed
    if ($bgProc.HasExited) {
        Write-Host "   Background process completed" -ForegroundColor Green
    } else {
        Write-Host "   Background process still running, stopping..." -ForegroundColor Yellow
        Stop-Process -Id $bgProc.Id -Force -ErrorAction SilentlyContinue
    }
} else {
    Write-Host "   Failed to start background process" -ForegroundColor Red
}

# Clean up
Remove-Item -Path $tempScript -Force -ErrorAction SilentlyContinue
Remove-Item -Path $outputFile -Force -ErrorAction SilentlyContinue
Write-Host ""

# 4. File Search
Write-Host "4. File Search" -ForegroundColor Yellow
Write-Host "   -----------" -ForegroundColor Yellow

# Find PowerShell scripts in lib directory
$ps1Files = Select-FilesByPattern -Path $scriptDir -Name "*.ps1" -Type 'f'
Write-Host "   Found $($ps1Files.Count) PowerShell script(s) in lib directory:"
$ps1Files | ForEach-Object {
    $fileName = Split-Path -Leaf $_
    Write-Host "     - $fileName" -ForegroundColor Gray
}
Write-Host ""

# 5. Content Search
Write-Host "5. Content Search" -ForegroundColor Yellow
Write-Host "   --------------" -ForegroundColor Yellow

# Create a test file
$testFile = [System.IO.Path]::GetTempFileName()
@"
This is line 1
This line contains ERROR
This line contains WARNING
Normal line here
Another error in lowercase
"@ | Out-File -FilePath $testFile -Encoding UTF8

Write-Host "   Searching for 'ERROR' in test file..."
$matches = Search-FileContent -Pattern "ERROR" -Path $testFile
Write-Host "   Found $($matches.Count) match(es)"

Write-Host "   Case-insensitive search for 'error'..."
$matchesCI = Search-FileContent -Pattern "error" -Path $testFile -IgnoreCase
Write-Host "   Found $($matchesCI.Count) match(es)"

# Clean up
Remove-Item -Path $testFile -Force
Write-Host ""

# 6. Text Processing (AWK-like)
Write-Host "6. Text Processing (AWK-like)" -ForegroundColor Yellow
Write-Host "   ---------------------------" -ForegroundColor Yellow

$data = @"
apple red fruit
banana yellow fruit
carrot orange vegetable
grape purple fruit
"@

Write-Host "   Original data:"
$data.Split("`n") | ForEach-Object { Write-Host "     $_" -ForegroundColor Gray }

Write-Host "   Extracting fields 1 and 3:"
$data | Format-TextWithAwk -Fields @(1, 3) | ForEach-Object {
    Write-Host "     $_" -ForegroundColor Gray
}

Write-Host "   Converting to uppercase:"
$data | Format-TextWithAwk -ScriptBlock { $_.ToUpper() } | ForEach-Object {
    Write-Host "     $_" -ForegroundColor Gray
}
Write-Host ""

# 7. Line Counting
Write-Host "7. Line Counting (wc)" -ForegroundColor Yellow
Write-Host "   ------------------" -ForegroundColor Yellow

$testFile = [System.IO.Path]::GetTempFileName()
@"
Line 1
Line 2
Line 3
Line 4
Line 5
"@ | Out-File -FilePath $testFile -Encoding UTF8

$stats = Count-Lines -Path $testFile
Write-Host "   File statistics:"
Write-Host "     Lines: $($stats.Lines)" -ForegroundColor Gray
Write-Host "     Words: $($stats.Words)" -ForegroundColor Gray
Write-Host "     Characters: $($stats.Characters)" -ForegroundColor Gray
Write-Host "     Bytes: $($stats.Bytes)" -ForegroundColor Gray

# Clean up
Remove-Item -Path $testFile -Force
Write-Host ""

# 8. File Statistics
Write-Host "8. File Statistics (stat)" -ForegroundColor Yellow
Write-Host "   ----------------------" -ForegroundColor Yellow

# Get stats for this script
$scriptPath = $MyInvocation.MyCommand.Path
$stats = Get-FileStats -Path $scriptPath

Write-Host "   Script file: $($stats.Name)"
Write-Host "   Size: $($stats.SizeFormatted)" -ForegroundColor Gray
Write-Host "   Type: $($stats.Type)" -ForegroundColor Gray
Write-Host "   Created: $($stats.Created)" -ForegroundColor Gray
Write-Host "   Modified: $($stats.Modified)" -ForegroundColor Gray
Write-Host "   Owner: $($stats.Owner)" -ForegroundColor Gray
Write-Host ""

# 9. File Permissions
Write-Host "9. File Permissions (chmod)" -ForegroundColor Yellow
Write-Host "   -------------------------" -ForegroundColor Yellow

$testFile = [System.IO.Path]::GetTempFileName()
"Test content" | Out-File -FilePath $testFile

Write-Host "   Setting file as read-only..."
$result = Set-FilePermission -Path $testFile -ReadOnly
if ($result) {
    Write-Host "   File is now read-only" -ForegroundColor Green

    $item = Get-Item -Path $testFile
    $isReadOnly = ($item.Attributes -band [System.IO.FileAttributes]::ReadOnly) -ne 0
    Write-Host "   Verified: Read-only = $isReadOnly" -ForegroundColor Gray

    # Remove read-only for cleanup
    $item.Attributes = $item.Attributes -bxor [System.IO.FileAttributes]::ReadOnly
}

# Clean up
Remove-Item -Path $testFile -Force
Write-Host ""

# 10. Best Practices Summary
Write-Host "10. Best Practices Summary" -ForegroundColor Yellow
Write-Host "    ----------------------" -ForegroundColor Yellow
Write-Host "    " -NoNewline
Write-Host "✓" -ForegroundColor Green -NoNewline
Write-Host " Use Get-UnixStylePath for path conversion"
Write-Host "    " -NoNewline
Write-Host "✓" -ForegroundColor Green -NoNewline
Write-Host " Use Get/Stop-ProcessByName instead of taskkill"
Write-Host "    " -NoNewline
Write-Host "✓" -ForegroundColor Green -NoNewline
Write-Host " Use Search-FileContent instead of grep"
Write-Host "    " -NoNewline
Write-Host "✓" -ForegroundColor Green -NoNewline
Write-Host " Use Select-FilesByPattern instead of find"
Write-Host "    " -NoNewline
Write-Host "✓" -ForegroundColor Green -NoNewline
Write-Host " Use Start-BackgroundProcess instead of Start-Job for long tasks"
Write-Host "    " -NoNewline
Write-Host "✓" -ForegroundColor Green -NoNewline
Write-Host " Use Set-FilePermission for ACL management"
Write-Host ""

Write-Host "==================================================" -ForegroundColor Cyan
Write-Host "Example completed successfully!" -ForegroundColor Cyan
Write-Host "==================================================" -ForegroundColor Cyan
Write-Host ""
