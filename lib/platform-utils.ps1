# platform-utils.ps1 - Cross-platform utilities for PortableRalph (PowerShell version)
# Functions for path handling, process management, and platform detection
#
# Usage:
#   . .\lib\platform-utils.ps1
#   $OS = Get-OperatingSystem
#   $NormalizedPath = ConvertTo-NormalizedPath "C:\path\to\file"

# Detect operating system
# Returns: Windows, Linux, macOS, WSL, or Unknown
function Get-OperatingSystem {
    if ($IsWindows -or $env:OS -match "Windows") {
        return "Windows"
    }
    elseif ($IsLinux) {
        # Check for WSL
        if (Test-Path "/proc/version") {
            try {
                $version = Get-Content "/proc/version" -ErrorAction SilentlyContinue
                if ($version -match "microsoft") {
                    return "WSL"
                }
            }
            catch {
                # Ignore errors
            }
        }
        return "Linux"
    }
    elseif ($IsMacOS) {
        return "macOS"
    }
    else {
        return "Unknown"
    }
}

# Check if running on Windows
function Test-IsWindows {
    $os = Get-OperatingSystem
    return ($os -eq "Windows")
}

# Check if running on Unix-like system
function Test-IsUnix {
    $os = Get-OperatingSystem
    return ($os -in @("Linux", "macOS"))
}

# Check if running in WSL
function Test-IsWSL {
    $os = Get-OperatingSystem
    return ($os -eq "WSL")
}

# Normalize path separators for current platform
# Args: Path to normalize
# Returns: Normalized path (\ on Windows, / on Unix)
function ConvertTo-NormalizedPath {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Path
    )

    $os = Get-OperatingSystem

    switch ($os) {
        "Windows" {
            # Convert forward slashes to backslashes
            return $Path -replace '/', '\'
        }
        default {
            # Convert backslashes to forward slashes
            return $Path -replace '\\', '/'
        }
    }
}

# Convert WSL path to Windows path
# Args: WSL path (e.g., /mnt/c/Users/...)
# Returns: Windows path (e.g., C:\Users\...)
function ConvertFrom-WSLPath {
    param(
        [Parameter(Mandatory=$true)]
        [string]$WSLPath
    )

    if (-not (Test-IsWSL)) {
        return $WSLPath
    }

    # Check if wslpath is available
    if (Get-Command wslpath -ErrorAction SilentlyContinue) {
        try {
            return & wslpath -w $WSLPath
        }
        catch {
            # Fall through to manual conversion
        }
    }

    # Manual conversion for /mnt/c/... style paths
    if ($WSLPath -match '^/mnt/([a-z])(/.*)?$') {
        $driveLetter = $Matches[1].ToUpper()
        $restOfPath = $Matches[2] -replace '/', '\'
        return "${driveLetter}:${restOfPath}"
    }

    return $WSLPath
}

# Convert Windows path to WSL path
# Args: Windows path (e.g., C:\Users\...)
# Returns: WSL path (e.g., /mnt/c/Users/...)
function ConvertTo-WSLPath {
    param(
        [Parameter(Mandatory=$true)]
        [string]$WindowsPath
    )

    if (-not (Test-IsWSL)) {
        return $WindowsPath
    }

    # Check if wslpath is available
    if (Get-Command wslpath -ErrorAction SilentlyContinue) {
        try {
            return & wslpath -u $WindowsPath
        }
        catch {
            # Fall through to manual conversion
        }
    }

    # Manual conversion for C:\... style paths
    if ($WindowsPath -match '^([A-Za-z]):(.*)$') {
        $driveLetter = $Matches[1].ToLower()
        $restOfPath = $Matches[2] -replace '\\', '/'
        return "/mnt/${driveLetter}${restOfPath}"
    }

    return $WindowsPath
}

# Get absolute path in platform-appropriate format
# Args: Relative or absolute path
# Returns: Absolute path
function Get-AbsolutePath {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Path
    )

    try {
        $resolvedPath = Resolve-Path -Path $Path -ErrorAction SilentlyContinue
        if ($resolvedPath) {
            return $resolvedPath.Path
        }
    }
    catch {
        # Ignore errors
    }

    # Fallback: combine with current directory
    if ([System.IO.Path]::IsPathRooted($Path)) {
        return $Path
    }
    else {
        return Join-Path (Get-Location).Path $Path
    }
}

# Check if a path is absolute
# Args: Path to check
# Returns: $true if absolute, $false if relative
function Test-IsAbsolutePath {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Path
    )

    $os = Get-OperatingSystem

    switch ($os) {
        "Windows" {
            # Windows absolute: C:\... or \\server\...
            return ($Path -match '^[A-Za-z]:' -or $Path -match '^\\\\')
        }
        default {
            # Unix absolute: /...
            return ($Path -match '^/')
        }
    }
}

# Find a command in PATH
# Args: Command name
# Returns: Full path to command or $null
function Find-Command {
    param(
        [Parameter(Mandatory=$true)]
        [string]$CommandName
    )

    $cmd = Get-Command $CommandName -ErrorAction SilentlyContinue
    if ($cmd) {
        return $cmd.Source
    }
    return $null
}

# Check if a process is running
# Args: Process ID
# Returns: $true if running, $false if not
function Test-ProcessRunning {
    param(
        [Parameter(Mandatory=$true)]
        [int]$ProcessId
    )

    try {
        $process = Get-Process -Id $ProcessId -ErrorAction SilentlyContinue
        return ($null -ne $process)
    }
    catch {
        return $false
    }
}

# Kill a process gracefully with timeout, then force
# Args: Process ID, Timeout in seconds (default: 5)
# Returns: $true if killed, $false if failed
function Stop-ProcessGraceful {
    param(
        [Parameter(Mandatory=$true)]
        [int]$ProcessId,

        [Parameter(Mandatory=$false)]
        [int]$TimeoutSeconds = 5
    )

    if (-not (Test-ProcessRunning -ProcessId $ProcessId)) {
        return $true
    }

    try {
        # Try graceful stop first
        Stop-Process -Id $ProcessId -ErrorAction SilentlyContinue

        # Wait for process to exit
        $elapsed = 0
        while ((Test-ProcessRunning -ProcessId $ProcessId) -and ($elapsed -lt $TimeoutSeconds)) {
            Start-Sleep -Seconds 1
            $elapsed++
        }

        # If still running, force kill
        if (Test-ProcessRunning -ProcessId $ProcessId) {
            Stop-Process -Id $ProcessId -Force -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 1
        }

        # Check if process is dead
        return -not (Test-ProcessRunning -ProcessId $ProcessId)
    }
    catch {
        return $false
    }
}

# Get process IDs by name pattern
# Args: Process name or pattern
# Returns: Array of process IDs
function Get-ProcessIdsByName {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Pattern
    )

    try {
        $processes = Get-Process | Where-Object {
            $_.ProcessName -match $Pattern -or $_.Path -match $Pattern
        }
        return $processes | Select-Object -ExpandProperty Id
    }
    catch {
        return @()
    }
}

# Create a lock file to prevent concurrent execution
# Args: Lock file path
# Returns: $true if lock acquired, $false if already locked
function New-LockFile {
    param(
        [Parameter(Mandatory=$true)]
        [string]$LockFilePath
    )

    # Check if lock file exists and process is still running
    if (Test-Path $LockFilePath) {
        try {
            $existingPid = Get-Content $LockFilePath -ErrorAction SilentlyContinue
            if ($existingPid -and (Test-ProcessRunning -ProcessId ([int]$existingPid))) {
                return $false
            }
        }
        catch {
            # Ignore errors, assume lock is stale
        }
    }

    # Create lock file with current PID
    try {
        $PID | Out-File -FilePath $LockFilePath -Encoding ASCII -Force
        return $true
    }
    catch {
        return $false
    }
}

# Release a lock file
# Args: Lock file path
function Remove-LockFile {
    param(
        [Parameter(Mandatory=$true)]
        [string]$LockFilePath
    )

    try {
        Remove-Item -Path $LockFilePath -Force -ErrorAction SilentlyContinue
    }
    catch {
        # Ignore errors
    }
}

# Set file permissions (Windows-specific using icacls)
# Args: File path, Permission type (Private=owner only, Public=everyone read)
function Set-FilePermissions {
    param(
        [Parameter(Mandatory=$true)]
        [string]$FilePath,

        [Parameter(Mandatory=$false)]
        [ValidateSet("Private", "Public")]
        [string]$PermissionType = "Private"
    )

    $os = Get-OperatingSystem

    if ($os -ne "Windows") {
        # On Unix, use chmod (if available)
        if (Get-Command chmod -ErrorAction SilentlyContinue) {
            switch ($PermissionType) {
                "Private" { & chmod 600 $FilePath 2>$null }
                "Public"  { & chmod 644 $FilePath 2>$null }
            }
        }
        return
    }

    # Windows: use icacls
    try {
        # Reset to default permissions
        & icacls $FilePath /reset 2>$null | Out-Null

        switch ($PermissionType) {
            "Private" {
                # Remove all permissions
                & icacls $FilePath /inheritance:r 2>$null | Out-Null
                # Grant owner full control
                & icacls $FilePath /grant "${env:USERNAME}:(F)" 2>$null | Out-Null
            }
            "Public" {
                # Grant everyone read
                & icacls $FilePath /grant "Everyone:(R)" 2>$null | Out-Null
            }
        }
    }
    catch {
        # Ignore errors
    }
}

# Make a file executable (cross-platform)
# Args: File path
function Set-Executable {
    param(
        [Parameter(Mandatory=$true)]
        [string]$FilePath
    )

    $os = Get-OperatingSystem

    if ($os -ne "Windows") {
        # On Unix, use chmod
        if (Get-Command chmod -ErrorAction SilentlyContinue) {
            & chmod +x $FilePath 2>$null
        }
    }
    # On Windows, files are executable by extension (.exe, .bat, .ps1, etc.)
}

# Get temporary directory (cross-platform)
function Get-TempDirectory {
    $os = Get-OperatingSystem

    switch ($os) {
        "Windows" {
            return $env:TEMP
        }
        default {
            if ($env:TMPDIR) {
                return $env:TMPDIR
            }
            else {
                return "/tmp"
            }
        }
    }
}

# Get user home directory (cross-platform)
function Get-HomeDirectory {
    if ($env:HOME) {
        return $env:HOME
    }
    elseif ($env:USERPROFILE) {
        return $env:USERPROFILE
    }
    else {
        return "~"
    }
}

# Escape string for safe use in shell commands
# Args: String to escape
# Returns: Escaped string
function ConvertTo-EscapedString {
    param(
        [Parameter(Mandatory=$true)]
        [string]$String
    )

    # Escape single quotes by doubling them
    return $String -replace "'", "''"
}

# Export functions (PowerShell equivalent of export -f)
Export-ModuleMember -Function @(
    'Get-OperatingSystem',
    'Test-IsWindows',
    'Test-IsUnix',
    'Test-IsWSL',
    'ConvertTo-NormalizedPath',
    'ConvertFrom-WSLPath',
    'ConvertTo-WSLPath',
    'Get-AbsolutePath',
    'Test-IsAbsolutePath',
    'Find-Command',
    'Test-ProcessRunning',
    'Stop-ProcessGraceful',
    'Get-ProcessIdsByName',
    'New-LockFile',
    'Remove-LockFile',
    'Set-FilePermissions',
    'Set-Executable',
    'Get-TempDirectory',
    'Get-HomeDirectory',
    'ConvertTo-EscapedString'
)
