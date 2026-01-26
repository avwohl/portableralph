# process-mgmt.ps1 - Windows process management utilities for PortableRalph
# Provides Windows equivalents for nohup, kill, ps, pgrep
#
# Usage:
#   . .\lib\process-mgmt.ps1
#   Start-BackgroundProcess -Command "claude.exe" -Arguments "--version"
#   Stop-ProcessByPattern -Pattern "claude"

# Start a process in the background (equivalent to nohup)
# Args: Command to run, Arguments, Output file path (optional), Working directory (optional)
# Returns: Process object
function Start-BackgroundProcess {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Command,

        [Parameter(Mandatory=$false)]
        [string[]]$Arguments = @(),

        [Parameter(Mandatory=$false)]
        [string]$OutputPath = $null,

        [Parameter(Mandatory=$false)]
        [string]$WorkingDirectory = $null,

        [Parameter(Mandatory=$false)]
        [switch]$NoWindow
    )

    # Prepare process start info
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $Command
    $psi.Arguments = $Arguments -join ' '
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $NoWindow.IsPresent

    # Set working directory if specified
    if ($WorkingDirectory) {
        $psi.WorkingDirectory = $WorkingDirectory
    }

    # Redirect output if specified
    if ($OutputPath) {
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError = $true
    }

    # Start the process
    try {
        $process = New-Object System.Diagnostics.Process
        $process.StartInfo = $psi

        # Set up output redirection if needed
        if ($OutputPath) {
            $outputWriter = [System.IO.StreamWriter]::new($OutputPath, $true)

            # Register output handlers
            $process.add_OutputDataReceived({
                param($sender, $e)
                if ($e.Data) {
                    $outputWriter.WriteLine($e.Data)
                    $outputWriter.Flush()
                }
            })

            $process.add_ErrorDataReceived({
                param($sender, $e)
                if ($e.Data) {
                    $outputWriter.WriteLine("ERROR: $($e.Data)")
                    $outputWriter.Flush()
                }
            })
        }

        $process.Start() | Out-Null

        # Begin async output reading if redirecting
        if ($OutputPath) {
            $process.BeginOutputReadLine()
            $process.BeginErrorReadLine()
        }

        return $process
    }
    catch {
        Write-Error "Failed to start background process: $_"
        return $null
    }
}

# Stop a process gracefully (equivalent to kill)
# Args: Process ID or Process object, Force flag, Timeout in seconds
# Returns: $true if stopped successfully
function Stop-ProcessSafe {
    param(
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        $Process,

        [Parameter(Mandatory=$false)]
        [switch]$Force,

        [Parameter(Mandatory=$false)]
        [int]$TimeoutSeconds = 5
    )

    # Convert to process ID if needed
    $pid = if ($Process -is [int]) {
        $Process
    } elseif ($Process -is [System.Diagnostics.Process]) {
        $Process.Id
    } else {
        Write-Error "Invalid process parameter type"
        return $false
    }

    # Check if process exists
    try {
        $proc = Get-Process -Id $pid -ErrorAction Stop
    }
    catch {
        # Process doesn't exist, consider it stopped
        return $true
    }

    # Try graceful stop first (unless Force is specified)
    if (-not $Force) {
        try {
            $proc.CloseMainWindow() | Out-Null

            # Wait for process to exit
            $exited = $proc.WaitForExit($TimeoutSeconds * 1000)
            if ($exited) {
                return $true
            }
        }
        catch {
            # Graceful stop failed, will try force kill
        }
    }

    # Force kill
    try {
        Stop-Process -Id $pid -Force -ErrorAction Stop
        return $true
    }
    catch {
        Write-Error "Failed to stop process $pid: $_"
        return $false
    }
}

# List processes with details (equivalent to ps)
# Args: Process name pattern (optional), Include details flag
# Returns: Array of process objects
function Get-ProcessList {
    param(
        [Parameter(Mandatory=$false)]
        [string]$Pattern = "*",

        [Parameter(Mandatory=$false)]
        [switch]$Detailed
    )

    $processes = Get-Process -Name $Pattern -ErrorAction SilentlyContinue

    if ($Detailed) {
        return $processes | Select-Object Id, ProcessName, CPU, WorkingSet64, StartTime, Path
    }
    else {
        return $processes | Select-Object Id, ProcessName, CPU, WorkingSet64
    }
}

# Find processes by name or command pattern (equivalent to pgrep)
# Args: Pattern to match against process name or path
# Returns: Array of process IDs
function Find-ProcessByPattern {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Pattern,

        [Parameter(Mandatory=$false)]
        [switch]$FullPath
    )

    try {
        $processes = Get-Process | Where-Object {
            if ($FullPath) {
                # Match against full path
                $_.Path -match $Pattern
            }
            else {
                # Match against process name
                $_.ProcessName -match $Pattern
            }
        }

        return $processes | Select-Object -ExpandProperty Id
    }
    catch {
        return @()
    }
}

# Stop all processes matching a pattern (equivalent to pkill)
# Args: Pattern to match, Force flag
# Returns: Number of processes stopped
function Stop-ProcessByPattern {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Pattern,

        [Parameter(Mandatory=$false)]
        [switch]$Force,

        [Parameter(Mandatory=$false)]
        [switch]$FullPath
    )

    $pids = Find-ProcessByPattern -Pattern $Pattern -FullPath:$FullPath
    $count = 0

    foreach ($pid in $pids) {
        if (Stop-ProcessSafe -Process $pid -Force:$Force) {
            $count++
        }
    }

    return $count
}

# Check if a process is running
# Args: Process ID
# Returns: $true if running, $false otherwise
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

# Get process information (equivalent to ps -p <pid>)
# Args: Process ID
# Returns: Process object with details
function Get-ProcessInfo {
    param(
        [Parameter(Mandatory=$true)]
        [int]$ProcessId
    )

    try {
        $process = Get-Process -Id $ProcessId -ErrorAction Stop
        return $process | Select-Object Id, ProcessName, CPU, WorkingSet64, StartTime, Path, CommandLine
    }
    catch {
        return $null
    }
}

# Wait for a process to exit (equivalent to wait)
# Args: Process ID, Timeout in seconds (optional)
# Returns: $true if exited, $false if timeout
function Wait-ProcessExit {
    param(
        [Parameter(Mandatory=$true)]
        [int]$ProcessId,

        [Parameter(Mandatory=$false)]
        [int]$TimeoutSeconds = 0
    )

    try {
        $process = Get-Process -Id $ProcessId -ErrorAction Stop

        if ($TimeoutSeconds -gt 0) {
            $exited = $process.WaitForExit($TimeoutSeconds * 1000)
            return $exited
        }
        else {
            $process.WaitForExit()
            return $true
        }
    }
    catch {
        # Process doesn't exist
        return $true
    }
}

# Start a process and detach (like nohup &)
# Args: Command, Arguments, Log file path
# Returns: Process ID
function Start-DetachedProcess {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Command,

        [Parameter(Mandatory=$false)]
        [string[]]$Arguments = @(),

        [Parameter(Mandatory=$false)]
        [string]$LogFile = $null,

        [Parameter(Mandatory=$false)]
        [string]$WorkingDirectory = $null
    )

    # If no log file specified, use NUL
    if (-not $LogFile) {
        $LogFile = "NUL"
    }

    # Use Windows Task Scheduler for true detachment
    # Or simply start the process without waiting
    $process = Start-BackgroundProcess -Command $Command -Arguments $Arguments -OutputPath $LogFile -WorkingDirectory $WorkingDirectory -NoWindow

    if ($process) {
        return $process.Id
    }
    else {
        return $null
    }
}

# Export functions
Export-ModuleMember -Function @(
    'Start-BackgroundProcess',
    'Stop-ProcessSafe',
    'Get-ProcessList',
    'Find-ProcessByPattern',
    'Stop-ProcessByPattern',
    'Test-ProcessRunning',
    'Get-ProcessInfo',
    'Wait-ProcessExit',
    'Start-DetachedProcess'
)
