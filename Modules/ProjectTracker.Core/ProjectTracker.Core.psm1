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
# Private helper function to safely get console width
function Get-SafeConsoleWidth {
    try {
        # Check if running interactively and Host supports RawUI
        if ($Host.UI.RawUI -ne $null -and $Host.Name -ne 'Windows PowerShell ISE Host' -and $Host.Name -ne 'Visual Studio Code Host') {
             # Use BufferWidth for potentially wider content than window width
            $width = $Host.UI.RawUI.BufferSize.Width
            # Fallback to WindowWidth if BufferWidth is zero or unreasonably small
            if ($width -le 10) {
                $width = $Host.UI.RawUI.WindowSize.Width
            }
            # Ensure a minimum width
            return [Math]::Max(20, $width)
        } else {
            # Fallback for non-interactive or incompatible hosts (e.g., ISE, some VSCode terminals)
            # Return a reasonable default width
            return 80
        }
    } catch {
        # Catch any errors accessing host properties
        Write-Warning "Could not determine console width. Using default 80. Error: $($_.Exception.Message)"
        return 80
    }
}


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
}

# ProjectTracker.Core.psm1
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

    # Heavy Box - bold lines
    HeavyBox = @{
        Horizontal = "="
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

    # Double Line - classic double borders
    DoubleLine = @{
        Horizontal = "="
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

    # Rounded - softer corners
    Rounded = @{
        Horizontal = "-"
        Vertical = "|"
        TopLeft = "/"
        TopRight = "\\"
        BottomLeft = "\\"
        BottomRight = "/"
        LeftJunction = "+"
        RightJunction = "+"
        TopJunction = "+"
        BottomJunction = "+"
        CrossJunction = "+"
    }

    # Block - solid blocks
    Block = @{
        Horizontal = "#"
        Vertical = "#"
        TopLeft = "#"
        TopRight = "#"
        BottomLeft = "#"
        BottomRight = "#"
        LeftJunction = "#"
        RightJunction = "#"
        TopJunction = "#"
        BottomJunction = "#"
        CrossJunction = "#"
    }

    # Neon - for cyberpunk neon effect
    Neon = @{
        Horizontal = "-"
        Vertical = "|"
        TopLeft = "/"
        TopRight = "\\"
        BottomLeft = "\\"
        BottomRight = "/"
        LeftJunction = "+"
        RightJunction = "+"
        TopJunction = "+"
        BottomJunction = "+"
        CrossJunction = "+"
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
        BorderChar = "="
        Corners = "++++"
    }

    # Gradient - gradient top border
    Gradient = @{
        Style = "Gradient"
        BorderChar = "="
        Corners = "++++"
        GradientChars = "#:. "
    }

    # Minimal - minimal borders
    Minimal = @{
        Style = "Minimal"
        BorderChar = "-"
        Corners = "/\\\/"
    }

    # Neon - cyberpunk neon effect
    Neon = @{
        Style = "Gradient"
        BorderChar = "="
        Corners = "/\\\/"
        GradientChars = ".:  "
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


##Start of missing content

# Missing functions for ProjectTracker.Core.psm1

<#
.SYNOPSIS
    Initializes the data environment.
.DESCRIPTION
    Creates necessary directories and ensures data files exist with required headers.
.EXAMPLE
    Initialize-DataEnvironment
.OUTPUTS
    Boolean indicating success
#>
function Initialize-DataEnvironment {
    [CmdletBinding()]
    param()
    
    Write-Verbose "Initializing data environment..."
    
    try {
        $config = Get-AppConfig
        
        # Ensure base directory exists
        if (-not (Ensure-DirectoryExists -Path $config.BaseDataDir)) {
            Write-AppLog "Failed to create base data directory: $($config.BaseDataDir)" -Level ERROR
            return $false
        }
        
        # Ensure themes directory exists
        if (-not (Ensure-DirectoryExists -Path $config.ThemesDir)) {
            Write-AppLog "Failed to create themes directory: $($config.ThemesDir)" -Level ERROR
            return $false
        }
        
        # Initialize data files with headers
        $dataFiles = @(
            @{ Path = $config.ProjectsFullPath; Headers = $config.ProjectsHeaders },
            @{ Path = $config.TodosFullPath; Headers = $config.TodosHeaders },
            @{ Path = $config.TimeLogFullPath; Headers = $config.TimeHeaders },
            @{ Path = $config.NotesFullPath; Headers = $config.NotesHeaders },
            @{ Path = $config.CommandsFullPath; Headers = $config.CommandsHeaders }
        )
        
        foreach ($file in $dataFiles) {
            if (-not (Test-Path -Path $file.Path)) {
                # Create file with headers
                $file.Headers -join "," | Out-File -FilePath $file.Path -Encoding utf8
                Write-Verbose "Created data file: $($file.Path)"
            }
        }
        
        Write-AppLog "Data environment initialization complete" -Level INFO
        return $true
    } catch {
        Handle-Error -ErrorRecord $_ -Context "Data environment initialization" -Continue
        return $false
    }
}

<#
.SYNOPSIS
    Initializes the theme engine.
.DESCRIPTION
    Sets up the theme engine, loads the configured theme, and initializes
    theming variables.
.EXAMPLE
    Initialize-ThemeEngine
.OUTPUTS
    Boolean indicating success
#>
function Initialize-ThemeEngine {
    [CmdletBinding()]
    param()
    
    Write-Verbose "Initializing theme engine..."
    
    try {
        $config = Get-AppConfig
        
        # Clear cache
        $script:availableThemesCache = $null
        $script:stringLengthCache = @{}
        
        # Ensure themes directory exists
        Ensure-DirectoryExists -Path $config.ThemesDir | Out-Null
        
        # Save built-in themes to files if they don't exist
        foreach ($themeName in $script:themePresets.Keys) {
            $themePath = Join-Path $config.ThemesDir "$themeName.json"
            if (-not (Test-Path $themePath)) {
                try {
                    # Get a deep copy of the theme
                    $themeToSave = Copy-HashtableDeep -Source $script:themePresets[$themeName]
                    # Convert to JSON and save
                    ConvertTo-Json -InputObject $themeToSave -Depth 10 | 
                        Out-File -FilePath $themePath -Encoding utf8
                    Write-Verbose "Saved built-in theme: $themeName"
                } catch {
                    Write-AppLog "Failed to save built-in theme '$themeName': $($_.Exception.Message)" -Level WARNING
                }
            }
        }
        
        # Load default theme
        $defaultThemeName = $config.DefaultTheme
        if (-not $defaultThemeName -or -not (Set-CurrentTheme -ThemeName $defaultThemeName)) {
            # If failed to load specified theme, use Default
            if (-not (Set-CurrentTheme -ThemeName "Default")) {
                # If even that fails, use the hardcoded default theme
                $script:currentTheme = $script:defaultTheme
                $script:colors = $script:defaultTheme.Colors
                $script:useAnsiColors = $script:defaultTheme.UseAnsiColors
                Write-AppLog "Failed to load any theme, using hardcoded default" -Level WARNING
            }
        }
        
        Write-AppLog "Theme engine initialized with theme: $($script:currentTheme.Name)" -Level INFO
        return $true
    } catch {
        Handle-Error -ErrorRecord $_ -Context "Theme engine initialization" -Continue
        # Even on error, ensure we have a theme
        if (-not $script:currentTheme) {
            $script:currentTheme = $script:defaultTheme
            $script:colors = $script:defaultTheme.Colors
            $script:useAnsiColors = $script:defaultTheme.UseAnsiColors
        }
        return $false
    }
}

<#
.SYNOPSIS
    Creates a deep copy of a hashtable.
.DESCRIPTION
    Creates a deep copy of a hashtable, including all nested hashtables.
.PARAMETER Source
    The hashtable to copy.
.EXAMPLE
    $copy = Copy-HashtableDeep -Source $originalHashtable
.OUTPUTS
    System.Collections.Hashtable - The deep copy
#>
function Copy-HashtableDeep {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        $Source
    )
    
    if ($null -eq $Source) { return $null }
    
    if ($Source -is [hashtable]) {
        $copy = @{}
        foreach ($key in $Source.Keys) {
            $copy[$key] = Copy-HashtableDeep -Source $Source[$key]
        }
        return $copy
    } elseif ($Source -is [System.Collections.ICollection]) {
        $copy = New-Object -TypeName "System.Collections.ArrayList"
        foreach ($item in $Source) {
            $null = $copy.Add((Copy-HashtableDeep -Source $item))
        }
        return $copy
    } else {
        return $Source
    }
}

<#
.SYNOPSIS
    Converts JSON to hashtable.
.DESCRIPTION
    Converts a JSON string or PSCustomObject to a hashtable.
.PARAMETER InputObject
    The JSON string or PSCustomObject to convert.
.EXAMPLE
    $hashtable = ConvertFrom-JsonToHashtable -InputObject $jsonString
.OUTPUTS
    System.Collections.Hashtable - The resulting hashtable
#>
function ConvertFrom-JsonToHashtable {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        $InputObject
    )
    
    process {
        # If it's a string, convert to object first
        if ($InputObject -is [string]) {
            $InputObject = $InputObject | ConvertFrom-Json
        }
        
        # If it's not a custom object, return as is
        if (-not ($InputObject -is [PSCustomObject])) {
            return $InputObject
        }
        
        # Convert PSCustomObject to hashtable
        $hashtable = @{}
        foreach ($property in $InputObject.PSObject.Properties) {
            $value = $property.Value
            
            # Handle nested objects
            if ($value -is [PSCustomObject]) {
                $value = ConvertFrom-JsonToHashtable -InputObject $value
            } elseif ($value -is [Object[]]) {
                # Handle arrays
                $value = @($value | ForEach-Object {
                    if ($_ -is [PSCustomObject]) {
                        ConvertFrom-JsonToHashtable -InputObject $_
                    } else {
                        $_
                    }
                })
            }
            
            $hashtable[$property.Name] = $value
        }
        
        return $hashtable
    }
}

<#
.SYNOPSIS
    Gets an entity by ID.
.DESCRIPTION
    Retrieves an entity from a data file by its ID.
.PARAMETER FilePath
    The path to the data file.
.PARAMETER ID
    The ID of the entity to retrieve.
.PARAMETER IdField
    The name of the ID field. Default is "ID".
.EXAMPLE
    $todo = Get-EntityById -FilePath $config.TodosFullPath -ID "12345"
.OUTPUTS
    PSObject representing the entity, or $null if not found
#>
function Get-EntityById {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$FilePath,
        
        [Parameter(Mandatory=$true)]
        [string]$ID,
        
        [Parameter(Mandatory=$false)]
        [string]$IdField = "ID"
    )
    
    try {
        # Get all entities
        $entities = @(Get-EntityData -FilePath $FilePath)
        
        # Find the entity by ID
        $entity = $entities | Where-Object { $_.$IdField -eq $ID } | Select-Object -First 1
        
        if (-not $entity) {
            Write-Verbose "Entity with $IdField='$ID' not found in $FilePath"
            return $null
        }
        
        return $entity
    } catch {
        Handle-Error -ErrorRecord $_ -Context "Getting entity by ID" -Continue
        return $null
    }
}

<#
.SYNOPSIS
    Updates an entity by ID.
.DESCRIPTION
    Updates an entity in a data file by its ID.
.PARAMETER FilePath
    The path to the data file.
.PARAMETER ID
    The ID of the entity to update.
.PARAMETER UpdatedEntity
    The updated entity object.
.PARAMETER IdField
    The name of the ID field. Default is "ID".
.EXAMPLE
    $success = Update-EntityById -FilePath $config.TodosFullPath -ID "12345" -UpdatedEntity $updatedTodo
.OUTPUTS
    Boolean indicating success or failure
#>
function Update-EntityById {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$FilePath,
        
        [Parameter(Mandatory=$true)]
        [string]$ID,
        
        [Parameter(Mandatory=$true)]
        [PSObject]$UpdatedEntity,
        
        [Parameter(Mandatory=$false)]
        [string]$IdField = "ID"
    )
    
    try {
        # Get all entities
        $entities = @(Get-EntityData -FilePath $FilePath)
        
        # Create updated list
        $updatedEntities = @()
        $entityFound = $false
        
        foreach ($entity in $entities) {
            if ($entity.$IdField -eq $ID) {
                $updatedEntities += $UpdatedEntity
                $entityFound = $true
            } else {
                $updatedEntities += $entity
            }
        }
        
        if (-not $entityFound) {
            Write-Verbose "Entity with $IdField='$ID' not found in $FilePath"
            return $false
        }
        
        # Save the updated entities
        return Save-EntityData -Data $updatedEntities -FilePath $FilePath
    } catch {
        Handle-Error -ErrorRecord $_ -Context "Updating entity by ID" -Continue
        return $false
    }
}

<#
.SYNOPSIS
    Removes an entity by ID.
.DESCRIPTION
    Removes an entity from a data file by its ID.
.PARAMETER FilePath
    The path to the data file.
.PARAMETER ID
    The ID of the entity to remove.
.PARAMETER IdField
    The name of the ID field. Default is "ID".
.EXAMPLE
    $success = Remove-EntityById -FilePath $config.TodosFullPath -ID "12345"
.OUTPUTS
    Boolean indicating success or failure
#>
function Remove-EntityById {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$FilePath,
        
        [Parameter(Mandatory=$true)]
        [string]$ID,
        
        [Parameter(Mandatory=$false)]
        [string]$IdField = "ID"
    )
    
    try {
        # Get all entities
        $entities = @(Get-EntityData -FilePath $FilePath)
        
        # Filter out the entity to remove
        $updatedEntities = $entities | Where-Object { $_.$IdField -ne $ID }
        
        # Check if an entity was removed
        if ($updatedEntities.Count -eq $entities.Count) {
            Write-Verbose "Entity with $IdField='$ID' not found in $FilePath"
            return $false
        }
        
        # Save the updated entities
        return Save-EntityData -Data $updatedEntities -FilePath $FilePath
    } catch {
        Handle-Error -ErrorRecord $_ -Context "Removing entity by ID" -Continue
        return $false
    }
}

<#
.SYNOPSIS
    Creates a new entity.
.DESCRIPTION
    Creates a new entity and adds it to a data file.
.PARAMETER FilePath
    The path to the data file.
.PARAMETER Entity
    The entity object to create.
.PARAMETER IdField
    The name of the ID field. Default is "ID".
.PARAMETER GenerateId
    Whether to generate a new ID for the entity if one doesn't exist.
.EXAMPLE
    $success = Create-Entity -FilePath $config.TodosFullPath -Entity $newTodo -GenerateId
.OUTPUTS
    Boolean indicating success or failure
#>
function Create-Entity {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$FilePath,
        
        [Parameter(Mandatory=$true)]
        [PSObject]$Entity,
        
        [Parameter(Mandatory=$false)]
        [string]$IdField = "ID",
        
        [Parameter(Mandatory=$false)]
        [switch]$GenerateId
    )
    
    try {
        # Generate ID if needed
        if ($GenerateId -and (-not $Entity.PSObject.Properties.Name.Contains($IdField) -or [string]::IsNullOrWhiteSpace($Entity.$IdField))) {
            $newId = New-ID
            $Entity | Add-Member -NotePropertyName $IdField -NotePropertyValue $newId -Force
        }
        
        # Get all entities
        $entities = @(Get-EntityData -FilePath $FilePath)
        
        # Add the new entity
        $updatedEntities = $entities + $Entity
        
        # Save the updated entities
        return Save-EntityData -Data $updatedEntities -FilePath $FilePath
    } catch {
        Handle-Error -ErrorRecord $_ -Context "Creating entity" -Continue
        return $false
    }
}

<#
.SYNOPSIS
    Generates a new unique ID.
.DESCRIPTION
    Generates a new unique identifier (GUID).
.PARAMETER Format
    The format of the ID to generate (Short or Full). Default is Full.
.EXAMPLE
    $id = New-ID
.OUTPUTS
    String containing the generated ID
#>
function New-ID {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)]
        [ValidateSet("Short", "Full")]
        [string]$Format = "Full"
    )
    
    switch ($Format) {
        "Short" {
            return [Guid]::NewGuid().ToString("N").Substring(0, 8)
        }
        default {
            return [Guid]::NewGuid().ToString()
        }
    }
}

<#
.SYNOPSIS
    Gets the relative week description.
.DESCRIPTION
    Returns a relative description of a week (This Week, Next Week, etc.).
.PARAMETER Date
    The date to get the description for.
.PARAMETER ReferenceDate
    The reference date to compare against. Default is today.
.EXAMPLE
    $description = Get-RelativeWeekDescription -Date "2024-04-15"
.OUTPUTS
    String containing the relative week description
#>
function Get-RelativeWeekDescription {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [DateTime]$Date,
        
        [Parameter(Mandatory=$false)]
        [DateTime]$ReferenceDate = (Get-Date).Date
    )
    
    # Get the start of the reference week
    $referenceWeekStart = Get-FirstDayOfWeek -Date $ReferenceDate
    
    # Get the start of the target week
    $targetWeekStart = Get-FirstDayOfWeek -Date $Date
    
    # Calculate the difference in weeks
    $weekDiff = (New-TimeSpan -Start $referenceWeekStart -End $targetWeekStart).Days / 7
    
    switch ($weekDiff) {
        -4 { return "4 weeks ago" }
        -3 { return "3 weeks ago" }
        -2 { return "2 weeks ago" }
        -1 { return "Last week" }
        0 { return "This week" }
        1 { return "Next week" }
        2 { return "In 2 weeks" }
        3 { return "In 3 weeks" }
        4 { return "In 4 weeks" }
        default {
            $weekNum = Get-WeekNumber -Date $Date
            $year = $Date.Year
            
            if ($year -eq $ReferenceDate.Year) {
                return "Week $weekNum"
            } else {
                return "Week $weekNum, $year"
            }
        }
    }
}

<#
.SYNOPSIS
    Gets the date range for a month.
.DESCRIPTION
    Gets the start and end dates for a specified month.
.PARAMETER Year
    The year.
.PARAMETER Month
    The month number (1-12).
.EXAMPLE
    $range = Get-MonthDateRange -Year 2024 -Month 4
.OUTPUTS
    PSObject with StartDate and EndDate properties
#>
function Get-MonthDateRange {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [int]$Year,
        
        [Parameter(Mandatory=$true)]
        [ValidateRange(1, 12)]
        [int]$Month
    )
    
    $startDate = [DateTime]::new($Year, $Month, 1)
    $endDate = $startDate.AddMonths(1).AddDays(-1)
    
    return [PSCustomObject]@{
        StartDate = $startDate
        EndDate = $endDate
    }
}

#region Display Functions

# This implementation is based on the display-module.txt file

<#
.SYNOPSIS
    Gets the safe console width to use for UI components.
.DESCRIPTION
    Provides a consistent way to get console width while handling edge cases
    and potential errors accessing the console information.
.EXAMPLE
    $width = Get-SafeConsoleWidth
.OUTPUTS
    System.Int32 - The safe console width to use
#>
function Get-SafeConsoleWidth {
    # Check for override (used for testing)
    if ($null -ne $script:override_console_width) {
        return $script:override_console_width
    }

    return Invoke-WithErrorHandling -ScriptBlock {
        # Subtract 1 to prevent wrapping issues with some terminals
        # Keep a reasonable minimum width
        return [Math]::Max(40, $Host.UI.RawUI.WindowSize.Width - 1)
    } -ErrorContext "Getting console width" -Continue -DefaultValue 80
}

<#
.SYNOPSIS
    Writes colored text to the console with ANSI support.
.DESCRIPTION
    Centralizes the output of colored text with support for ANSI color codes
    when enabled and fallback to standard PowerShell colors when not.
.PARAMETER Text
    The text to write.
.PARAMETER ForegroundColor
    The foreground color to use.
.PARAMETER BackgroundColor
    The background color to use.
.PARAMETER NoNewline
    If specified, no newline is added after the text.
.EXAMPLE
    Write-ColorText "This is colored text" -ForegroundColor "Green"
.EXAMPLE
    Write-ColorText "This has no newline" -ForegroundColor "Red" -NoNewline
#>
function Write-ColorText {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)]
        [string]$Text = "",
        
        [Parameter(Mandatory=$false)]
        $ForegroundColor = $null,
        
        [Parameter(Mandatory=$false)]
        $BackgroundColor = $null,
        
        [Parameter(Mandatory=$false)]
        [switch]$NoNewline
    )
    
    # Handle null text gracefully
    if ($null -eq $Text) { $Text = "" }
    
    # Determine colors to use
    $fg = if ($null -ne $ForegroundColor) { $ForegroundColor } else { (Get-CurrentTheme).Colors.Normal }
    $bg = $BackgroundColor
    
    # Get console color from various formats
    function Get-ConsoleColor {
        param($Color)
        
        if ($null -eq $Color) { return $null }
        
        if ($Color -is [System.ConsoleColor]) { 
            return $Color 
        }
        
        if ($Color -is [string]) {
            # Try to convert string to ConsoleColor enum
            $validColors = [System.Enum]::GetNames([System.ConsoleColor])
            foreach ($validColor in $validColors) {
                if ($validColor -ieq $Color) { return [System.ConsoleColor]::Parse([System.ConsoleColor], $validColor) }
            }
        }
        
        # Default to White if conversion fails
        return [System.ConsoleColor]::White
    }
    
    # Check if we should use ANSI colors
    if ($script:useAnsiColors) {
        # Get ANSI color code
        function Get-AnsiColorCode {
            param($Color, [switch]$IsBackground)
            
            if ($null -eq $Color) { return $null }
            
            $colorMap = if ($IsBackground) { $script:ansiBackgroundColors } else { $script:ansiForegroundColors }
            
            if ($Color -is [string] -and $colorMap.ContainsKey($Color)) {
                return $colorMap[$Color]
            }
            
            # Default if not found
            return if ($IsBackground) { "40" } else { "37" }
        }
        
        # Build ANSI sequence
        $ansiSeq = ""
        
        # Add foreground color
        $fgCode = Get-AnsiColorCode -Color $fg
        if ($null -ne $fgCode) {
            $ansiSeq += "`e[$fgCode" + "m"
        }
        
        # Add background color
        $bgCode = Get-AnsiColorCode -Color $bg -IsBackground
        if ($null -ne $bgCode) {
            # Add separator if needed
            if ($ansiSeq -ne "") {
                $ansiSeq = $ansiSeq.TrimEnd("m") + ";" 
            } else {
                $ansiSeq += "`e["
            }
            $ansiSeq += "$bgCode" + "m"
        }
        
        # Write with ANSI codes
        if ($ansiSeq -ne "") {
            if ($NoNewline) {
                Write-Host -NoNewline "$ansiSeq$Text`e[0m"
            } else {
                Write-Host "$ansiSeq$Text`e[0m"
            }
        } else {
            # No colors specified, use default
            if ($NoNewline) {
                Write-Host -NoNewline $Text
            } else {
                Write-Host $Text
            }
        }
    } else {
        # Use standard PowerShell coloring
        $params = @{
            Object = $Text
            NoNewline = $NoNewline
        }
        
        $consoleFg = Get-ConsoleColor -Color $fg
        if ($null -ne $consoleFg) {
            $params.ForegroundColor = $consoleFg
        }
        
        $consoleBg = Get-ConsoleColor -Color $bg
        if ($null -ne $consoleBg) {
            $params.BackgroundColor = $consoleBg
        }
        
        Write-Host @params
    }
}

<#
.SYNOPSIS
    Removes ANSI escape codes from text.
.DESCRIPTION
    Strips ANSI escape sequences from a string to get the displayable text.
    Used for calculating string lengths and formatting text for output.
.PARAMETER Text
    The text to process.
.EXAMPLE
    $cleanText = Remove-AnsiCodes -Text $ansiColoredText
.OUTPUTS
    System.String - The text with ANSI codes removed
#>
function Remove-AnsiCodes {
    param(
        [Parameter(Mandatory=$false)]
        [string]$Text = ""
    )
    
    if ([string]::IsNullOrEmpty($Text)) { return "" }
    
    return Invoke-WithErrorHandling -ScriptBlock {
        if ($null -eq $script:ansiEscapePattern) {
            return $Text
        }
        
        return $script:ansiEscapePattern.Replace($Text, '')
    } -ErrorContext "Removing ANSI codes" -Continue -DefaultValue $Text
}

<#
.SYNOPSIS
    Gets the visible length of a string by removing ANSI codes.
.DESCRIPTION
    Calculates the visible length of a string after removing ANSI escape sequences.
    Used for text formatting and alignment in UI components.
.PARAMETER Text
    The text to measure.
.EXAMPLE
    $length = Get-VisibleStringLength -Text $coloredText
.OUTPUTS
    System.Int32 - The visible length of the text
#>
function Get-VisibleStringLength {
    param(
        [Parameter(Mandatory=$false)]
        [string]$Text = ""
    )
    
    if ($null -eq $Text) { return 0 }
    if ($Text.Length -eq 0) { return 0 }
    
    # Use caching for performance with repeated calls
    $cacheKey = [System.Security.Cryptography.MD5]::Create().ComputeHash(
        [System.Text.Encoding]::UTF8.GetBytes($Text)
    ) | ForEach-Object { $_.ToString("X2") } | Join-String
    
    if ($script:stringLengthCache.ContainsKey($cacheKey)) {
        return $script:stringLengthCache[$cacheKey]
    }
    
    return Invoke-WithErrorHandling -ScriptBlock {
        # Strip ANSI codes and calculate length
        $strippedText = Remove-AnsiCodes -Text $Text
        $length = $strippedText.Length
        
        # Cache the result
        if ($script:stringLengthCache.Count -gt 1000) {
            # Cache getting too large, clear it
            $script:stringLengthCache.Clear()
        }
        $script:stringLengthCache[$cacheKey] = $length
        
        return $length
    } -ErrorContext "Calculating visible string length" -Continue -DefaultValue $Text.Length
}

<#
.SYNOPSIS
    Safely truncates text to a specified length.
.DESCRIPTION
    Truncates text to a maximum length while handling ANSI color codes correctly.
.PARAMETER Text
    The text to truncate.
.PARAMETER MaxLength
    The maximum length for the output.
.PARAMETER PreserveAnsi
    If specified, ANSI color codes are preserved in the truncated string.
.EXAMPLE
    $truncated = Safe-TruncateString -Text $longText -MaxLength 50
.EXAMPLE
    $truncated = Safe-TruncateString -Text $coloredText -MaxLength 50 -PreserveAnsi
.OUTPUTS
    System.String - The truncated text
#>
function Safe-TruncateString {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Text,
        
        [Parameter(Mandatory=$true)]
        [int]$MaxLength,
        
        [Parameter(Mandatory=$false)]
        [switch]$PreserveAnsi
    )
    
    if ([string]::IsNullOrEmpty($Text)) { return "" }
    if ($MaxLength -le 0) { return "" }
    
    $visibleLength = Get-VisibleStringLength -Text $Text
    if ($visibleLength -le $MaxLength) {
        return $Text # Already fits, no truncation needed
    }
    
    return Invoke-WithErrorHandling -ScriptBlock {
        if ($PreserveAnsi) {
            # This is a simplified approach that may not handle all ANSI cases perfectly
            # But it's more reliable than complex parsing that could fail
            $cleanText = Remove-AnsiCodes -Text $Text
            if ($cleanText.Length -le $MaxLength) {
                return $Text # Edge case: ANSI codes make it look longer but actual content fits
            }
            
            # Simple ellipsis approach
            if ($MaxLength -le 3) {
                return "..."
            }
            
            # Extract characters up to position, preserving ANSI
            $result = ""
            $visibleCount = 0
            $i = 0
            
            while ($i -lt $Text.Length -and $visibleCount -lt $MaxLength - 3) {
                if ($Text[$i] -eq [char]27 -and $i + 1 -lt $Text.Length -and $Text[$i + 1] -eq '[') {
                    # Found potential ANSI escape sequence
                    $j = $i
                    while ($j -lt$Text.Length -and -not [char]::IsLetter($Text[$j])) {
                        $j++
                    }
                    if ($j -lt $Text.Length) {
                        # Include the entire sequence
                        $result += $Text.Substring($i, $j - $i + 1)
                        $i = $j + 1
                        continue
                    }
                }
                
                # Regular character
                $result += $Text[$i]
                $visibleCount++
                $i++
            }
            
            # Add ellipsis
            $result += "..."
            
            # Always ensure we end with a reset code if we have ANSI
            if ($Text -match '\x1b\[') {
                $result += "`e[0m"
            }
            
            return $result
        }
        else {
            # Simple truncation without ANSI preservation
            $cleanText = Remove-AnsiCodes -Text $Text
            if ($MaxLength -le 3) {
                return "..."
            }
            return $cleanText.Substring(0, [Math]::Min($cleanText.Length, $MaxLength - 3)) + "..."
        }
    } -ErrorContext "Truncating string" -Continue -DefaultValue $Text.Substring(0, [Math]::Min($Text.Length, $MaxLength))
}

<#
.SYNOPSIS
    Renders a header with a title and optional subtitle.
.DESCRIPTION
    Displays a header box with a title and optional subtitle, using theme-specific styling.
.PARAMETER Title
    The title text.
.PARAMETER Subtitle
    An optional subtitle.
.EXAMPLE
    Render-Header -Title "My Application" -Subtitle "Version 1.0"
#>
function Render-Header {
    param(
        [string]$Title, 
        [string]$Subtitle = ""
    )
    
    Clear-Host
    $consoleWidth = Get-SafeConsoleWidth
    
    # Get theme settings or defaults
    $headerStyle = "Simple"
    $borderChar = "="
    $cornerTL = "+"
    $cornerTR = "+"
    $cornerBL = "+"
    $cornerBR = "+"
    $vSideChar = "|" # Default vertical side character
    $gradientChars = "█▓▒░"
    
    # Safely get theme header settings
    if ($script:currentTheme -and $script:currentTheme.Headers) {
        $headerConf = $script:currentTheme.Headers
        $headerStyle = if ($null -ne $headerConf.Style -and $headerConf.Style -ne '') { $headerConf.Style } else { "Simple" }
        $borderChar = if ($null -ne $headerConf.BorderChar -and $headerConf.BorderChar -ne '') { $headerConf.BorderChar } else { "=" }
        
        # Determine corners based on style and definition
        if ($headerConf.Corners -and $headerConf.Corners.Length -ge 4) {
            $cornerTL = $headerConf.Corners[0]
            $cornerTR = $headerConf.Corners[1]
            $cornerBL = $headerConf.Corners[2]
            $cornerBR = $headerConf.Corners[3]
        } else {
            # Infer corners from border char or style if not explicitly defined
            switch ($headerStyle) {
                "Double" { $cornerTL = "╔"; $cornerTR = "╗"; $cornerBL = "╚"; $cornerBR = "╝" }
                "Minimal" { $cornerTL = "╭"; $cornerTR = "╮"; $cornerBL = "╰"; $cornerBR = "╯" }
                "Block" { $cornerTL = $cornerTR = $cornerBL = $cornerBR = $borderChar }
                default { $cornerTL = "+"; $cornerTR = "+"; $cornerBL = "+"; $cornerBR = "+" } # Simple/Default
            }
        }
        
        # Determine vertical side character based on style
        switch ($headerStyle) {
            "Double" { $vSideChar = "║" }
            "Block" { $vSideChar = $borderChar }
            "Minimal" { $vSideChar = " " } # Minimal has no vertical sides usually
            default { $vSideChar = "│" } # Simple/Gradient/Default
        }
        
        $gradientChars = if ($null -ne $headerConf.GradientChars -and $headerConf.GradientChars -ne '') {
            $headerConf.GradientChars
        } else {
            "█▓▒░"
        }
    }
    
    $borderLine = $borderChar * ($consoleWidth - 2)
    
    # Title padding (ANSI-aware)
    $titleLength = Get-VisibleStringLength -Text $Title
    # Ensure padding calculation doesn't go negative if title is wider than console
    $paddingLength = [Math]::Max(0, ($consoleWidth - $titleLength - 2)) / 2
    $leftPad = " " * [Math]::Floor($paddingLength)
    $rightPad = " " * [Math]::Ceiling($paddingLength)
    
    # Subtitle padding
    $subLeftPad = ""; $subRightPad = ""
    if (-not [string]::IsNullOrWhiteSpace($Subtitle)) {
        $subTitleLength = Get-VisibleStringLength -Text $Subtitle
        $subPaddingLength = [Math]::Max(0, ($consoleWidth - $subTitleLength - 2)) / 2
        $subLeftPad = " " * [Math]::Floor($subPaddingLength)
        $subRightPad = " " * [Math]::Ceiling($subPaddingLength)
    }
    
    # Draw header
    Write-ColorText "$cornerTL$borderLine$cornerTR" -ForegroundColor $script:colors.TableBorder
    Write-ColorText "$vSideChar$leftPad$Title$rightPad$vSideChar" -ForegroundColor $script:colors.Header
    
    if (-not [string]::IsNullOrWhiteSpace($Subtitle)) {
        Write-ColorText "$vSideChar$subLeftPad$Subtitle$subRightPad$vSideChar" -ForegroundColor $script:colors.Header
    }
    
    Write-ColorText "$cornerBL$borderLine$cornerBR" -ForegroundColor $script:colors.TableBorder
    Write-Host "" # Spacer
}

<#
.SYNOPSIS
    Displays a table of data with formatting and styling.
.DESCRIPTION
    Shows tabular data with column headers, formatting, and row coloring
    based on theme settings and custom rules.
.PARAMETER Data
    The array of data objects to display.
.PARAMETER Columns
    The column names to include in the table.
.PARAMETER Headers
    Optional hashtable mapping column names to display headers.
.PARAMETER Formatters
    Optional hashtable of scriptblocks to format cell values.
.PARAMETER ShowRowNumbers
    If specified, row numbers are included in the table.
.PARAMETER RowColorizer
    Optional scriptblock to determine row colors.
.EXAMPLE
    Show-Table -Data $projects -Columns @("Name", "Status", "DueDate") -Headers @{ "DueDate" = "Due Date" }
.OUTPUTS
    System.Int32 - The number of rows displayed
#>
# Fix for the Show-Table function in ProjectTracker.Core.psm1
# Replace the existing Show-Table function with this updated version

function Show-Table {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [array]$Data,
        
        [Parameter(Mandatory=$true)]
        [string[]]$Columns,
        
        [Parameter(Mandatory=$false)]
        [hashtable]$Headers = @{},
        
        [Parameter(Mandatory=$false)]
        [hashtable]$Formatters = @{},
        
        [Parameter(Mandatory=$false)]
        [switch]$ShowRowNumbers,
        
        [Parameter(Mandatory=$false)]
        [scriptblock]$RowColorizer = $null
    )
    
    # Ensure we have a theme
    if ($null -eq $script:currentTheme) {
        # Create a minimal default theme if none exists
        $script:currentTheme = @{
            Name = "EmergencyDefault"
            Colors = @{
                Normal = "White"
                Header = "Cyan"
                Accent1 = "Yellow"
                TableBorder = "Gray"
                Error = "Red"
                Warning = "Yellow"
                Success = "Green"
                Completed = "DarkGray"
            }
            Table = @{
                Chars = @{
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
                RowSeparator = $false
                CellPadding = 1
                HeaderStyle = "Normal"
            }
        }
        $script:colors = $script:currentTheme.Colors
    }
    
    # Make sure colors are set
    if ($null -eq $script:colors -or $script:colors.Count -eq 0) {
        $script:colors = @{
            Normal = "White"
            Header = "Cyan"
            Accent1 = "Yellow"
            TableBorder = "Gray"
            Error = "Red"
            Warning = "Yellow"
            Success = "Green"
            Completed = "DarkGray"
        }
    }
    
    # Get border characters from theme with fallbacks
    $chars = @{
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
    
    # Try to get theme-specific border characters safely
    if ($null -ne $script:currentTheme -and 
        $null -ne $script:currentTheme.Table -and 
        $script:currentTheme.Table.ContainsKey("Chars") -and
        $null -ne $script:currentTheme.Table.Chars) {
        
        # Copy over only valid characters
        $themeChars = $script:currentTheme.Table.Chars
        foreach ($key in $chars.Keys) {
            if ($themeChars.ContainsKey($key) -and $null -ne $themeChars[$key]) {
                $chars[$key] = $themeChars[$key]
            }
        }
    }
    
    # Determine if row separators should be used (with fallback)
    $useRowSeparator = $false
    if ($null -ne $script:currentTheme -and 
        $null -ne $script:currentTheme.Table -and 
        $script:currentTheme.Table.ContainsKey("RowSeparator")) {
        $useRowSeparator = $script:currentTheme.Table.RowSeparator
    }
    
    # Calculate column widths
    $widths = @{}
    
    # Safe access to config
    $fixedWidths = @{}
    $alignments = @{}
    
    try {
        $config = Get-AppConfig
        if ($null -ne $config -and 
            $config.ContainsKey("TableOptions") -and 
            $null -ne $config.TableOptions) {
            
            if ($config.TableOptions.ContainsKey("FixedWidths") -and 
                $null -ne $config.TableOptions.FixedWidths) {
                $fixedWidths = $config.TableOptions.FixedWidths
            }
            
            if ($config.TableOptions.ContainsKey("Alignments") -and 
                $null -ne $config.TableOptions.Alignments) {
                $alignments = $config.TableOptions.Alignments
            }
        }
    } catch {
        # Silently continue if config can't be accessed
        Write-Verbose "Could not access table config options: $($_.Exception.Message)"
    }
    
    # Safe function to get visible string length
    function Safe-GetVisibleLength {
        param([string]$text)
        
        try {
            return Get-VisibleStringLength -Text $text
        } catch {
            # Fallback to basic string length
            return $text.Length
        }
    }
    
    foreach ($col in $Columns) {
        # Check for fixed width first
        if ($fixedWidths.ContainsKey($col) -and $fixedWidths[$col] -gt 0) {
            $widths[$col] = $fixedWidths[$col]
            continue
        }
        
        # Calculate width based on content
        $headerText = if ($Headers.ContainsKey($col)) { $Headers[$col] } else { $col }
        $maxContentLen = $headerText.Length
        
        # Check data for max content length
        if ($null -ne $Data -and $Data.Count -gt 0) {
            foreach ($item in $Data) {
                if ($null -eq $item) { continue }
                
                $value = if ($item.PSObject.Properties[$col]) { 
                    $item.PSObject.Properties[$col].Value 
                } else { 
                    "" 
                }
                
                $formatted = ""
                if ($Formatters.ContainsKey($col)) {
                    try {
                        $result = & $Formatters[$col] $value $item
                        $formatted = if ($null -ne $result) { $result.ToString() } else { "" }
                    } catch {
                        $formatted = "[ERR]"
                    }
                } else {
                    $formatted = if ($null -ne $value) { $value.ToString() } else { "" }
                }
                
                $len = Safe-GetVisibleLength -text $formatted
                if ($len -gt $maxContentLen) {
                    $maxContentLen = $len
                }
            }
        }
        
        # Add some padding
        $widths[$col] = $maxContentLen + 2
        
        # Ensure minimum width
        if ($widths[$col] -lt 3) {
            $widths[$col] = 3
        }
    }
    
    # Function to build table borders
    function Build-TableBorder {
        param (
            [string]$Left,
            [string]$Horizontal,
            [string]$Right,
            [string]$Junction
        )
        
        $border = $Left
        for ($i = 0; $i -lt $Columns.Count; $i++) {
            $col = $Columns[$i]
            $border += $Horizontal * $widths[$col]
            
            if ($i -lt $Columns.Count - 1) {
                $border += $Junction
            }
        }
        $border += $Right
        
        return $border
    }
    
    # Draw top border
    $topBorder = Build-TableBorder -Left $chars.TopLeft -Horizontal $chars.Horizontal -Right $chars.TopRight -Junction $chars.TopJunction
    Write-ColorText $topBorder -ForegroundColor $script:colors.TableBorder
    
    # Draw header row
    Write-ColorText $chars.Vertical -ForegroundColor $script:colors.TableBorder -NoNewline
    
    foreach ($col in $Columns) {
        $headerText = if ($Headers.ContainsKey($col)) { $Headers[$col] } else { $col }
        $width = $widths[$col]
        $alignment = if ($alignments.ContainsKey($col)) { $alignments[$col] } else { "Left" }
        
        # Ensure headerText isn't null
        if ($null -eq $headerText) { $headerText = "" }
        
        # Truncate if needed
        if ($headerText.Length -gt $width - 2) {
            $headerText = $headerText.Substring(0, $width - 5) + "..."
        }
        
        # Pad based on alignment
        $padding = $width - 2 - $headerText.Length
        if ($padding -lt 0) { $padding = 0 }
        
        $leftPad = 0
        $rightPad = 0
        
        switch ($alignment.ToUpper()) {
            "RIGHT" { $leftPad = $padding; $rightPad = 0 }
            "CENTER" { $leftPad = [Math]::Floor($padding / 2); $rightPad = $padding - $leftPad }
            default { $leftPad = 0; $rightPad = $padding }
        }
        
        $paddedHeader = (" " * $leftPad) + $headerText + (" " * $rightPad)
        Write-ColorText " $paddedHeader " -ForegroundColor $script:colors.Header -NoNewline
        Write-ColorText $chars.Vertical -ForegroundColor $script:colors.TableBorder -NoNewline
    }
    
    Write-Host "" # End header row
    
    # Draw header/data separator
    $midBorder = Build-TableBorder -Left $chars.LeftJunction -Horizontal $chars.Horizontal -Right $chars.RightJunction -Junction $chars.CrossJunction
    Write-ColorText $midBorder -ForegroundColor $script:colors.TableBorder
    
    # Handle empty data case
    if ($null -eq $Data -or $Data.Count -eq 0) {
        $emptyMessage = "No data available"
        $totalWidth = ($Columns | ForEach-Object { $widths[$_] } | Measure-Object -Sum).Sum + $Columns.Count + 1
        
        $padWidth = [Math]::Max(0, ($totalWidth - $emptyMessage.Length - 2) / 2)
        $leftPad = " " * [Math]::Floor($padWidth)
        $rightPad = " " * [Math]::Ceiling($padWidth)
        
        Write-ColorText $chars.Vertical -ForegroundColor $script:colors.TableBorder -NoNewline
        Write-ColorText "$leftPad$emptyMessage$rightPad" -ForegroundColor $script:colors.Completed -NoNewline
        Write-ColorText $chars.Vertical -ForegroundColor $script:colors.TableBorder
        
        # Draw bottom border
        $botBorder = Build-TableBorder -Left $chars.BottomLeft -Horizontal $chars.Horizontal -Right $chars.BottomRight -Junction $chars.BottomJunction
        Write-ColorText $botBorder -ForegroundColor $script:colors.TableBorder
        
        return 0
    }
    
    # Draw data rows
    $rowIndex = 0
    foreach ($item in $Data) {
        $rowIndex++
        
        # Skip null items
        if ($null -eq $item) { continue }
        
        # Get row color with fallback
        $rowColor = $script:colors.Normal # Default color
        if ($null -ne $RowColorizer) {
            try {
                $colorResult = & $RowColorizer $item $rowIndex
                if (-not [string]::IsNullOrEmpty($colorResult)) {
                    $rowColor = $colorResult
                }
            } catch {
                # Ignore errors in colorizer
                Write-Verbose "Row colorizer error: $($_.Exception.Message)"
            }
        }
        
        # Start row with vertical border
        Write-ColorText $chars.Vertical -ForegroundColor $script:colors.TableBorder -NoNewline
        
        # Draw each cell
        foreach ($col in $Columns) {
            $cellValue = if ($item.PSObject.Properties[$col]) { 
                $item.PSObject.Properties[$col].Value 
            } else { 
                "" 
            }
            
            # Format cell value
            $formatted = ""
            if ($Formatters.ContainsKey($col)) {
                try {
                    $result = & $Formatters[$col] $cellValue $item
                    $formatted = if ($null -ne $result) { $result.ToString() } else { "" }
                } catch {
                    $formatted = "[ERR]"
                }
            } else {
                $formatted = if ($null -ne $cellValue) { $cellValue.ToString() } else { "" }
            }
            
            $width = $widths[$col]
            $alignment = if ($alignments.ContainsKey($col)) { $alignments[$col] } else { "Left" }
            
            # Truncate if needed - with safe handling
            $visibleLength = 0
            try {
                $visibleLength = Get-VisibleStringLength -Text $formatted
            } catch {
                $visibleLength = $formatted.Length
            }
            
            if ($visibleLength -gt $width - 2) {
                try {
                    $formatted = Safe-TruncateString -Text $formatted -MaxLength ($width - 2) -PreserveAnsi
                } catch {
                    # Fallback to basic truncation
                    if ($formatted.Length -gt $width - 2) {
                        $formatted = $formatted.Substring(0, $width - 5) + "..."
                    }
                }
                
                # Recalculate length after truncation
                try {
                    $visibleLength = Get-VisibleStringLength -Text $formatted
                } catch {
                    $visibleLength = $formatted.Length
                }
            }
            
            # Pad based on alignment
            $padding = $width - 2 - $visibleLength
            if ($padding -lt 0) { $padding = 0 }
            
            $leftPad = 0
            $rightPad = 0
            
            switch ($alignment.ToUpper()) {
                "RIGHT" { $leftPad = $padding; $rightPad = 0 }
                "CENTER" { $leftPad = [Math]::Floor($padding / 2); $rightPad = $padding - $leftPad }
                default { $leftPad = 0; $rightPad = $padding }
            }
            
            $paddedCell = (" " * $leftPad) + $formatted + (" " * $rightPad)
            Write-ColorText " $paddedCell " -ForegroundColor $rowColor -NoNewline
            Write-ColorText $chars.Vertical -ForegroundColor $script:colors.TableBorder -NoNewline
        }
        
        Write-Host "" # End row
        
        # Draw row separator if enabled and not the last row
        if ($useRowSeparator -and $rowIndex -lt $Data.Count) {
            $rowSepBorder = Build-TableBorder -Left $chars.LeftJunction -Horizontal $chars.Horizontal -Right $chars.RightJunction -Junction $chars.CrossJunction
            Write-ColorText $rowSepBorder -ForegroundColor $script:colors.TableBorder
        }
    }
    
    # Draw bottom border
    $botBorder = Build-TableBorder -Left $chars.BottomLeft -Horizontal $chars.Horizontal -Right $chars.BottomRight -Junction $chars.BottomJunction
    Write-ColorText $botBorder -ForegroundColor $script:colors.TableBorder
    
    return $rowIndex
}
    

<#
.SYNOPSIS
    Displays a dynamic menu with options.
.DESCRIPTION
    Shows a menu with options, headers, and separators, handling user input
    and executing the selected option's function.
.PARAMETER Title
    The menu title.
.PARAMETER Subtitle
    An optional subtitle.
.PARAMETER MenuItems
    An array of menu item hashtables with Type, Key, Text, and Function properties.
.PARAMETER Prompt
    The prompt text for user input.
.PARAMETER UseNavigationBar
    If specified, shows a navigation bar above the menu.
.EXAMPLE
    Show-DynamicMenu -Title "Main Menu" -MenuItems $menuItems -Prompt "Select option:"
.OUTPUTS
    The return value from the selected menu item's function, or $null if no selection was made
#>
function Show-DynamicMenu {
    param(
        [string]$Title,
        [string]$Subtitle = "",
        [array]$MenuItems,
        [string]$Prompt = "Enter selection:",
        [switch]$UseNavigationBar
    )
    
    # Render header
    Render-Header -Title $Title -Subtitle $Subtitle
    
    # Show navigation bar if requested
    if ($UseNavigationBar) {
        Show-NavigationBar
    }
    
    # Display menu items
    $validOptions = @{}
    
    foreach ($item in $MenuItems) {
        if ($item.ContainsKey("Type")) {
            switch ($item.Type) {
                "header" {
                    Write-ColorText $item.Text -ForegroundColor $script:colors.Accent1
                    Write-ColorText "------------------------------" -ForegroundColor $script:colors.TableBorder
                }
                "separator" {
                    Write-ColorText "------------------------------" -ForegroundColor $script:colors.TableBorder
                }
                "option" {
                    $prefix = ""
                    if ($script:currentTheme.Menu.ContainsKey("UnselectedPrefix")) {
                        $prefix = $script:currentTheme.Menu.UnselectedPrefix
                    }
                    
                    $optionText = "$prefix[$($item.Key)] $($item.Text)"
                    $color = $script:colors.Normal
                    
                    if ($item.ContainsKey("IsHighlighted") -and $item.IsHighlighted) {
                        $color = $script:colors.Accent2
                        if ($script:currentTheme.Menu.ContainsKey("SelectedPrefix")) {
                            $prefix = $script:currentTheme.Menu.SelectedPrefix
                            $optionText = "$prefix[$($item.Key)] $($item.Text)"
                        }
                    }
                    
                    if ($item.ContainsKey("IsDisabled") -and $item.IsDisabled) {
                        $color = $script:colors.Completed
                    } else {
                        $validOptions[$item.Key] = $item
                    }
                    
                    Write-ColorText $optionText -ForegroundColor $color
                }
            }
        }
    }
    
    # Handle user selection
    while ($true) {
        Write-Host "`n$Prompt " -ForegroundColor $script:colors.Accent2 -NoNewline
        $choice = Read-Host
        
        if ($validOptions.ContainsKey($choice)) {
            $selectedItem = $validOptions[$choice]
            
            if ($selectedItem.ContainsKey("Function")) {
                $result = $null
                
                # Call function with arguments if provided
                if ($selectedItem.ContainsKey("Args")) {
                    $result = & $selectedItem.Function $selectedItem.Args
                } else {
                    $result = & $selectedItem.Function
                }
                
                # Only exit if IsExit is explicitly true
                if ($selectedItem.ContainsKey("IsExit") -and $selectedItem.IsExit -eq $true) {
                    return $result
                }
                
                if ($null -ne $result) {
                    return $result
                }
                
                # Redraw menu if we're still here
                Render-Header -Title $Title -Subtitle $Subtitle
                
                if ($UseNavigationBar) {
                    Show-NavigationBar
                }
                
                # Redisplay menu items
                foreach ($item in $MenuItems) {
                    if ($item.ContainsKey("Type")) {
                        switch ($item.Type) {
                            "header" {
                                Write-ColorText $item.Text -ForegroundColor $script:colors.Accent1
                                Write-ColorText "------------------------------" -ForegroundColor $script:colors.TableBorder
                            }
                            "separator" {
                                Write-ColorText "------------------------------" -ForegroundColor $script:colors.TableBorder
                            }
                            "option" {
                                $prefix = ""
                                if ($script:currentTheme.Menu.ContainsKey("UnselectedPrefix")) {
                                    $prefix = $script:currentTheme.Menu.UnselectedPrefix
                                }
                                
                                $optionText = "$prefix[$($item.Key)] $($item.Text)"
                                $color = $script:colors.Normal
                                
                                if ($item.ContainsKey("IsHighlighted") -and $item.IsHighlighted) {
                                    $color = $script:colors.Accent2
                                    if ($script:currentTheme.Menu.ContainsKey("SelectedPrefix")) {
                                        $prefix = $script:currentTheme.Menu.SelectedPrefix
                                        $optionText = "$prefix[$($item.Key)] $($item.Text)"
                                    }
                                }
                                
                                if ($item.ContainsKey("IsDisabled") -and $item.IsDisabled) {
                                    $color = $script:colors.Completed
                                }
                                
                                Write-ColorText $optionText -ForegroundColor $color
                            }
                        }
                    }
                }
            }
        } else {
            Write-ColorText "Invalid selection. Please try again." -ForegroundColor $script:colors.Error
        }
    }
}

<#
.SYNOPSIS
    Shows a progress bar.
.DESCRIPTION
    Displays a progress bar with a percentage complete and optional text.
.PARAMETER PercentComplete
    The percentage complete (0-100).
.PARAMETER Width
    The width of the progress bar in characters.
.PARAMETER Text
    Optional text to display after the progress bar.
.EXAMPLE
    Show-ProgressBar -PercentComplete 50 -Width 40 -Text "Processing files..."
#>
function Show-ProgressBar {
    param(
        [int]$PercentComplete,
        [int]$Width = 50,
        [string]$Text = ""
    )
    
    # Ensure percent is in valid range
    $percent = [Math]::Max(0, [Math]::Min(100, $PercentComplete))
    
    # Get theme characters if available
    $filledChar = "="
    $emptyChar = " "
    $leftCap = "["
    $rightCap = "]"
    
    if ($script:currentTheme.ContainsKey("ProgressBar")) {
        $pb = $script:currentTheme.ProgressBar
        if ($pb.ContainsKey("FilledChar")) { $filledChar = $pb.FilledChar }
        if ($pb.ContainsKey("EmptyChar")) { $emptyChar = $pb.EmptyChar }
        if ($pb.ContainsKey("LeftCap")) { $leftCap = $pb.LeftCap }
        if ($pb.ContainsKey("RightCap")) { $rightCap = $pb.RightCap }
    }
    
    # Calculate filled and empty portions
    $filled = [Math]::Round(($Width * $percent) / 100)
    $empty = $Width - $filled
    
    # Draw progress bar
    Write-ColorText $leftCap -NoNewline
    
    if ($filled -gt 0) {
        Write-ColorText ($filledChar * $filled) -ForegroundColor $script:colors.Success -NoNewline
    }
    
    if ($empty -gt 0) {
        Write-ColorText ($emptyChar * $empty) -ForegroundColor $script:colors.Completed -NoNewline
    }
    
    Write-ColorText $rightCap -NoNewline
    Write-ColorText " $percent% " -NoNewline
    
    if (-not [string]::IsNullOrEmpty($Text)) {
        Write-ColorText $Text
    } else {
        Write-Host ""
    }
}

#endregion Display Functions

#region Theme Management Functions

<#
.SYNOPSIS
    Performs a deep copy of a hashtable.
.DESCRIPTION
    Creates a new hashtable with all keys and values from the source,
    recursively copying nested hashtables.
.PARAMETER InputObject
    The hashtable to copy.
.EXAMPLE
    $copy = Copy-HashtableDeep -InputObject $original
.OUTPUTS
    System.Collections.Hashtable - The copy of the input hashtable
#>
function Copy-HashtableDeep {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [hashtable]$InputObject
    )
    
    $clone = @{}
    foreach ($key in $InputObject.Keys) {
        if ($InputObject[$key] -is [hashtable]) {
            $clone[$key] = Copy-HashtableDeep -InputObject $InputObject[$key]
        }
        elseif ($InputObject[$key] -is [array]) {
            # Handle arrays of hashtables
            $array = @()
            foreach ($item in $InputObject[$key]) {
                if ($item -is [hashtable]) {
                    $array += Copy-HashtableDeep -InputObject $item
                }
                else {
                    $array += $item
                }
            }
            $clone[$key] = $array
        }
        else {
            $clone[$key] = $InputObject[$key]
        }
    }
    
    return $clone
}

<#
.SYNOPSIS
    Converts a JSON object to a hashtable.
.DESCRIPTION
    Recursively converts a JSON object (PSCustomObject) to a hashtable.
.PARAMETER InputObject
    The JSON object to convert.
.EXAMPLE
    $hashtable = ConvertFrom-JsonToHashtable -InputObject $jsonObject
.OUTPUTS
    System.Collections.Hashtable - The hashtable representation of the input object
#>
function ConvertFrom-JsonToHashtable {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
        [object]$InputObject
    )
    
    process {
        # Return non-object types as is
        if ($null -eq $InputObject -or
            $InputObject -is [bool] -or
            $InputObject -is [int] -or
            $InputObject -is [long] -or
            $InputObject -is [double] -or
            $InputObject -is [decimal] -or
            $InputObject -is [string]) {
            return $InputObject
        }
        
        # Handle arrays
        if ($InputObject -is [array]) {
            $array = @()
            foreach ($item in $InputObject) {
                $array += (ConvertFrom-JsonToHashtable -InputObject $item)
            }
            return $array
        }
        
        # Handle PSCustomObject (usual output from ConvertFrom-Json)
        if ($InputObject -is [System.Management.Automation.PSCustomObject]) {
            $hashtable = @{}
            $InputObject.PSObject.Properties | ForEach-Object {
                $hashtable[$_.Name] = (ConvertFrom-JsonToHashtable -InputObject $_.Value)
            }
            return $hashtable
        }
        
        # Default - return as is
        return $InputObject
    }
}

<#
.SYNOPSIS
    Gets a theme by name.
.DESCRIPTION
    Retrieves a theme by name, looking in built-in themes and 
    theme files in the themes directory.
.PARAMETER ThemeName
    The name of the theme to get.
.EXAMPLE
    $theme = Get-Theme -ThemeName "NeonCyberpunk"
.OUTPUTS
    System.Collections.Hashtable - The theme, or the default theme if not found
#>
function Get-Theme {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [ValidateNotNullOrEmpty()]
        [string]$ThemeName
    )
    
    return Invoke-WithErrorHandling -ScriptBlock {
        $themeToLoad = $null
        
        # Check built-in first
        if ($script:themePresets.ContainsKey($ThemeName)) {
            $themeToLoad = $script:themePresets[$ThemeName]
        } else {
            # Try loading from file
            $config = Get-AppConfig
            $themePath = Join-Path $config.ThemesDir "$ThemeName.json"
            if (Test-Path $themePath) {
                # Convert JSON object graph to nested hashtables for easier manipulation
                $jsonData = Get-Content -Path $themePath -Raw | ConvertFrom-Json
                $themeToLoad = ConvertFrom-JsonToHashtable -InputObject $jsonData
            }
        }
        
        # Get a deep copy of the default theme to merge into
        $mergedTheme = Copy-HashtableDeep -InputObject $script:defaultTheme
        
        # If a theme was found (built-in or custom), merge it over the default
        if ($themeToLoad) {
            $mergedTheme = Merge-ThemeRecursive -Base $mergedTheme -Overlay $themeToLoad
            # Ensure Name is correct, especially for file-loaded themes
            $mergedTheme.Name = $ThemeName
        } else {
            Write-Warning "Theme '$ThemeName' not found or failed to load. Using default."
            # mergedTheme is already a copy of default, just ensure Name is 'Default'
            $mergedTheme.Name = "Default"
        }
        
        return $mergedTheme # Return the merged theme
    } -ErrorContext "Loading theme '$ThemeName'" -Continue -DefaultValue (Copy-HashtableDeep -InputObject $script:defaultTheme)
}

<#
.SYNOPSIS
    Sets the current theme.
.DESCRIPTION
    Sets the current theme by name and applies it to the application.
.PARAMETER ThemeName
    The name of the theme to set.
.PARAMETER ThemeObject
    Optional theme object to set directly.
.EXAMPLE
    Set-CurrentTheme -ThemeName "NeonCyberpunk"
.EXAMPLE
    Set-CurrentTheme -ThemeObject $customTheme
.OUTPUTS
    System.Boolean - True if the theme was set successfully, False otherwise
#>
function Set-CurrentTheme {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$false, ParameterSetName="ByName")]
        [ValidateNotNullOrEmpty()]
        [string]$ThemeName,
        
        [Parameter(Mandatory=$false, ParameterSetName="ByObject")]
        [hashtable]$ThemeObject
    )
    
    try {
        $theme = $null
        
        if ($PSCmdlet.ParameterSetName -eq "ByName") {
            $theme = Get-Theme -ThemeName $ThemeName
        } else {
            $theme = $ThemeObject
            if (-not $theme.ContainsKey("Name")) {
                $theme.Name = "Custom"
            }
        }
        
        if ($theme) {
            $script:currentTheme = $theme
            # Colors are guaranteed to exist due to merging with default in Get-Theme
            $script:colors = $theme.Colors
            
            # Set ANSI usage if theme specifies it
            if ($theme.ContainsKey("UseAnsiColors")) {
                $script:useAnsiColors = $theme.UseAnsiColors
            }
            
            # Persist the choice
            $config = Get-AppConfig
            $config.DefaultTheme = $theme.Name
            Save-AppConfig -Config $config | Out-Null
            
            Write-Verbose "Theme set to '$($theme.Name)'"
            return $true
        }
        
        return $false
    } catch {
        Write-Warning "Error setting theme: $($_.Exception.Message)"
        return $false
    }
}

<#
.SYNOPSIS
    Gets the current theme.
.DESCRIPTION
    Returns the current theme or the default theme if none is set.
.EXAMPLE
    $theme = Get-CurrentTheme
.OUTPUTS
    System.Collections.Hashtable - The current theme
#>
function Get-CurrentTheme {
    [CmdletBinding()]
    param()
    
    if ($script:currentTheme) {
        return $script:currentTheme
    }
    
    # No current theme, return default
    return $script:defaultTheme
}

<#
.SYNOPSIS
    Gets a list of available themes.
.DESCRIPTION
    Returns a list of all available themes, including built-in and custom themes.
.EXAMPLE
    $themes = Get-AvailableThemes
.OUTPUTS
    System.Collections.ArrayList - A list of theme information objects
#>
function Get-AvailableThemes {
    [CmdletBinding()]
    param()
    
    # Return cached list if available
    if ($script:availableThemesCache) {
        return $script:availableThemesCache
    }
    
    $themes = [System.Collections.ArrayList]::new()
    
    # Add built-in themes first
    foreach ($presetName in $script:themePresets.Keys | Sort-Object) {
        # Ensure the preset itself is valid before adding
        if ($script:themePresets[$presetName] -is [hashtable]) {
            $themes.Add([PSCustomObject]@{ 
                Name = $presetName
                Type = "Built-in"
                Source = "System"
            }) | Out-Null
        } else {
            Write-Warning "Invalid theme preset found: $presetName"
        }
    }
    
    # Add custom themes from the themes directory
    $config = Get-AppConfig
    if (Test-Path $config.ThemesDir) {
        Get-ChildItem -Path $config.ThemesDir -Filter "*.json" | ForEach-Object {
            $themeName = $_.BaseName
            # Avoid listing built-ins twice if they exist as files
            if (-not $script:themePresets.ContainsKey($themeName)) {
                try {
                    $themeData = Get-Content -Path $_.FullName -Raw | ConvertFrom-Json
                    # Basic validation: check if it has a Name property at least
                    if ($themeData -is [PSCustomObject] -and $themeData.PSObject.Properties.Name -contains 'Name') {
                        $themes.Add([PSCustomObject]@{
                            Name = $themeName
                            Type = "Custom"
                            Source = if ($themeData.PSObject.Properties.Name -contains 'Author') {
                                $themeData.Author
                            } else {
                                "User"
                            }
                        }) | Out-Null
                    } else {
                        Write-Verbose "Skipping invalid theme file (missing Name?): $($_.Name)"
                    }
                } catch {
                    Write-Verbose "Error reading theme file $($_.Name): $($_.Exception.Message)"
                }
            }
        }
    }
    
    # Cache the result
    $script:availableThemesCache = $themes
    
    return $themes
}

<#
.SYNOPSIS
    Recursively merges two theme hashtables.
.DESCRIPTION
    Merges an overlay theme into a base theme, recursively handling nested hashtables.
.PARAMETER Base
    The base theme hashtable.
.PARAMETER Overlay
    The overlay theme hashtable to merge on top.
.EXAMPLE
    $merged = Merge-ThemeRecursive -Base $defaultTheme -Overlay $customTheme
.OUTPUTS
    System.Collections.Hashtable - The merged theme
#>
function Merge-ThemeRecursive {
    param($Base, $Overlay)
    
    $merged = Copy-HashtableDeep -InputObject $Base
    if ($null -eq $Overlay) { return $merged }
    
    foreach ($key in $Overlay.Keys) {
        if ($merged.ContainsKey($key) -and $merged[$key] -is [hashtable] -and $Overlay[$key] -is [hashtable]) {
            # Recurse for nested hashtables
            $merged[$key] = Merge-ThemeRecursive -Base $merged[$key] -Overlay $Overlay[$key]
        } else {
            # Overwrite or add the key from the overlay
            # Use deep copy for overlay values too, if they are hashtables
            $merged[$key] = if ($Overlay[$key] -is [hashtable]) {
                Copy-HashtableDeep -InputObject $Overlay[$key]
            } else {
                $Overlay[$key]
            }
        }
    }
    
    return $merged
}

<#
.SYNOPSIS
    Initializes the theme engine.
.DESCRIPTION
    Sets up the theme engine, loads available themes, and sets the default theme.
.EXAMPLE
    Initialize-ThemeEngine
.OUTPUTS
    Boolean - $true if initialization was successful, $false otherwise
#>
function Initialize-ThemeEngine {
    [CmdletBinding()]
    param()
    
    try {
        Write-AppLog "Initializing theme engine..." -Level INFO
        
        # Get config
        $config = Get-AppConfig
        
        # Reset theme-related variables
        $script:currentTheme = $null
        $script:colors = @{}
        $script:availableThemesCache = $null
        
        # Determine if the console supports ANSI colors
        try {
            # Check PowerShell version, Core usually supports ANSI
            $isPSCore = $PSVersionTable.PSEdition -eq 'Core'
            
            # Check if running in VS Code terminal which supports ANSI
            $isVSCode = $env:TERM_PROGRAM -eq 'vscode' -or $host.Name -match 'Visual Studio Code'
            
            # Check if running in Windows Terminal which supports ANSI
            $isWindowsTerminal = $env:WT_SESSION -ne $null
            
            # Set default ANSI support based on these checks
            $script:useAnsiColors = $isPSCore -or $isVSCode -or $isWindowsTerminal
            
            Write-AppLog "ANSI color support detected: $($script:useAnsiColors)" -Level DEBUG
        }
        catch {
            # If we can't determine, default to false
            $script:useAnsiColors = $false
            Write-AppLog "Failed to detect ANSI color support, defaulting to false" -Level WARNING
        }
        
        # Get built-in themes
        $availableThemes = @()
        foreach ($themeName in $script:themePresets.Keys) {
            $themeInfo = @{
                Name = $themeName
                Type = "Built-in"
                Source = "System"
                ThemeObject = $script:themePresets[$themeName]
            }
            $availableThemes += $themeInfo
        }
        
        # Look for custom themes in theme directory
        if (Test-Path -Path $config.ThemesDir -PathType Container) {
            $themeFiles = Get-ChildItem -Path $config.ThemesDir -Filter "*.json" -File
            
            foreach ($themeFile in $themeFiles) {
                try {
                    $themeContent = Get-Content -Path $themeFile.FullName -Raw | ConvertFrom-Json
                    
                    # Skip invalid theme files
                    if (-not $themeContent.Name) {
                        Write-AppLog "Skipping invalid theme file: $($themeFile.Name)" -Level WARNING
                        continue
                    }
                    
                    # Convert from JSON to hashtable
                    $themeHashtable = ConvertFrom-JsonToHashtable -InputObject $themeContent
                    
                    # Add to available themes
                    $themeInfo = @{
                        Name = $themeContent.Name
                        Type = "Custom"
                        Source = $themeFile.FullName
                        ThemeObject = $themeHashtable
                    }
                    
                    # Check if a theme with this name already exists
                    if (($availableThemes | Where-Object { $_.Name -eq $themeContent.Name }).Count -gt 0) {
                        Write-AppLog "Theme '$($themeContent.Name)' already exists, skipping: $($themeFile.Name)" -Level WARNING
                    }
                    else {
                        $availableThemes += $themeInfo
                        Write-AppLog "Loaded custom theme: $($themeContent.Name)" -Level DEBUG
                    }
                }
                catch {
                    Write-AppLog "Failed to load theme file: $($themeFile.Name). Error: $($_.Exception.Message)" -Level WARNING
                }
            }
        }
        
        # Cache available themes
        $script:availableThemesCache = $availableThemes
        
        # Set default theme
        $defaultThemeName = $config.DefaultTheme
        if (-not $defaultThemeName -or -not ($availableThemes | Where-Object { $_.Name -eq $defaultThemeName })) {
            $defaultThemeName = "Default"
            Write-AppLog "Default theme not found or not specified, using 'Default'" -Level WARNING
        }
        
        # Apply the theme
        $success = Set-CurrentTheme -ThemeName $defaultThemeName
        
        if ($success) {
            Write-AppLog "Theme engine initialized with theme: $defaultThemeName" -Level INFO
        }
        else {
            Write-AppLog "Failed to initialize theme engine with theme: $defaultThemeName" -Level ERROR
            # Fallback to hardcoded Default theme
            $script:currentTheme = $script:defaultTheme
            $script:colors = $script:defaultTheme.Colors
            $script:useAnsiColors = $script:defaultTheme.UseAnsiColors
        }
        
        return $success
    }
    catch {
        Handle-Error -ErrorRecord $_ -Context "Initializing theme engine" -Continue
        
        # Emergency fallback to ensure we have some theme
        $script:currentTheme = $script:defaultTheme
        $script:colors = $script:defaultTheme.Colors
        $script:useAnsiColors = $false
        
        return $false
    }
}

#endregion Theme Management Functions

#region Initialization Functions

<#
.SYNOPSIS
    Initializes the data environment for Project Tracker.
.DESCRIPTION
    Creates necessary directories and data files if they don't exist.
    Sets up default data structures with required headers.
.EXAMPLE
    Initialize-DataEnvironment
.OUTPUTS
    Boolean - $true if initialization was successful, $false otherwise
#>
function Initialize-DataEnvironment {
    [CmdletBinding()]
    param()
    
    try {
        Write-AppLog "Initializing data environment..." -Level INFO
        
        # Get config (creates default if not exists)
        $config = Get-AppConfig
        
        # Create base data directory if it doesn't exist
        if (-not (Test-Path -Path $config.BaseDataDir -PathType Container)) {
            Write-AppLog "Creating base data directory: $($config.BaseDataDir)" -Level INFO
            New-Item -Path $config.BaseDataDir -ItemType Directory -Force | Out-Null
        }
        
        # Ensure data files exist with required headers
        $dataFiles = @(
            @{
                Path = $config.ProjectsFullPath
                Headers = $config.ProjectsHeaders
            },
            @{
                Path = $config.TodosFullPath
                Headers = $config.TodosHeaders
            },
            @{
                Path = $config.TimeLogFullPath
                Headers = $config.TimeHeaders
            },
            @{
                Path = $config.NotesFullPath
                Headers = $config.NotesHeaders
            },
            @{
                Path = $config.CommandsFullPath
                Headers = $config.CommandsHeaders
            }
        )
        
        foreach ($file in $dataFiles) {
            if (-not (Test-Path -Path $file.Path)) {
                Write-AppLog "Creating data file: $($file.Path)" -Level INFO
                
                # Create directory if it doesn't exist
                $directory = Split-Path -Path $file.Path -Parent
                if (-not (Test-Path -Path $directory -PathType Container)) {
                    New-Item -Path $directory -ItemType Directory -Force | Out-Null
                }
                
                # Create an empty array of custom objects with the required headers
                $emptyData = @()
                
                # Create the file with headers only (no data rows)
                $emptyData | Export-Csv -Path $file.Path -NoTypeInformation
            }
        }
        
        # Create themes directory if it doesn't exist
        if (-not (Test-Path -Path $config.ThemesDir -PathType Container)) {
            Write-AppLog "Creating themes directory: $($config.ThemesDir)" -Level INFO
            New-Item -Path $config.ThemesDir -ItemType Directory -Force | Out-Null
        }
        
        Write-AppLog "Data environment initialized successfully" -Level INFO
        return $true
    }
    catch {
        Handle-Error -ErrorRecord $_ -Context "Initializing data environment" -Continue
        return $false
    }
}

#endregion Initialization Functions

#region Data Functions

<#
.SYNOPSIS
    Ensures a directory exists, creating it if necessary.
.DESCRIPTION
    Checks if the specified directory exists and creates it if it doesn't.
.PARAMETER Path
    The path to the directory.
.EXAMPLE
    Ensure-DirectoryExists -Path "C:\ProjectData"
.OUTPUTS
    System.Boolean - True if the directory exists or was created, False if creation failed
#>
function Ensure-DirectoryExists {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Path
    )
    
    if (-not (Test-Path $Path -PathType Container)) {
        try {
            New-Item -ItemType Directory -Path $Path -Force | Out-Null
            Write-Verbose "Created directory: $Path"
            return $true
        } catch {
            Write-Host "ERROR creating directory '$Path': $($_.Exception.Message)" -ForegroundColor $script:colors.Error
            return $false
        }
    }
    return $true
}

<#
.SYNOPSIS
    Gets entity data from a CSV file.
.DESCRIPTION
    Reads entity data from a CSV file, handling validation, defaults, and error conditions.
.PARAMETER FilePath
    The path to the CSV file.
.PARAMETER RequiredHeaders
    Optional array of required headers.
.PARAMETER DefaultValues
    Optional hashtable of default values for missing headers.
.PARAMETER CreateIfNotExists
    If specified, creates the file with headers if it doesn't exist.
.EXAMPLE
    $projects = Get-EntityData -FilePath $projectsFile -RequiredHeaders $projectsHeaders -CreateIfNotExists
.OUTPUTS
    System.Object[] - An array of entity objects
#>
function Get-EntityData {
    param(
        [Parameter(Mandatory=$true)]
        [string]$FilePath,
        
        [Parameter(Mandatory=$false)]
        [string[]]$RequiredHeaders,
        
        [Parameter(Mandatory=$false)]
        [hashtable]$DefaultValues = @{},
        
        [Parameter(Mandatory=$false)]
        [switch]$CreateIfNotExists
    )
    
    # Check if file exists
    if (-not (Test-Path $FilePath)) {
        Write-Verbose "File not found: '$FilePath'."
        
        if ($CreateIfNotExists -and $RequiredHeaders -and $RequiredHeaders.Count -gt 0) {
            # Create directory if it doesn't exist
            Ensure-DirectoryExists -Path (Split-Path $FilePath -Parent) | Out-Null
            
            # Create the file with headers
            $RequiredHeaders -join "," | Out-File $FilePath -Encoding utf8 -ErrorAction Stop
            Write-Verbose "Created file with headers: '$FilePath'."
            return @() # Return empty array as no data exists yet
        }
        
        return @() # Return empty array if file doesn't exist
    }
    
    try {
        # Always wrap Import-Csv result in @() to ensure it's an array
        $data = @(Import-Csv -Path $FilePath -ErrorAction Stop)
        
        # Check and add missing headers/properties if needed
        if ($RequiredHeaders -and $RequiredHeaders.Count -gt 0 -and $data.Count -gt 0) {
            $currentHeaders = $data[0].PSObject.Properties.Name
            $missingHeaders = $RequiredHeaders | Where-Object { $currentHeaders -notcontains $_ }
            
            if ($missingHeaders.Count -gt 0) {
                Write-Verbose "File is missing columns: $($missingHeaders -join ', '). Adding them."
                
                foreach ($item in $data) {
                    foreach ($header in $missingHeaders) {
                        $defaultValue = if ($DefaultValues.ContainsKey($header)) { $DefaultValues[$header] } else { "" }
                        Add-Member -InputObject $item -MemberType NoteProperty -Name $header -Value $defaultValue -Force
                    }
                }
            }
        }
        
        return $data
    }
    catch {
        Write-Host "ERROR: Failed to load data from '$FilePath': $($_.Exception.Message)" -ForegroundColor $script:colors.Error
        return @() # Return empty array on error
    }
}

<#
.SYNOPSIS
    Saves entity data to a CSV file.
.DESCRIPTION
    Writes entity data to a CSV file, creating a backup first, and handling errors.
.PARAMETER Data
    The array of entity objects to save.
.PARAMETER FilePath
    The path to the CSV file.
.PARAMETER RequiredHeaders
    Optional array of headers to include in the output.
.EXAMPLE
    Save-EntityData -Data $projects -FilePath $projectsFile -RequiredHeaders $projectsHeaders
.OUTPUTS
    System.Boolean - True if the save was successful, False otherwise
#>
function Save-EntityData {
    param(
        [Parameter(Mandatory=$true)]
        [array]$Data,
        
        [Parameter(Mandatory=$true)]
        [string]$FilePath,
        
        [Parameter(Mandatory=$false)]
        [string[]]$RequiredHeaders
    )
    
    $backupPath = "$FilePath.bak"
    try {
        # Create backup of existing file
        if (Test-Path $FilePath) {
            Copy-Item -Path $FilePath -Destination $backupPath -Force -ErrorAction SilentlyContinue
        }
        
        # Ensure directory exists
        Ensure-DirectoryExists -Path (Split-Path $FilePath -Parent) | Out-Null
        
        # Save data with the specified headers (if provided)
        if ($RequiredHeaders -and $RequiredHeaders.Count -gt 0) {
            $Data | Select-Object -Property $RequiredHeaders | Export-Csv -Path $FilePath -NoTypeInformation -Encoding UTF8 -ErrorAction Stop
        } else {
            $Data | Export-Csv -Path $FilePath -NoTypeInformation -Encoding UTF8 -ErrorAction Stop
        }
        
        return $true
    }
    catch {
        Write-Host "ERROR saving data to '$FilePath': $($_.Exception.Message)" -ForegroundColor $script:colors.Error
        
        # Try to restore from backup if available
        if (Test-Path $backupPath) {
            Copy-Item -Path $backupPath -Destination $FilePath -Force -ErrorAction SilentlyContinue
            Write-Verbose "Restored file from backup."
        }
        
        return $false
    }
}

<#
.SYNOPSIS
    Updates the cumulative hours for a project.
.DESCRIPTION
    Calculates and updates the cumulative hours for a project based on time entries.
.PARAMETER Nickname
    The nickname of the project to update.
.EXAMPLE
    Update-CumulativeHours -Nickname "WEBSITE"
#>
function Update-CumulativeHours {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Nickname
    )
    
    if ([string]::IsNullOrWhiteSpace($Nickname)) {
        Write-Verbose "Update-CumulativeHours: Empty nickname."
        return
    }
    
    $config = Get-AppConfig
    $projects = @(Get-EntityData -FilePath $config.ProjectsFullPath)
    $project = $projects | Where-Object { $_.Nickname -eq $Nickname } | Select-Object -First 1
    
    if (-not $project) {
        Write-Verbose "Update-CumulativeHours: Project '$Nickname' not found."
        return
    }
    
    $timeEntries = @(Get-EntityData -FilePath $config.TimeLogFullPath | Where-Object { $_.Nickname -eq $Nickname })
    
    $totalHours = 0.0
    foreach ($entry in $timeEntries) {
        $dailyTotal = 0.0
        $weekDays = @("MonHours", "TueHours", "WedHours", "ThuHours", "FriHours", "SatHours", "SunHours")
        
        foreach ($day in $weekDays) {
            if ($entry.PSObject.Properties.Name -contains $day -and -not [string]::IsNullOrWhiteSpace($entry.$day)) {
                $hours = 0.0
                if ([double]::TryParse($entry.$day, [ref]$hours)) {
                    $dailyTotal += $hours
                }
            }
        }
        
        # If daily breakdown is empty but total exists, use the total
        if ($entry.PSObject.Properties.Name -contains 'Total' -and
            -not [string]::IsNullOrWhiteSpace($entry.Total) -and
            $dailyTotal -eq 0.0) {
            $hours = 0.0
            if ([double]::TryParse($entry.Total, [ref]$hours)) {
                $totalHours += $hours
            }
        } else {
            $totalHours += $dailyTotal
        }
    }
    
    # Update the project's cumulative hours
    $project.CumulativeHrs = $totalHours.ToString("F2")
    Save-EntityData -Data $projects -FilePath $config.ProjectsFullPath -RequiredHeaders $config.ProjectsHeaders | Out-Null
    
    Write-Verbose "Updated cumulative hours for project '$Nickname': $($project.CumulativeHrs) hours"
}

<#
.SYNOPSIS
    Gets an entity by ID.
.DESCRIPTION
    Retrieves an entity from a CSV file by its ID field.
.PARAMETER FilePath
    The path to the CSV file.
.PARAMETER ID
    The ID of the entity to retrieve.
.PARAMETER IDField
    The name of the ID field. Default is "ID".
.EXAMPLE
    $todoItem = Get-EntityById -FilePath $todosFile -ID "12345" -IDField "ID"
.OUTPUTS
    System.Object - The entity object, or $null if not found
#>
function Get-EntityById {
    param(
        [Parameter(Mandatory=$true)]
        [string]$FilePath,
        
        [Parameter(Mandatory=$true)]
        [string]$ID,
        
        [Parameter(Mandatory=$false)]
        [string]$IDField = "ID"
    )
    
    try {
        $entities = @(Get-EntityData -FilePath $FilePath)
        return $entities | Where-Object { $_.$IDField -eq $ID } | Select-Object -First 1
    }
    catch {
        Write-Error "Failed to get entity by ID: $($_.Exception.Message)"
        return $null
    }
}

<#
.SYNOPSIS
    Updates an entity by ID.
.DESCRIPTION
    Updates an entity in a CSV file by its ID field.
.PARAMETER FilePath
    The path to the CSV file.
.PARAMETER ID
    The ID of the entity to update.
.PARAMETER UpdatedEntity
    The updated entity object.
.PARAMETER IDField
    The name of the ID field. Default is "ID".
.PARAMETER RequiredHeaders
    Optional array of headers to include in the output.
.EXAMPLE
    Update-EntityById -FilePath $todosFile -ID "12345" -UpdatedEntity $updatedTodo -RequiredHeaders $todoHeaders
.OUTPUTS
    System.Boolean - True if the update was successful, False otherwise
#>
function Update-EntityById {
    param(
        [Parameter(Mandatory=$true)]
        [string]$FilePath,
        
        [Parameter(Mandatory=$true)]
        [string]$ID,
        
        [Parameter(Mandatory=$true)]
        [object]$UpdatedEntity,
        
        [Parameter(Mandatory=$false)]
        [string]$IDField = "ID",
        
        [Parameter(Mandatory=$false)]
        [string[]]$RequiredHeaders
    )
    
    try {
        $entities = @(Get-EntityData -FilePath $FilePath)
        $updated = @()
        $found = $false
        
        foreach ($entity in $entities) {
            if ($entity.$IDField -eq $ID) {
                $updated += $UpdatedEntity
                $found = $true
            } else {
                $updated += $entity
            }
        }
        
        if (-not $found) {
            Write-Warning "Entity with ID '$ID' not found."
            return $false
        }
        
        return Save-EntityData -Data $updated -FilePath $FilePath -RequiredHeaders $RequiredHeaders
    }
    catch {
        Write-Error "Failed to update entity: $($_.Exception.Message)"
        return $false
    }
}

<#
.SYNOPSIS
    Removes an entity by ID.
.DESCRIPTION
    Removes an entity from a CSV file by its ID field.
.PARAMETER FilePath
    The path to the CSV file.
.PARAMETER ID
    The ID of the entity to remove.
.PARAMETER IDField
    The name of the ID field. Default is "ID".
.PARAMETER RequiredHeaders
    Optional array of headers to include in the output.
.EXAMPLE
    Remove-EntityById -FilePath $todosFile -ID "12345" -RequiredHeaders $todoHeaders
.OUTPUTS
    System.Boolean - True if the removal was successful, False otherwise
#>
function Remove-EntityById {
    param(
        [Parameter(Mandatory=$true)]
        [string]$FilePath,
        
        [Parameter(Mandatory=$true)]
        [string]$ID,
        
        [Parameter(Mandatory=$false)]
        [string]$IDField = "ID",
        
        [Parameter(Mandatory=$false)]
        [string[]]$RequiredHeaders
    )
    
    try {
        $entities = @(Get-EntityData -FilePath $FilePath)
        $updated = $entities | Where-Object { $_.$IDField -ne $ID }
        
        if ($updated.Count -eq $entities.Count) {
            Write-Warning "Entity with ID '$ID' not found."
            return $false
        }
        
        return Save-EntityData -Data $updated -FilePath $FilePath -RequiredHeaders $RequiredHeaders
    }
    catch {
        Write-Error "Failed to remove entity: $($_.Exception.Message)"
        return $false
    }
}

<#
.SYNOPSIS
    Creates a new entity.
.DESCRIPTION
    Creates a new entity in a CSV file with the specified data.
.PARAMETER FilePath
    The path to the CSV file.
.PARAMETER EntityData
    The entity data to add.
.PARAMETER RequiredHeaders
    Optional array of headers to include in the output.
.EXAMPLE
    Create-Entity -FilePath $todosFile -EntityData $newTodo -RequiredHeaders $todoHeaders
.OUTPUTS
    System.Boolean - True if the creation was successful, False otherwise
#>
function Create-Entity {
    param(
        [Parameter(Mandatory=$true)]
        [string]$FilePath,
        
        [Parameter(Mandatory=$true)]
        [object]$EntityData,
        
        [Parameter(Mandatory=$false)]
        [string[]]$RequiredHeaders
    )
    
    try {
        $entities = @(Get-EntityData -FilePath $FilePath)
        $updated = $entities + $EntityData
        
        return Save-EntityData -Data $updated -FilePath $FilePath -RequiredHeaders $RequiredHeaders
    }
    catch {
        Write-Error "Failed to create entity: $($_.Exception.Message)"
        return $false
    }
}

#endregion Data Functions

#region Helper Functions

<#
.SYNOPSIS
    Generates a new ID.
.DESCRIPTION
    Generates a new ID in various formats for use in entities.
.PARAMETER Format
    The format of the ID to generate. Options: "GUID", "Short", "Full", "Custom"
.PARAMETER CustomFormat
    A custom format string to use when Format is "Custom".
.EXAMPLE
    $id = New-ID -Format "GUID"
.EXAMPLE
    $id = New-ID -Format "Custom" -CustomFormat "PRJ-{0:yyyyMMdd}-{1:D4}" # Projects-20240301-0001
.OUTPUTS
    System.String - The generated ID
#>
function New-ID {
    param(
        [Parameter(Mandatory=$false)]
        [ValidateSet("GUID", "Short", "Full", "Custom")]
        [string]$Format = "GUID",
        
        [Parameter(Mandatory=$false)]
        [string]$CustomFormat
    )
    
    switch ($Format) {
        "GUID" {
            return [guid]::NewGuid().ToString()
        }
        "Short" {
            return [guid]::NewGuid().ToString().Substring(0, 8)
        }
        "Full" {
            return [guid]::NewGuid().ToString("D").ToUpper()
        }
        "Custom" {
            if ([string]::IsNullOrEmpty($CustomFormat)) {
                throw "CustomFormat is required when Format is 'Custom'"
            }
            
            $now = Get-Date
            $random = Get-Random -Minimum 1 -Maximum 10000
            return [string]::Format($CustomFormat, $now, $random)
        }
    }
}

<#
.SYNOPSIS
    Reads user input with validation.
.DESCRIPTION
    Prompts the user for input and validates it against a validator scriptblock.
.PARAMETER Prompt
    The prompt text to display.
.PARAMETER Validator
    Optional scriptblock that validates the input and returns a boolean.
.PARAMETER ErrorMessage
    Optional error message to display when validation fails.
.PARAMETER DefaultValue
    Optional default value to use when the user enters nothing.
.PARAMETER HideInput
    If specified, the input is masked (e.g., for passwords).
.PARAMETER AllowEmpty
    If specified, empty input is allowed.
.EXAMPLE
    $name = Read-UserInput -Prompt "Enter your name" -Validator { param($input) $input.Length -gt 0 } -ErrorMessage "Name cannot be empty"
.OUTPUTS
    System.String - The user input
#>
function Read-UserInput {
    param(
        [Parameter(Mandatory=$false)]
        [string]$Prompt = "",
        
        [Parameter(Mandatory=$false)]
        [scriptblock]$Validator = { $true },
        
        [Parameter(Mandatory=$false)]
        [string]$ErrorMessage = "Invalid input. Please try again.",
        
        [Parameter(Mandatory=$false)]
        $DefaultValue = $null,
        
        [Parameter(Mandatory=$false)]
        [switch]$HideInput,
        
        [Parameter(Mandatory=$false)]
        [switch]$AllowEmpty
    )
    
    $isValid = $false
    $input = $null
    
    while (-not $isValid) {
        # Display prompt
        if (-not [string]::IsNullOrEmpty($Prompt)) {
            if ($DefaultValue) {
                Write-Host "$Prompt [Default: $DefaultValue] " -ForegroundColor $script:colors.Accent2 -NoNewline
            } else {
                Write-Host "$Prompt " -ForegroundColor $script:colors.Accent2 -NoNewline
            }
        }
        
        # Get input
        if ($HideInput) {
            $secureString = Read-Host -AsSecureString
            $ptr = [System.Runtime.InteropServices.Marshal]::SecureStringToGlobalAllocUnicode($secureString)
            $input = [System.Runtime.InteropServices.Marshal]::PtrToStringUni($ptr)
            [System.Runtime.InteropServices.Marshal]::ZeroFreeGlobalAllocUnicode($ptr)
        } else {
            $input = Read-Host
        }
        
        # Check for default value
        if ([string]::IsNullOrWhiteSpace($input) -and $null -ne $DefaultValue) {
            $input = $DefaultValue
        }
        
        # Validate input
        if ([string]::IsNullOrWhiteSpace($input) -and -not $AllowEmpty) {
            Write-ColorText "Input cannot be empty." -ForegroundColor $script:colors.Warning
            continue
        }
        
        try {
            $isValid = & $Validator $input
            if (-not $isValid) {
                Write-ColorText $ErrorMessage -ForegroundColor $script:colors.Warning
            }
        } catch {
            Write-ColorText "Validation error: $($_.Exception.Message)" -ForegroundColor $script:colors.Error
            $isValid = $false
        }
    }
    
    return $input
}

<#
.SYNOPSIS
    Asks for confirmation of an action.
.DESCRIPTION
    Prompts the user to confirm an action with customizable confirm/reject texts.
.PARAMETER ActionDescription
    Description of the action to confirm.
.PARAMETER ConfirmText
    The text that confirms the action. Default is "Yes".
.PARAMETER RejectText
    The text that rejects the action. Default is "No".
.EXAMPLE
    if (Confirm-Action -ActionDescription "Are you sure you want to delete this item?") {
        # Delete the item
    }
.OUTPUTS
    System.Boolean - True if the action was confirmed, False otherwise
#>
function Confirm-Action {
    param(
        [Parameter(Mandatory=$true)]
        [string]$ActionDescription,
        
        [Parameter(Mandatory=$false)]
        [string]$ConfirmText = "Yes",
        
        [Parameter(Mandatory=$false)]
        [string]$RejectText = "No"
    )
    
    Write-ColorText $ActionDescription -ForegroundColor $script:colors.Warning
    Write-Host "Type '$ConfirmText' to confirm, or anything else to cancel: " -ForegroundColor $script:colors.Accent2 -NoNewline
    $response = Read-Host
    
    return $response -eq $ConfirmText
}

<#
.SYNOPSIS
    Creates a new menu items array.
.DESCRIPTION
    Creates a simple array to store menu items.
.EXAMPLE
    $menuItems = New-MenuItems
.OUTPUTS
    System.Object[] - An empty array for menu items
#>
function New-MenuItems {
    return @()
}

<#
.SYNOPSIS
    Converts a priority string to an integer for sorting.
.DESCRIPTION
    Converts a priority string (High, Normal, Low) to an integer value for sorting.
.PARAMETER Priority
    The priority string to convert.
.EXAMPLE
    $sortedTodos = $todos | Sort-Object { Convert-PriorityToInt -Priority $_.Importance }
.OUTPUTS
    System.Int32 - The priority as an integer (1=High, 2=Normal, 3=Low, 4=Unknown)
#>
function Convert-PriorityToInt {
    param($Priority)
    
    # Handle null or empty input first
    if ([string]::IsNullOrWhiteSpace($Priority)) {
        return 4 # Assign lowest priority (sorts last) if null/empty
    }
    
    # Now it's safe to call ToLower()
    switch ($Priority.ToLower()) {
        'high'   { return 1 }
        'normal' { return 2 }
        'low'    { return 3 }
        default  { return 4 } # Unknown string priorities also sort last
    }
}

#endregion Helper Functions

#region Date Functions

<#
.SYNOPSIS
    Parses a date input in various formats.
.DESCRIPTION
    Attempts to parse a date input string in various formats, returning
    a standardized internal date format.
.PARAMETER InputDate
    The date string to parse.
.PARAMETER AllowEmptyForToday
    If specified and input is empty, returns today's date.
.PARAMETER DefaultFormat
    The format to return the date in. Default is "yyyyMMdd".
.PARAMETER DisplayFormat
    The display format from the configuration.
.EXAMPLE
    $date = Parse-DateInput -InputDate "04/15/2024" -AllowEmptyForToday
.OUTPUTS
    System.String - The parsed date in the specified format, or null if parsing failed
#>
function Parse-DateInput {
    param(
        [string]$InputDate,
        [switch]$AllowEmptyForToday,
        [string]$DefaultFormat = "yyyyMMdd",  # Default internal storage format
        [string]$DisplayFormat = $script:config.displayDateFormat
    )
    
    if ([string]::IsNullOrWhiteSpace($InputDate)) {
        if ($AllowEmptyForToday) { 
            return (Get-Date).ToString($DefaultFormat) 
        }
        else { 
            Write-Host "Date input cannot be empty." -ForegroundColor $script:colors.Error
            return $null 
        }
    }
    
    if ($InputDate -in @("0", "exit", "cancel")) { 
        return "CANCEL" 
    }
    
    $parsedDate = $null
    $formatsToTry = @(
        "yyyyMMdd",
        "M/d/yyyy",
        "MM/dd/yyyy",
        "yyyy-MM-dd"
        # Add other common formats if needed
    )
    
    foreach ($format in $formatsToTry) {
        try {
            $parsedDate = [datetime]::ParseExact($InputDate, $format, $null)
            break # Stop on first successful parse
        } catch { 
            $parsedDate = $null 
        }
    }
    
    # Try general PowerShell parsing (last resort)
    if ($null -eq $parsedDate) {
        try { 
            $parsedDate = Get-Date $InputDate -ErrorAction SilentlyContinue 
        } catch { 
            $parsedDate = $null 
        }
    }
    
    if ($parsedDate -is [datetime]) {
        return $parsedDate.ToString($DefaultFormat) # Return in consistent internal format
    } else {
        Write-Host "Invalid date format. Please use YYYYMMDD, MM/DD/YYYY, or YYYY-MM-DD." -ForegroundColor $script:colors.Error
        return $null
    }
}

<#
.SYNOPSIS
    Converts a display date to the internal date format.
.DESCRIPTION
    Converts a date from the display format to the internal storage format.
.PARAMETER DisplayDate
    The date string in display format.
.PARAMETER InternalFormat
    The internal format to return the date in. Default is "yyyyMMdd".
.EXAMPLE
    $internalDate = Convert-DisplayDateToInternal -DisplayDate "04/15/2024"
.OUTPUTS
    System.String - The date in internal format, or null if conversion failed
#>
function Convert-DisplayDateToInternal {
    param(
        [string]$DisplayDate,
        [string]$InternalFormat = "yyyyMMdd" # Assuming internal format is YYYYMMDD
    )
    
    if ([string]::IsNullOrWhiteSpace($DisplayDate)) { 
        return $null 
    }
    
    try {
        $displayFormat = $script:config.displayDateFormat
        $parsedDate = [datetime]::ParseExact($DisplayDate, $displayFormat, $null)
        return $parsedDate.ToString($InternalFormat)
    } catch {
        # Fallback: Try parsing generically if ParseExact fails
        try {
            $parsedDate = [datetime]::Parse($DisplayDate)
            return $parsedDate.ToString($InternalFormat)
        } catch {
            Write-Warning "Could not convert display date '$DisplayDate' to internal format."
            return $null # Return null on failure
        }
    }
}

<#
.SYNOPSIS
    Converts an internal date to the display format.
.DESCRIPTION
    Converts a date from the internal storage format to the display format.
.PARAMETER InternalDate
    The date string in internal format.
.PARAMETER DisplayFormat
    The display format to return the date in. Default is from config.
.PARAMETER InternalFormat
    The internal format the date is in. Default is "yyyyMMdd".
.EXAMPLE
    $displayDate = Convert-InternalDateToDisplay -InternalDate "20240415"
.OUTPUTS
    System.String - The date in display format, or the original string if conversion failed
#>
function Convert-InternalDateToDisplay {
    param(
        [string]$InternalDate,
        [string]$DisplayFormat = $script:config.displayDateFormat,
        [string]$InternalFormat = "yyyyMMdd" # Assuming internal format is YYYYMMDD
    )
    
    if ([string]::IsNullOrWhiteSpace($InternalDate)) { 
        return "" 
    }
    
    try {
        $parsedDate = [datetime]::ParseExact($InternalDate, $InternalFormat, $null)
        return $parsedDate.ToString($DisplayFormat)
    } catch {
        # Fallback: Try parsing generically if ParseExact fails
        try {
            $parsedDate = [datetime]::Parse($InternalDate)
            return $parsedDate.ToString($DisplayFormat)
        } catch {
            Write-Warning "Could not convert internal date '$InternalDate' to display format."
            return $InternalDate # Return original if conversion fails
        }
    }
}

<#
.SYNOPSIS
    Gets a relative description of a date.
.DESCRIPTION
    Returns a human-readable description of a date relative to a reference date.
.PARAMETER Date
    The date to describe.
.PARAMETER ReferenceDate
    The reference date to compare against. Default is today.
.EXAMPLE
    $description = Get-RelativeDateDescription -Date (Get-Date).AddDays(1) # "Tomorrow"
.OUTPUTS
    System.String - The relative date description
#>
function Get-RelativeDateDescription {
    param(
        [DateTime]$Date,
        [DateTime]$ReferenceDate = (Get-Date).Date # Compare against date part only
    )
    
    $diff = ($Date.Date - $ReferenceDate).Days
    
    if ($diff -eq 0) { return "Today" }
    if ($diff -eq 1) { return "Tomorrow" }
    if ($diff -eq -1) { return "Yesterday" }
    if ($diff -gt 1 -and $diff -le 7) { return "In $diff days" }
    if ($diff -lt -1 -and $diff -ge -7) { return "$([Math]::Abs($diff)) days ago" }
    
    # Return formatted date for anything further out
    return $Date.ToString($script:config.displayDateFormat)
}

<#
.SYNOPSIS
    Gets a date input from the user.
.DESCRIPTION
    Prompts the user for a date, validating the input and returning it
    in the internal format.
.PARAMETER PromptText
    The prompt text to display.
.PARAMETER DefaultValue
    Optional default value to use when the user enters nothing.
.PARAMETER AllowEmptyForToday
    If specified and input is empty, returns today's date.
.PARAMETER AllowCancel
    If specified, allows the user to cancel by entering 0.
.EXAMPLE
    $dueDate = Get-DateInput -PromptText "Enter due date" -AllowEmptyForToday -AllowCancel
.OUTPUTS
    System.String - The date in internal format, or null if cancelled or invalid
#>
function Get-DateInput {
    param(
        [string]$PromptText,
        [string]$DefaultValue = "",
        [switch]$AllowEmptyForToday,
        [switch]$AllowCancel
    )
    
    while ($true) {
        if ([string]::IsNullOrEmpty($DefaultValue)) {
            Write-Host "$PromptText " -ForegroundColor $script:colors.Accent2 -NoNewline
        } else {
            Write-Host "$PromptText [Default: $(Convert-InternalDateToDisplay -InternalDate $DefaultValue)] " -ForegroundColor $script:colors.Accent2 -NoNewline
        }
        
        $input = Read-Host
        
        # Handle empty input
        if ([string]::IsNullOrWhiteSpace($input)) {
            if ($AllowEmptyForToday) {
                return (Get-Date).ToString("yyyyMMdd")
            }
            elseif (-not [string]::IsNullOrEmpty($DefaultValue)) {
                return $DefaultValue
            }
            else {
                Write-Host "Date cannot be empty." -ForegroundColor $script:colors.Error
                continue
            }
        }
        
        # Handle cancel option
        if ($input -eq '0' -and $AllowCancel) {
            return $null
        }
        
        # Parse the date
        $parsedDate = Parse-DateInput -InputDate $input
        if ($parsedDate -eq "CANCEL" -and $AllowCancel) {
            return $null
        }
        elseif ($parsedDate) {
            return $parsedDate
        }
        # If parse failed, the error was already displayed - loop continues
    }
}

<#
.SYNOPSIS
    Gets the first day of the week for a date.
.DESCRIPTION
    Returns the date of the first day of the week containing the specified date.
.PARAMETER Date
    The date to get the week start for.
.PARAMETER StartDay
    The day of the week that starts the week. Default is from config.
.EXAMPLE
    $weekStart = Get-FirstDayOfWeek -Date (Get-Date) -StartDay [DayOfWeek]::Monday
.OUTPUTS
    System.DateTime - The date of the first day of the week
#>
function Get-FirstDayOfWeek {
    param(
        [DateTime]$Date,
        [DayOfWeek]$StartDay = $script:config.calendarStartDay
    )
    
    $diff = [int]$Date.DayOfWeek - [int]$StartDay
    if ($diff -lt 0) { $diff += 7 }
    
    return $Date.AddDays(-$diff)
}

<#
.SYNOPSIS
    Gets the week number of a date.
.DESCRIPTION
    Returns the ISO 8601 week number for a date.
.PARAMETER Date
    The date to get the week number for.
.EXAMPLE
    $weekNumber = Get-WeekNumber -Date (Get-Date)
.OUTPUTS
    System.Int32 - The week number (1-53)
#>
function Get-WeekNumber {
    param(
        [DateTime]$Date
    )
    
    $cal = [System.Globalization.CultureInfo]::CurrentCulture.Calendar
    return $cal.GetWeekOfYear($Date, [System.Globalization.CalendarWeekRule]::FirstFourDayWeek, [DayOfWeek]::Monday)
}

<#
.SYNOPSIS
    Gets the name of a month.
.DESCRIPTION
    Returns the localized name of a month based on its number.
.PARAMETER Month
    The month number (1-12).
.EXAMPLE
    $monthName = Get-MonthName -Month 4 # "April"
.OUTPUTS
    System.String - The month name
#>



###These should go before the export module-member stuff

#region Initialization Functions

<#
.SYNOPSIS
    Initializes the data environment for Project Tracker.
.DESCRIPTION
    Creates necessary directories and data files if they don't exist.
    Sets up default data structures with required headers.
.EXAMPLE
    Initialize-DataEnvironment
.OUTPUTS
    Boolean - $true if initialization was successful, $false otherwise
#>
function Initialize-DataEnvironment {
    [CmdletBinding()]
    param()
    
    try {
        Write-AppLog "Initializing data environment..." -Level INFO
        
        # Get config (creates default if not exists)
        $config = Get-AppConfig
        
        # Create base data directory if it doesn't exist
        if (-not (Test-Path -Path $config.BaseDataDir -PathType Container)) {
            Write-AppLog "Creating base data directory: $($config.BaseDataDir)" -Level INFO
            New-Item -Path $config.BaseDataDir -ItemType Directory -Force | Out-Null
        }
        
        # Ensure data files exist with required headers
        $dataFiles = @(
            @{
                Path = $config.ProjectsFullPath
                Headers = $config.ProjectsHeaders
            },
            @{
                Path = $config.TodosFullPath
                Headers = $config.TodosHeaders
            },
            @{
                Path = $config.TimeLogFullPath
                Headers = $config.TimeHeaders
            },
            @{
                Path = $config.NotesFullPath
                Headers = $config.NotesHeaders
            },
            @{
                Path = $config.CommandsFullPath
                Headers = $config.CommandsHeaders
            }
        )
        
        foreach ($file in $dataFiles) {
            if (-not (Test-Path -Path $file.Path)) {
                Write-AppLog "Creating data file: $($file.Path)" -Level INFO
                
                # Create directory if it doesn't exist
                $directory = Split-Path -Path $file.Path -Parent
                if (-not (Test-Path -Path $directory -PathType Container)) {
                    New-Item -Path $directory -ItemType Directory -Force | Out-Null
                }
                
                # Create an empty array of custom objects with the required headers
                $emptyData = @()
                $emptyObject = [PSCustomObject]@{}
                
                # Add each header as an empty property
                foreach ($header in $file.Headers) {
                    $emptyObject | Add-Member -NotePropertyName $header -NotePropertyValue ""
                }
                
                # Create the file with headers only (no data rows)
                $emptyData | Export-Csv -Path $file.Path -NoTypeInformation
            }
        }
        
        # Create themes directory if it doesn't exist
        if (-not (Test-Path -Path $config.ThemesDir -PathType Container)) {
            Write-AppLog "Creating themes directory: $($config.ThemesDir)" -Level INFO
            New-Item -Path $config.ThemesDir -ItemType Directory -Force | Out-Null
        }
        
        Write-AppLog "Data environment initialized successfully" -Level INFO
        return $true
    }
    catch {
        Handle-Error -ErrorRecord $_ -Context "Initializing data environment" -Continue
        return $false
    }
}

<#
.SYNOPSIS
    Initializes the theme engine for Project Tracker.
.DESCRIPTION
    Sets up the theme engine, loads available themes, and sets the default theme.
.EXAMPLE
    Initialize-ThemeEngine
.OUTPUTS
    Boolean - $true if initialization was successful, $false otherwise
#>
function Initialize-ThemeEngine {
    [CmdletBinding()]
    param()
    
    try {
        Write-AppLog "Initializing theme engine..." -Level INFO
        
        # Get config
        $config = Get-AppConfig
        
        # Reset theme-related variables
        $script:currentTheme = $null
        $script:colors = @{}
        $script:availableThemesCache = $null
        
        # Determine if the console supports ANSI colors
        try {
            # Check PowerShell version, Core usually supports ANSI
            $isPSCore = $PSVersionTable.PSEdition -eq 'Core'
            
            # Check if running in VS Code terminal which supports ANSI
            $isVSCode = $env:TERM_PROGRAM -eq 'vscode' -or $host.Name -match 'Visual Studio Code'
            
            # Check if running in Windows Terminal which supports ANSI
            $isWindowsTerminal = $env:WT_SESSION -ne $null
            
            # Set default ANSI support based on these checks
            $script:useAnsiColors = $isPSCore -or $isVSCode -or $isWindowsTerminal
            
            Write-AppLog "ANSI color support detected: $($script:useAnsiColors)" -Level DEBUG
        }
        catch {
            # If we can't determine, default to false
            $script:useAnsiColors = $false
            Write-AppLog "Failed to detect ANSI color support, defaulting to false" -Level WARNING
        }
        
        # Get built-in themes
        $availableThemes = @()
        foreach ($themeName in $script:themePresets.Keys) {
            $themeInfo = @{
                Name = $themeName
                Type = "Built-in"
                Source = "System"
                ThemeObject = $script:themePresets[$themeName]
            }
            $availableThemes += $themeInfo
        }
        
        # Look for custom themes in theme directory
        if (Test-Path -Path $config.ThemesDir -PathType Container) {
            $themeFiles = Get-ChildItem -Path $config.ThemesDir -Filter "*.json" -File
            
            foreach ($themeFile in $themeFiles) {
                try {
                    $themeContent = Get-Content -Path $themeFile.FullName -Raw | ConvertFrom-Json
                    
                    # Skip invalid theme files
                    if (-not $themeContent.Name) {
                        Write-AppLog "Skipping invalid theme file: $($themeFile.Name)" -Level WARNING
                        continue
                    }
                    
                    # Convert from JSON to hashtable
                    $themeHashtable = ConvertFrom-JsonToHashtable -InputObject $themeContent
                    
                    # Add to available themes
                    $themeInfo = @{
                        Name = $themeContent.Name
                        Type = "Custom"
                        Source = $themeFile.FullName
                        ThemeObject = $themeHashtable
                    }
                    
                    # Check if a theme with this name already exists
                    if (($availableThemes | Where-Object { $_.Name -eq $themeContent.Name }).Count -gt 0) {
                        Write-AppLog "Theme '$($themeContent.Name)' already exists, skipping: $($themeFile.Name)" -Level WARNING
                    }
                    else {
                        $availableThemes += $themeInfo
                        Write-AppLog "Loaded custom theme: $($themeContent.Name)" -Level DEBUG
                    }
                }
                catch {
                    Write-AppLog "Failed to load theme file: $($themeFile.Name). Error: $($_.Exception.Message)" -Level WARNING
                }
            }
        }
        
        # Cache available themes
        $script:availableThemesCache = $availableThemes
        
        # Set default theme
        $defaultThemeName = $config.DefaultTheme
        if (-not $defaultThemeName -or -not ($availableThemes | Where-Object { $_.Name -eq $defaultThemeName })) {
            $defaultThemeName = "Default"
            Write-AppLog "Default theme not found or not specified, using 'Default'" -Level WARNING
        }
        
        # Apply the theme
        $success = Set-CurrentTheme -ThemeName $defaultThemeName
        
        if ($success) {
            Write-AppLog "Theme engine initialized with theme: $defaultThemeName" -Level INFO
        }
        else {
            Write-AppLog "Failed to initialize theme engine with theme: $defaultThemeName" -Level ERROR
            # Fallback to hardcoded Default theme
            $script:currentTheme = $script:defaultTheme
            $script:colors = $script:defaultTheme.Colors
            $script:useAnsiColors = $script:defaultTheme.UseAnsiColors
        }
        
        return $success
    }
    catch {
        Handle-Error -ErrorRecord $_ -Context "Initializing theme engine" -Continue
        
        # Emergency fallback to ensure we have some theme
        $script:currentTheme = $script:defaultTheme
        $script:colors = $script:defaultTheme.Colors
        $script:useAnsiColors = $false
        
        return $false
    }
}

<#
.SYNOPSIS
    Performs a deep copy of a hashtable.
.DESCRIPTION
    Creates a new hashtable with all keys and values from the source,
    recursively copying nested hashtables.
.PARAMETER InputObject
    The hashtable to copy.
.EXAMPLE
    $copy = Copy-HashtableDeep -InputObject $original
.OUTPUTS
    System.Collections.Hashtable - The copy of the input hashtable
#>
function Copy-HashtableDeep {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [hashtable]$InputObject
    )
    
    $clone = @{}
    foreach ($key in $InputObject.Keys) {
        if ($InputObject[$key] -is [hashtable]) {
            $clone[$key] = Copy-HashtableDeep -InputObject $InputObject[$key]
        }
        elseif ($InputObject[$key] -is [array]) {
            # Handle arrays of hashtables
            $array = @()
            foreach ($item in $InputObject[$key]) {
                if ($item -is [hashtable]) {
                    $array += Copy-HashtableDeep -InputObject $item
                }
                else {
                    $array += $item
                }
            }
            $clone[$key] = $array
        }
        else {
            $clone[$key] = $InputObject[$key]
        }
    }
    
    return $clone
}

<#
.SYNOPSIS
    Converts a JSON object to a hashtable.
.DESCRIPTION
    Recursively converts a JSON object (PSCustomObject) to a hashtable.
.PARAMETER InputObject
    The JSON object to convert.
.EXAMPLE
    $hashtable = ConvertFrom-JsonToHashtable -InputObject $jsonObject
.OUTPUTS
    System.Collections.Hashtable - The hashtable representation of the input object
#>
function ConvertFrom-JsonToHashtable {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [object]$InputObject
    )
    
    process {
        # Return non-object types as is
        if ($null -eq $InputObject -or
            $InputObject -is [bool] -or
            $InputObject -is [int] -or
            $InputObject -is [long] -or
            $InputObject -is [double] -or
            $InputObject -is [decimal] -or
            $InputObject -is [string]) {
            return $InputObject
        }
        
        # Handle arrays
        if ($InputObject -is [array]) {
            $array = @()
            foreach ($item in $InputObject) {
                $array += (ConvertFrom-JsonToHashtable -InputObject $item)
            }
            return $array
        }
        
        # Handle PSCustomObject (usual output from ConvertFrom-Json)
        if ($InputObject -is [System.Management.Automation.PSCustomObject]) {
            $hashtable = @{}
            $InputObject.PSObject.Properties | ForEach-Object {
                $hashtable[$_.Name] = (ConvertFrom-JsonToHashtable -InputObject $_.Value)
            }
            return $hashtable
        }
        
        # Default - return as is
        return $InputObject
    }
}

#endregion Initialization Functions
# Fix for ProjectTracker.Core.psm1
# Add this at the very end of the file
$coreFunctions = @(
    # Configuration functions
    'Get-AppConfig', 'Save-AppConfig', 'Merge-Hashtables',
    
    # Error handling
    'Handle-Error', 'Invoke-WithErrorHandling',
    
    # Logging
    'Write-AppLog', 'Rotate-LogFile', 'Get-AppLogContent',
    
    # Data functions
    'Ensure-DirectoryExists', 'Get-EntityData', 'Save-EntityData', 'Update-CumulativeHours',
    'Initialize-DataEnvironment', 'Get-EntityById', 'Update-EntityById', 'Remove-EntityById', 'Create-Entity',
    
    # Date functions
    'Parse-DateInput', 'Convert-DisplayDateToInternal', 'Convert-InternalDateToDisplay',
    'Get-RelativeDateDescription', 'Get-DateInput', 'Get-FirstDayOfWeek', 'Get-WeekNumber',
    
    # Helper functions
    'Read-UserInput', 'Confirm-Action', 'New-MenuItems', 'Show-Confirmation',
    'Get-EnvironmentVariable', 'Join-PathSafely', 'Get-UniqueFileName',
    'ConvertTo-ValidFileName', 'Get-TempFilePath', 'Convert-PriorityToInt', 'New-ID',
    
    # Theme functions
    'Initialize-ThemeEngine', 'Get-Theme', 'Set-CurrentTheme', 'Get-CurrentTheme', 'Get-AvailableThemes',
    
    # Display functions
    'Write-ColorText', 'Show-Table', 'Render-Header', 'Show-InfoBox', 'Show-ProgressBar',
    'Show-DynamicMenu', 'Get-VisibleStringLength', 'Safe-TruncateString', 'Remove-AnsiCodes',
    
    # Hashtable/JSON utilities
    'Copy-HashtableDeep', 'ConvertFrom-JsonToHashtable'
)

# Add this line at the end of 
Export-ModuleMember -Function Get-AppConfig, Save-AppConfig, Handle-Error, Invoke-WithErrorHandling, 
    Write-AppLog, Rotate-LogFile, Get-AppLogContent, Ensure-DirectoryExists, Get-EntityData, 
    Save-EntityData, Update-CumulativeHours, Initialize-DataEnvironment, Get-EntityById, 
    Update-EntityById, Remove-EntityById, Create-Entity, Parse-DateInput, 
    Convert-DisplayDateToInternal, Convert-InternalDateToDisplay, Get-RelativeDateDescription, 
    Get-DateInput, Get-FirstDayOfWeek, Get-WeekNumber, Get-MonthName, Get-RelativeWeekDescription, 
    Get-MonthDateRange, Read-UserInput, Confirm-Action, New-MenuItems, Show-Confirmation, 
    Get-EnvironmentVariable, Join-PathSafely, Get-UniqueFileName, ConvertTo-ValidFileName, 
    Get-TempFilePath, Convert-PriorityToInt, New-ID, New-RandomPassword, 
    Convert-BytesToHumanReadable, Find-SubstringPosition, Convert-ToSlug, 
    Initialize-ThemeEngine, Get-Theme, Set-CurrentTheme, Get-CurrentTheme, 
    Get-AvailableThemes, Write-ColorText, Show-Table, Render-Header, Show-InfoBox, 
    Show-ProgressBar, Show-DynamicMenu, Get-VisibleStringLength, Safe-TruncateString, 
    Remove-AnsiCodes