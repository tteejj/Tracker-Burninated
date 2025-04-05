# lib/config.ps1
# Configuration Management for Project Tracker
# Handles loading, saving, and accessing application configuration

<#
.SYNOPSIS
    Gets the application configuration, merging defaults with user settings.
.DESCRIPTION
    Loads configuration from the config file if it exists, otherwise uses defaults.
    Ensures all expected keys exist by merging with default configuration.
    Calculates and adds derived paths based on configuration values.
.PARAMETER ConfigFile
    Optional path to a specific config file. If not specified, uses the default location.
.EXAMPLE
    $config = Get-AppConfig
    $baseDataDir = $config.BaseDataDir
.OUTPUTS
    System.Collections.Hashtable - The complete configuration hashtable
#>
function Get-AppConfig {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)]
        [string]$ConfigFile = $null
    )

    # Define default configuration
    $defaultConfig = @{
        # Core paths
        BaseDataDir = Join-Path $env:LOCALAPPDATA "ProjectTrackerData"
        ThemesDir = Join-Path $PSScriptRoot "..\themes"
        ProjectsFile = "projects.csv"
        TodosFile = "todolist.csv"
        TimeLogFile = "timelog.csv"
        NotesFile = "notes.csv"
        CommandsFile = "commands.csv"
        LogFile = "project-tracker.log"
        
        # User settings
        LoggingEnabled = $true
        LogLevel = "INFO"  # DEBUG, INFO, WARNING, ERROR
        DefaultTheme = "Default"
        DisplayDateFormat = "MM/dd/yyyy"
        CalendarStartDay = [DayOfWeek]::Monday
        
        # Table display options
        TableOptions = @{
            # Fixed column widths
            FixedWidths = @{
                ID = 5
                Nickname = 15
                Task = 40
                TaskDescription = 40
                Note = 30
                Priority = 10
                Status = 10
                Date = 12
                Assigned = 12
                Due = 12
                BFDate = 12
                CreatedDate = 12
                Hrs = 8
                Mon = 7
                Tue = 7
                Wed = 7
                Thu = 7
                Fri = 7
                Total = 9
                FullProjectName = 30
                ClosedDate = 12
            }
            
            # Column alignments
            Alignments = @{
                ID = "Right"
                Hrs = "Right"
                CumulativeHrs = "Right"
                Mon = "Right"
                Tue = "Right"
                Wed = "Right"
                Thu = "Right"
                Fri = "Right"
                Total = "Right"
                DateAssigned = "Right"
                DueDate = "Right"
                BFDate = "Right"
                CreatedDate = "Right"
                Date = "Right"
                ClosedDate = "Right"
            }
        }
    }

    # Determine config file path if not provided
    if (-not $ConfigFile) {
        $ConfigFile = Join-Path $defaultConfig.BaseDataDir "config.json"
    }

    # Load user configuration if exists
    $userConfig = @{}
    if (Test-Path $ConfigFile) {
        try {
            $userConfig = Get-Content -Path $ConfigFile -Raw | ConvertFrom-Json -AsHashtable -ErrorAction Stop
        } catch {
            # Handle error loading config - log will come later
            Write-Warning "Failed to load configuration from $ConfigFile. Using defaults. Error: $($_.Exception.Message)"
            # We'll continue with default config
        }
    }

    # Merge configurations (user settings override defaults)
    $finalConfig = Merge-Hashtables -BaseTable $defaultConfig -OverrideTable $userConfig

    # Calculate and add full paths
    $finalConfig.ProjectsFullPath = Join-Path $finalConfig.BaseDataDir $finalConfig.ProjectsFile
    $finalConfig.TodosFullPath = Join-Path $finalConfig.BaseDataDir $finalConfig.TodosFile
    $finalConfig.TimeLogFullPath = Join-Path $finalConfig.BaseDataDir $finalConfig.TimeLogFile
    $finalConfig.NotesFullPath = Join-Path $finalConfig.BaseDataDir $finalConfig.NotesFile
    $finalConfig.CommandsFullPath = Join-Path $finalConfig.BaseDataDir $finalConfig.CommandsFile
    $finalConfig.LogFullPath = Join-Path $finalConfig.BaseDataDir $finalConfig.LogFile

    return $finalConfig
}

<#
.SYNOPSIS
    Saves the application configuration to a JSON file.
.DESCRIPTION
    Saves the provided configuration hashtable to the specified file in JSON format.
    Creates the directory if it doesn't exist.
.PARAMETER Config
    The configuration hashtable to save.
.PARAMETER ConfigFile
    Optional path to save the config file. If not specified, uses the path from Config.
.EXAMPLE
    $success = Save-AppConfig -Config $configObject
.OUTPUTS
    System.Boolean - True if saved successfully, False otherwise
#>
function Save-AppConfig {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [hashtable]$Config,
        
        [Parameter(Mandatory=$false)]
        [string]$ConfigFile = $null
    )

    # Determine config file path
    if (-not $ConfigFile) {
        $ConfigFile = Join-Path $Config.BaseDataDir "config.json"
    }

    # Ensure directory exists
    $configDir = Split-Path -Parent $ConfigFile
    if (-not (Test-Path $configDir -PathType Container)) {
        try {
            New-Item -Path $configDir -ItemType Directory -Force | Out-Null
        } catch {
            Write-Warning "Failed to create directory for config file: $($_.Exception.Message)"
            return $false
        }
    }

    # Save configuration
    try {
        $Config | ConvertTo-Json -Depth 5 | Out-File -FilePath $ConfigFile -Encoding utf8 -Force
        return $true
    } catch {
        Write-Warning "Failed to save configuration to $ConfigFile. Error: $($_.Exception.Message)"
        return $false
    }
}

<#
.SYNOPSIS
    Recursively merges two hashtables, with the override hashtable taking precedence.
.DESCRIPTION
    Creates a new hashtable by combining the base hashtable with the override hashtable.
    If a key exists in both, the override value is used.
    If a key in both has hashtable values, they are recursively merged.
.PARAMETER BaseTable
    The base hashtable containing default values.
.PARAMETER OverrideTable
    The override hashtable containing values that should take precedence.
.EXAMPLE
    $mergedHashtable = Merge-Hashtables -BaseTable $defaults -OverrideTable $userSettings
.OUTPUTS
    System.Collections.Hashtable - The merged hashtable
#>
function Merge-Hashtables {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [hashtable]$BaseTable,
        
        [Parameter(Mandatory=$true)]
        [hashtable]$OverrideTable
    )

    # Create a new hashtable for the result
    $result = @{}

    # Copy all keys from base table
    foreach ($key in $BaseTable.Keys) {
        $result[$key] = $BaseTable[$key]
    }

    # Override or add keys from override table
    foreach ($key in $OverrideTable.Keys) {
        # If both tables have the key and both values are hashtables, recursively merge
        if ($result.ContainsKey($key) -and $result[$key] -is [hashtable] -and $OverrideTable[$key] -is [hashtable]) {
            $result[$key] = Merge-Hashtables -BaseTable $result[$key] -OverrideTable $OverrideTable[$key]
        } else {
            # Otherwise, use the override value
            $result[$key] = $OverrideTable[$key]
        }
    }

    return $result
}

# Export only the functions we want to be publicly accessible
Export-ModuleMember -Function Get-AppConfig, Save-AppConfig
