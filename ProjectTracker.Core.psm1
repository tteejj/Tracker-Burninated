<#
.SYNOPSIS
    Shows an information box with a title and message.
.DESCRIPTION
    Displays a box with a title and message, using the specified type for styling.
.PARAMETER Title
    The title of the box.
.PARAMETER Message
    The message to display.
.PARAMETER Type
    The type of message (Info, Warning, Error, Success).
.EXAMPLE
    Show-InfoBox -Title "Operation Complete" -Message "All tasks were successfully processed." -Type Success
#>
function Show-InfoBox {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Title,
        
        [Parameter(Mandatory=$true)]
        [string]$Message,
        
        [Parameter(Mandatory=$false)]
        [ValidateSet("Info", "Warning", "Error", "Success")]
        [string]$Type = "Info"
    )
    
    # Ensure we have a current theme
    $theme = Get-CurrentTheme
    
    # Determine color based on type
    $color = switch ($Type) {
        "Warning" { $theme.Colors.Warning }
        "Error" { $theme.Colors.Error }
        "Success" { $theme.Colors.Success }
        default { $theme.Colors.Accent2 }
    }
    
    # Get console width
    $consoleWidth = Get-SafeConsoleWidth
    
    # Calculate box dimensions
    $boxWidth = [Math]::Min($consoleWidth - 4, 70)
    $contentWidth = $boxWidth - 4 # Accounting for borders and padding
    
    # Format message to fit within the box
    function Format-TextToWidth {
        param([string]$Text, [int]$Width)
        
        if ([string]::IsNullOrEmpty($Text)) { return @() }
        
        $words = $Text -split '\s+'
        $lines = @()
        $currentLine = ""
        
        foreach ($word in $words) {
            # If adding this word would exceed the width
            if ($currentLine.Length + $word.Length + 1 -gt $Width) {
                # Add current line to results if not empty
                if ($currentLine -ne "") {
                    $lines += $currentLine
                    $currentLine = ""
                }
                
                # Handle words longer than width by splitting them
                if ($word.Length -gt $Width) {
                    $remaining = $word
                    while ($remaining.Length -gt $Width) {
                        $lines += $remaining.Substring(0, $Width)
                        $remaining = $remaining.Substring($Width)
                    }
                    $currentLine = $remaining
                } else {
                    $currentLine = $word
                }
            } else {
                # Add word to current line with space if not first word
                if ($currentLine -ne "") {
                    $currentLine += " "
                }
                $currentLine += $word
            }
        }
        
        # Add final line if not empty
        if ($currentLine -ne "") {
            $lines += $currentLine
        }
        
        return $lines
    }
    
    $titleLines = Format-TextToWidth -Text $Title -Width $contentWidth
    $messageLines = Format-TextToWidth -Text $Message -Width $contentWidth
    
    # Determine box characters
    $hBorder = "-"
    $vBorder = "|"
    $cornerTL = "+"
    $cornerTR = "+"
    $cornerBL = "+"
    $cornerBR = "+"
    
    # Try to use theme border characters if available
    if ($theme.Table.ContainsKey("Chars")) {
        $borderChars = $theme.Table.Chars
        $hBorder = $borderChars.Horizontal
        $vBorder = $borderChars.Vertical
        $cornerTL = $borderChars.TopLeft
        $cornerTR = $borderChars.TopRight
        $cornerBL = $borderChars.BottomLeft
        $cornerBR = $borderChars.BottomRight
    }
    
    # Draw top border
    Write-ColorText "$cornerTL$($hBorder * ($boxWidth - 2))$cornerTR" -ForegroundColor $color
    
    # Draw title if provided
    if ($titleLines.Count -gt 0) {
        foreach ($line in $titleLines) {
            $padding = $contentWidth - $line.Length
            $leftPad = [Math]::Floor($padding / 2)
            $rightPad = $padding - $leftPad
            
            Write-ColorText "$vBorder " -ForegroundColor $color -NoNewline
            Write-ColorText "$(" " * $leftPad)$line$(" " * $rightPad)" -ForegroundColor $color -NoNewline
            Write-ColorText " $vBorder" -ForegroundColor $color
        }
        
        # Draw separator
        Write-ColorText "$vBorder$($hBorder * ($boxWidth - 2))$vBorder" -ForegroundColor $color
    }
    
    # Draw message
    foreach ($line in $messageLines) {
        Write-ColorText "$vBorder " -ForegroundColor $color -NoNewline
        Write-ColorText $line.PadRight($contentWidth) -ForegroundColor $color -NoNewline
        Write-ColorText " $vBorder" -ForegroundColor $color
    }
    
    # Draw bottom border
    Write-ColorText "$cornerBL$($hBorder * ($boxWidth - 2))$cornerBR" -ForegroundColor $color
}# ProjectTracker.Core.psm1
# Core functionality for Project Tracker application
# Includes configuration, error handling, logging, data access, and display functions

#region Module Variables

# Configuration
$script:configCache = $null

# Theme Engine
$script:currentTheme = $null
$script:colors = @{}
$script:useAnsiColors = $true
$script:availableThemesCache = $null
$script:stringLengthCache = @{}
$script:ansiEscapePattern = [regex]'\x1b\[[0-9;]*[mK]'

# ANSI color code mappings
$script:ansiForegroundColors = @{
    "Black" = "30"; "DarkRed" = "31"; "DarkGreen" = "32"; "DarkYellow" = "33";
    "DarkBlue" = "34"; "DarkMagenta" = "35"; "DarkCyan" = "36"; "Gray" = "37";
    "DarkGray" = "90"; "Red" = "91"; "Green" = "92"; "Yellow" = "93";
    "Blue" = "94"; "Magenta" = "95"; "Cyan" = "96"; "White" = "97"
}

$script:ansiBackgroundColors = @{
    "Black" = "40"; "DarkRed" = "41"; "DarkGreen" = "42"; "DarkYellow" = "43";
    "DarkBlue" = "44"; "DarkMagenta" = "45"; "DarkCyan" = "46"; "Gray" = "47";
    "DarkGray" = "100"; "Red" = "101"; "Green" = "102"; "Yellow" = "103";
    "Blue" = "104"; "Magenta" = "105"; "Cyan" = "106"; "White" = "107"
}

# Border character presets for themes
$script:borderPresets = @{
    # ASCII - for compatibility
    ASCII = @{
        Horizontal = "-"
        Vertical = "|"
        TopLeft = "+"
        TopRight = "+"
        BottomLeft = "+"
        BottomRight = "+"
        LeftJunction = "+"
        RightJunction = "+"
        TopJunction = "+"
        BottomJunction = "+"
        CrossJunction = "+"
    }

    # Light Box - standard Unicode box drawing
    LightBox = @{
        Horizontal = "─"
        Vertical = "│"
        TopLeft = "┌"
        TopRight = "┐"
        BottomLeft = "└"
        BottomRight = "┘"
        LeftJunction = "├"
        RightJunction = "┤"
        TopJunction = "┬"
        BottomJunction = "┴"
        CrossJunction = "┼"
    }

    # Heavy Box - bold lines
    HeavyBox = @{
        Horizontal = "━"
        Vertical = "┃"
        TopLeft = "┏"
        TopRight = "┓"
        BottomLeft = "┗"
        BottomRight = "┛"
        LeftJunction = "┣"
        RightJunction = "┫"
        TopJunction = "┳"
        BottomJunction = "┻"
        CrossJunction = "╋"
    }

    # Double Line - classic double borders
    DoubleLine = @{
        Horizontal = "═"
        Vertical = "║"
        TopLeft = "╔"
        TopRight = "╗"
        BottomLeft = "╚"
        BottomRight = "╝"
        LeftJunction = "╠"
        RightJunction = "╣"
        TopJunction = "╦"
        BottomJunction = "╩"
        CrossJunction = "╬"
    }

    # Rounded - softer corners
    Rounded = @{
        Horizontal = "─"
        Vertical = "│"
        TopLeft = "╭"
        TopRight = "╮"
        BottomLeft = "╰"
        BottomRight = "╯"
        LeftJunction = "├"
        RightJunction = "┤"
        TopJunction = "┬"
        BottomJunction = "┴"
        CrossJunction = "┼"
    }

    # Block - solid blocks
    Block = @{
        Horizontal = "█"
        Vertical = "█"
        TopLeft = "█"
        TopRight = "█"
        BottomLeft = "█"
        BottomRight = "█"
        LeftJunction = "█"
        RightJunction = "█"
        TopJunction = "█"
        BottomJunction = "█"
        CrossJunction = "█"
    }

    # Neon - for cyberpunk neon effect
    Neon = @{
        Horizontal = "─"
        Vertical = "│"
        TopLeft = "◢"
        TopRight = "◣"
        BottomLeft = "◥"
        BottomRight = "◤"
        LeftJunction = "├"
        RightJunction = "┤"
        TopJunction = "┬"
        BottomJunction = "┴"
        CrossJunction = "┼"
    }
}

# Header presets
$script:headerPresets = @{
    # Simple - basic box
    Simple = @{
        Style = "Simple"
        BorderChar = "="
        Corners = "++++"
    }

    # Double - double-line borders
    Double = @{
        Style = "Double"
        BorderChar = "═"
        Corners = "╔╗╚╝"
    }

    # Gradient - gradient top border
    Gradient = @{
        Style = "Gradient"
        BorderChar = "═"
        Corners = "╔╗╚╝"
        GradientChars = "█▓▒░"
    }

    # Minimal - minimal borders
    Minimal = @{
        Style = "Minimal"
        BorderChar = "─"
        Corners = "╭╮╰╯"
    }

    # Neon - cyberpunk neon effect
    Neon = @{
        Style = "Gradient"
        BorderChar = "═"
        Corners = "◢◣◥◤"
        GradientChars = "▒░  "
    }
}

# Default theme definition
$script:defaultTheme = @{
    Name = "Default"
    Description = "Default system theme"
    Author = "System"
    Version = "1.0"
    UseAnsiColors = $false
    Colors = @{
        Normal = "White"
        Header = "Cyan"
        Accent1 = "Yellow"
        Accent2 = "Cyan"
        Success = "Green"
        Warning = "Yellow"
        Error = "Red"
        Completed = "DarkGray"
        DueSoon = "Yellow"
        Overdue = "Red"
        TableBorder = "Gray"
    }
    Table = @{
        Chars = $script:borderPresets.ASCII.Clone()
        RowSeparator = $false
        CellPadding = 1
        HeaderStyle = "Normal"
    }
    Headers = $script:headerPresets.Simple.Clone()
    Menu = @{
        SelectedPrefix = ""
        UnselectedPrefix = ""
    }
    ProgressBar = @{
        FilledChar = "="
        EmptyChar = " "
        LeftCap = "["
        RightCap = "]"
    }
}

# Built-in themes
$script:themePresets = @{
    Default = $script:defaultTheme
    
    # RetroWave theme - magenta/cyan with black background
    RetroWave = @{
        Name = "RetroWave"
        Description = "Neon-inspired retro-wave cyberpunk theme with magenta and cyan"
        Author = "System"
        Version = "1.0"
        UseAnsiColors = $true
        Colors = @{
            Normal = "Cyan"
            Header = "Magenta"
            Accent1 = "Yellow"
            Accent2 = "Cyan"
            Success = "Green"
            Warning = "Yellow"
            Error = "Red"
            Completed = "DarkGray"
            DueSoon = "Yellow"
            Overdue = "Red"
            TableBorder = "Magenta"
        }
        Table = @{
            Chars = $script:borderPresets.HeavyBox.Clone()
            RowSeparator = $true
            CellPadding = 1
            HeaderStyle = "Bold"
        }
        Headers = $script:headerPresets.Gradient.Clone()
        Menu = @{
            SelectedPrefix = "►"
            UnselectedPrefix = " "
        }
        ProgressBar = @{
            FilledChar = "█"
            EmptyChar = "▒"
            LeftCap = "["
            RightCap = "]"
        }
    }
    
    # NeonCyberpunk theme
    NeonCyberpunk = @{
        Name = "NeonCyberpunk"
        Description = "Neon-inspired cyberpunk theme with bright colors and Unicode borders"
        Author = "System"
        Version = "1.0"
        UseAnsiColors = $true
        Colors = @{
            Normal = "Cyan"
            Header = "Magenta"
            Accent1 = "Yellow"
            Accent2 = "Cyan"
            Success = "Green"
            Warning = "Yellow"
            Error = "Red"
            Completed = "DarkGray"
            DueSoon = "Yellow"
            Overdue = "Red"
            TableBorder = "Magenta"
        }
        Table = @{
            Chars = $script:borderPresets.Neon.Clone()
            RowSeparator = $true
            CellPadding = 1
            HeaderStyle = "Bold"
        }
        Headers = $script:headerPresets.Neon.Clone()
        Menu = @{
            SelectedPrefix = "▶"
            UnselectedPrefix = " "
        }
        ProgressBar = @{
            FilledChar = "█"
            EmptyChar = "░"
            LeftCap = "【"
            RightCap = "】"
        }
    }
    
    # Matrix theme - green on black
    Matrix = @{
        Name = "Matrix"
        Description = "Green-on-black hacker aesthetic inspired by The Matrix"
        Author = "System"
        Version = "1.0"
        UseAnsiColors = $true
        Colors = @{
            Normal = "Green"
            Header = "Green"
            Accent1 = "DarkGreen"
            Accent2 = "Green"
            Success = "Green"
            Warning = "Yellow"
            Error = "Red"
            Completed = "DarkGreen"
            DueSoon = "Yellow"
            Overdue = "Red"
            TableBorder = "DarkGreen"
        }
        Table = @{
            Chars = @{ 
                Horizontal = "="
                Vertical = "|"
                TopLeft = "["
                TopRight = "]"
                BottomLeft = "["
                BottomRight = "]"
                LeftJunction = "|"
                RightJunction = "|"
                TopJunction = "="
                BottomJunction = "="
                CrossJunction = "+"
            }
            RowSeparator = $true
            CellPadding = 1
            HeaderStyle = "Normal"
        }
        Headers = @{
            Style = "Simple"
            BorderChar = "="
            Corners = "[][]"
        }
        Menu = @{
            SelectedPrefix = ">"
            UnselectedPrefix = " "
        }
        ProgressBar = @{
            FilledChar = "#"
            EmptyChar = "."
            LeftCap = "["
            RightCap = "]"
        }
    }
}

#endregion Module Variables

#region Configuration Functions

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

    # Return cached config if available
    if ($null -ne $script:configCache) {
        return $script:configCache
    }

    # Define default configuration
    $defaultConfig = @{
        # Core paths
        BaseDataDir = Join-Path $env:LOCALAPPDATA "ProjectTrackerData"
        ThemesDir = Join-Path $PSScriptRoot "..\themes"
        ProjectsFile = "projects.csv"
        TodosFile = "todolist.csv"
        TimeLogFile = "timetracking.csv"
        NotesFile = "notes.csv"
        CommandsFile = "commands.csv"
        LogFile = "project-tracker.log"
        
        # User settings
        LoggingEnabled = $true
        LogLevel = "INFO"  # DEBUG, INFO, WARNING, ERROR
        DefaultTheme = "Default"
        DisplayDateFormat = "MM/dd/yyyy"
        CalendarStartDay = [DayOfWeek]::Monday
        
        # Project settings
        DefaultProjectStatus = "Active"
        
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

    # Define required headers for each entity type
    $finalConfig.ProjectsHeaders = @(
        "FullProjectName", "Nickname", "ID1", "ID2", "DateAssigned",
        "DueDate", "BFDate", "CumulativeHrs", "Note", "ProjFolder",
        "ClosedDate", "Status"
    )
    
    $finalConfig.TodosHeaders = @(
        "ID", "Nickname", "TaskDescription", "Importance", "DueDate", 
        "Status", "CreatedDate", "CompletedDate"
    )
    
    $finalConfig.TimeHeaders = @(
        "EntryID", "Date", "WeekStartDate", "Nickname", "ID1", "ID2",
        "Description", "MonHours", "TueHours", "WedHours", "ThuHours", 
        "FriHours", "SatHours", "SunHours", "TotalHours"
    )
    
    $finalConfig.NotesHeaders = @(
        "NoteID", "Nickname", "DateCreated", "Title", "Content", "Tags"
    )
    
    $finalConfig.CommandsHeaders = @(
        "CommandID", "Name", "Description", "CommandText", "DateCreated", "Tags"
    )

    # Cache the configuration
    $script:configCache = $finalConfig

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
        
        # Update cache
        $script:configCache = $Config
        
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

#endregion Configuration Functions

#region Error Handling Functions

<#
.SYNOPSIS
    Handles errors consistently throughout the application.
.DESCRIPTION
    Centralizes error handling by providing logging, user feedback, and
    optionally terminating execution. Integrates with the logging system
    when available.
.PARAMETER ErrorRecord
    The PowerShell error record object.
.PARAMETER Context
    A string describing the operation that generated the error.
.PARAMETER Continue
    If specified, execution will continue after handling the error.
    Otherwise, the function will terminate execution.
.PARAMETER Silent
    If specified, no console output will be generated.
.EXAMPLE
    try {
        # Some operation that may fail
    } catch {
        Handle-Error -ErrorRecord $_ -Context "Reading data file" -Continue
    }
.EXAMPLE
    try {
        # Critical operation
    } catch {
        Handle-Error -ErrorRecord $_ -Context "Database initialization"
        # Will not reach this point as the function will terminate execution
    }
#>
function Handle-Error {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [System.Management.Automation.ErrorRecord]$ErrorRecord,
        
        [Parameter(Mandatory=$false)]
        [string]$Context = "Operation",
        
        [Parameter(Mandatory=$false)]
        [switch]$Continue,
        
        [Parameter(Mandatory=$false)]
        [switch]$Silent
    )
    
    # Extract error information
    $exception = $ErrorRecord.Exception
    $message = $exception.Message
    $scriptStackTrace = $ErrorRecord.ScriptStackTrace
    $errorCategory = $ErrorRecord.CategoryInfo.Category
    $errorId = $ErrorRecord.FullyQualifiedErrorId
    $position = $ErrorRecord.InvocationInfo.PositionMessage
    
    # Build detailed error message
    $detailedMessage = @"
Error in $Context
Message: $message
Category: $errorCategory
Error ID: $errorId
Position: $position
Stack Trace:
$scriptStackTrace
"@
    
    # Log error if logging is available
    try {
        Write-AppLog -Message "ERROR in $Context - $message" -Level ERROR
        Write-AppLog -Message $detailedMessage -Level DEBUG
    } catch {
        # Fallback if logging fails
        Write-Warning "Failed to log error: $($_.Exception.Message)"
    }
    
    # Display error to console unless silent
    if (-not $Silent) {
        # Use themed output if available
        try {
            if ($script:currentTheme) {
                Show-InfoBox -Title "Error in $Context" -Message $message -Type Error
            } else {
                # Fallback if theme isn't initialized
                Write-Host "ERROR in $Context - $message" -ForegroundColor Red
            }
        } catch {
            # Fallback if themed output fails
            Write-Host "ERROR in $Context - $message" -ForegroundColor Red
            
            # Show detailed information in debug scenarios
            if ($VerbosePreference -eq 'Continue' -or $DebugPreference -eq 'Continue') {
                Write-Host $detailedMessage -ForegroundColor DarkGray
            }
        }
    }
    
    # Terminate execution unless Continue is specified
    if (-not $Continue) {
        # Use throw to preserve the original error
        throw $ErrorRecord
    }
}

<#
.SYNOPSIS
    Runs a script block with try/catch and standard error handling.
.DESCRIPTION
    Executes the provided script block in a try/catch block,
    handling any errors using Handle-Error. Simplifies error handling
    for common operations.
.PARAMETER ScriptBlock
    The script block to execute.
.PARAMETER ErrorContext
    A string describing the operation for error context.
.PARAMETER Continue
    If specified, execution will continue after handling any error.
.PARAMETER Silent
    If specified, no console output will be generated for errors.
.PARAMETER DefaultValue
    The value to return if an error occurs and Continue is specified.
.EXAMPLE
    $result = Invoke-WithErrorHandling -ScriptBlock { Get-Content -Path $filePath } -ErrorContext "Reading data file" -Continue -DefaultValue @()
.OUTPUTS
    Returns the output of the script block or the DefaultValue if an error occurs.
#>
function Invoke-WithErrorHandling {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [scriptblock]$ScriptBlock,
        
        [Parameter(Mandatory=$false)]
        [string]$ErrorContext = "Operation",
        
        [Parameter(Mandatory=$false)]
        [switch]$Continue,
        
        [Parameter(Mandatory=$false)]
        [switch]$Silent,
        
        [Parameter(Mandatory=$false)]
        [object]$DefaultValue = $null
    )
    
    try {
        # Execute the script block
        return & $ScriptBlock
    } catch {
        # Handle the error
        Handle-Error -ErrorRecord $_ -Context $ErrorContext -Continue:$Continue -Silent:$Silent
        
        # If Continue is specified, return the default value
        if ($Continue) {
            return $DefaultValue
        }
        
        # This point is only reached if Continue is specified and Handle-Error doesn't terminate
    }
}

#endregion Error Handling Functions

#region Logging Functions

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
        try {
            $config = Get-AppConfig
        } catch {
            # Create default config if Get-AppConfig fails
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
