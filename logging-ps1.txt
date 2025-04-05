# lib/logging.ps1
# Simple Logging System for Project Tracker
# Provides standardized application logging

<#
.SYNOPSIS
    Writes a log entry to the application log file.
.DESCRIPTION
    Appends a timestamped, formatted log entry to the application log file.
    Handles log rotation, file locking, and respects log level configuration.
.PARAMETER Message
    The message to log.
.PARAMETER Level
    The log level (DEBUG, INFO, WARNING, ERROR). Default is INFO.
.PARAMETER ConfigObject
    Optional configuration object. If not provided, will load using Get-AppConfig.
.EXAMPLE
    Write-AppLog -Message "Processing started" -Level INFO
.EXAMPLE
    Write-AppLog -Message "User input validation failed" -Level WARNING
#>
function Write-AppLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message,
        
        [Parameter(Mandatory=$false)]
        [ValidateSet("DEBUG", "INFO", "WARNING", "ERROR")]
        [string]$Level = "INFO",
        
        [Parameter(Mandatory=$false)]
        [hashtable]$ConfigObject = $null
    )
    
    # Define log level priorities (for filtering)
    $levelPriorities = @{
        "DEBUG" = 0
        "INFO" = 1
        "WARNING" = 2
        "ERROR" = 3
    }
    
    # Get configuration if not provided
    $config = $ConfigObject
    if ($null -eq $config) {
        # Check if Get-AppConfig exists and use it
        if (Get-Command "Get-AppConfig" -ErrorAction SilentlyContinue) {
            try {
                $config = Get-AppConfig
            } catch {
                # Fallback to simple console output if config can't be loaded
                Write-Warning "Failed to load configuration for logging. Using defaults."
                $config = @{
                    LoggingEnabled = $true
                    LogLevel = "INFO"
                    LogFullPath = Join-Path $env:TEMP "project-tracker.log"
                }
            }
        } else {
            # Create default config if Get-AppConfig is not available
            $config = @{
                LoggingEnabled = $true
                LogLevel = "INFO"
                LogFullPath = Join-Path $env:TEMP "project-tracker.log"
            }
        }
    }
    
    # Check if logging is enabled
    if (-not $config.LoggingEnabled) {
        return
    }
    
    # Check log level priority
    $configLevelPriority = $levelPriorities[$config.LogLevel]
    $currentLevelPriority = $levelPriorities[$Level]
    
    if ($currentLevelPriority -lt $configLevelPriority) {
        # Skip logging if level is below configured threshold
        return
    }
    
    # Prepare log entry
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "[$timestamp] [$Level] $Message"
    
    # Ensure log directory exists
    $logDir = Split-Path -Parent $config.LogFullPath
    if (-not (Test-Path $logDir -PathType Container)) {
        try {
            New-Item -Path $logDir -ItemType Directory -Force | Out-Null
        } catch {
            # Can't create directory - fallback to console only
            Write-Warning "Failed to create log directory: $($_.Exception.Message)"
            Write-Host $logEntry
            return
        }
    }
    
    # Simple log rotation - if file exceeds 5MB, rename it with timestamp
    if (Test-Path $config.LogFullPath) {
        try {
            $logFile = Get-Item $config.LogFullPath
            
            # Check file size (5MB = 5242880 bytes)
            if ($logFile.Length -gt 5242880) {
                $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
                $backupName = [System.IO.Path]::ChangeExtension($config.LogFullPath, "$timestamp.log")
                
                # Rename the existing log file
                Rename-Item -Path $config.LogFullPath -NewName $backupName -Force
            }
        } catch {
            # If rotation fails, continue anyway but warn
            Write-Warning "Log rotation failed: $($_.Exception.Message)"
        }
    }
    
    # Write to log file with retries for file locking issues
    $maxRetries = 3
    $retryDelay = 100  # milliseconds
    $success = $false
    
    for ($retry = 0; $retry -lt $maxRetries -and -not $success; $retry++) {
        try {
            # Append to the log file
            Add-Content -Path $config.LogFullPath -Value $logEntry -Encoding UTF8 -Force
            $success = $true
        } catch {
            if ($retry -eq $maxRetries - 1) {
                # Log to console as fallback on final retry
                Write-Warning "Failed to write to log file after $maxRetries retries: $($_.Exception.Message)"
                Write-Host $logEntry
            } else {
                # Wait before retrying
                Start-Sleep -Milliseconds $retryDelay
            }
        }
    }
}

<#
.SYNOPSIS
    Rotates log files if they exceed a specified size.
.DESCRIPTION
    Checks the size of the specified log file and renames it with a timestamp
    if it exceeds the maximum size. Used for manual log rotation.
.PARAMETER LogFilePath
    The path to the log file to check.
.PARAMETER MaxSizeBytes
    The maximum size in bytes before rotation. Default is 5MB.
.EXAMPLE
    Rotate-LogFile -LogFilePath "C:\logs\app.log" -MaxSizeBytes 10485760
.OUTPUTS
    System.Boolean - True if rotation occurred, False otherwise
#>
function Rotate-LogFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$LogFilePath,
        
        [Parameter(Mandatory=$false)]
        [int]$MaxSizeBytes = 5242880  # 5MB default
    )
    
    # Check if file exists
    if (-not (Test-Path $LogFilePath)) {
        Write-Verbose "Log file does not exist: $LogFilePath"
        return $false
    }
    
    try {
        $logFile = Get-Item $LogFilePath
        
        # Check file size
        if ($logFile.Length -gt $MaxSizeBytes) {
            $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
            $backupName = [System.IO.Path]::ChangeExtension($LogFilePath, "$timestamp.log")
            
            # Rename the existing log file
            Rename-Item -Path $LogFilePath -NewName $backupName -Force
            Write-Verbose "Rotated log file: $LogFilePath -> $backupName"
            return $true
        }
    } catch {
        Write-Warning "Log rotation failed: $($_.Exception.Message)"
    }
    
    return $false
}

<#
.SYNOPSIS
    Gets the content of the application log file.
.DESCRIPTION
    Reads and returns the content of the application log file.
    Useful for viewing logs within the application.
.PARAMETER ConfigObject
    Optional configuration object. If not provided, will load using Get-AppConfig.
.PARAMETER Lines
    The number of lines to return. Default is 50 (most recent lines).
.PARAMETER Filter
    Optional filter string to match against log entries.
.PARAMETER Level
    Optional log level filter.
.EXAMPLE
    Get-AppLogContent -Lines 100
.EXAMPLE
    Get-AppLogContent -Filter "error connecting to" -Level ERROR
.OUTPUTS
    System.String[] - The log file content
#>
function Get-AppLogContent {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)]
        [hashtable]$ConfigObject = $null,
        
        [Parameter(Mandatory=$false)]
        [int]$Lines = 50,
        
        [Parameter(Mandatory=$false)]
        [string]$Filter = "",
        
        [Parameter(Mandatory=$false)]
        [ValidateSet("", "DEBUG", "INFO", "WARNING", "ERROR")]
        [string]$Level = ""
    )
    
    # Get configuration if not provided
    $config = $ConfigObject
    if ($null -eq $config) {
        # Check if Get-AppConfig exists and use it
        if (Get-Command "Get-AppConfig" -ErrorAction SilentlyContinue) {
            try {
                $config = Get-AppConfig
            } catch {
                # Create default config if Get-AppConfig fails
                $config = @{
                    LogFullPath = Join-Path $env:TEMP "project-tracker.log"
                }
            }
        } else {
            # Create default config if Get-AppConfig is not available
            $config = @{
                LogFullPath = Join-Path $env:TEMP "project-tracker.log"
            }
        }
    }
    
    # Check if log file exists
    if (-not (Test-Path $config.LogFullPath)) {
        return @("Log file not found: $($config.LogFullPath)")
    }
    
    try {
        # Get log content
        $content = Get-Content -Path $config.LogFullPath -Tail $Lines
        
        # Apply filters if specified
        if (-not [string]::IsNullOrEmpty($Filter)) {
            $content = $content | Where-Object { $_ -match $Filter }
        }
        
        if (-not [string]::IsNullOrEmpty($Level)) {
            $content = $content | Where-Object { $_ -match "\[$Level\]" }
        }
        
        return $content
    } catch {
        return @("Error reading log file: $($_.Exception.Message)")
    }
}

# Export the functions for use in other modules
Export-ModuleMember -Function Write-AppLog, Rotate-LogFile, Get-AppLogContent
