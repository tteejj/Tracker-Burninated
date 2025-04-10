# lib/theme-engine.ps1
# Display and Theme Management for Project Tracker
# Provides consistent UI rendering with theme support

# Script-scope variables for theme state
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

# Border character presets
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
}

<#
.SYNOPSIS
    Gets all available themes.
.DESCRIPTION
    Returns a list of all available themes, including built-in themes
    and custom themes from the themes directory.
.PARAMETER ThemesDir
    Optional path to the themes directory. If not specified, uses the path from configuration.
.PARAMETER ForceRefresh
    If specified, forces a refresh of the theme cache.
.EXAMPLE
    $themes = Get-AvailableThemes
    foreach ($theme in $themes) {
        Write-Host $theme.Name - $theme.Type
    }
.OUTPUTS
    System.Collections.Generic.List[PSObject] - List of theme objects with Name, Type, and Source properties
#>
function Get-AvailableThemes {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)]
        [string]$ThemesDir = $null,
        
        [Parameter(Mandatory=$false)]
        [switch]$ForceRefresh
    )
    
    # Use cached results if available and not forcing refresh
    if (-not $ForceRefresh -and $null -ne $script:availableThemesCache) {
        return $script:availableThemesCache
    }
    
    # Create a new list for the results
    $themes = New-Object System.Collections.Generic.List[PSObject]
    
    # Add built-in themes
    foreach ($name in $script:themePresets.Keys | Sort-Object) {
        $themes.Add([PSCustomObject]@{
            Name = $name
            Type = "Built-in"
            Source = "System"
        })
    }
    
    # Determine themes directory
    if (-not $ThemesDir) {
        # Try to get from app config
        if (Get-Command "Get-AppConfig" -ErrorAction SilentlyContinue) {
            try {
                $config = Get-AppConfig
                $ThemesDir = $config.ThemesDir
            } catch {
                Write-Verbose "Failed to get themes directory from config: $($_.Exception.Message)"
                # Use a default value
                $ThemesDir = Join-Path $PSScriptRoot "..\themes"
            }
        } else {
            # Use a default value
            $ThemesDir = Join-Path $PSScriptRoot "..\themes"
        }
    }
    
    # Add custom themes from the themes directory
    if (Test-Path $ThemesDir) {
        Get-ChildItem -Path $ThemesDir -Filter "*.json" | ForEach-Object {
            try {
                $themeData = Get-Content -Path $_.FullName -Raw | ConvertFrom-Json
                
                # Check if this theme has at least a Name property
                if ($themeData.PSObject.Properties.Name -contains 'Name') {
                    $themes.Add([PSCustomObject]@{
                        Name = $themeData.Name
                        Type = "Custom"
                        Source = if ($themeData.PSObject.Properties.Name -contains 'Author') {
                            $themeData.Author
                        } else {
                            "User"
                        }
                    })
                }
            } catch {
                Write-Verbose "Failed to load theme file $($_.Name): $($_.Exception.Message)"
            }
        }
    }
    
    # Cache the results
    $script:availableThemesCache = $themes
    
    return $themes
}

<#
.SYNOPSIS
    Gets a theme by name.
.DESCRIPTION
    Loads a theme by name, either from built-in themes or from a JSON file.
    Ensures all theme properties exist by merging with the default theme.
.PARAMETER ThemeName
    The name of the theme to load.
.PARAMETER ThemesDir
    Optional path to the themes directory. If not specified, uses the path from configuration.
.EXAMPLE
    $theme = Get-Theme -ThemeName "RetroWave"
.OUTPUTS
    System.Collections.Hashtable - The theme hashtable with all required properties
#>
function Get-Theme {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$ThemeName,
        
        [Parameter(Mandatory=$false)]
        [string]$ThemesDir = $null
    )
    
    # Check if theme is a built-in preset
    if ($script:themePresets.ContainsKey($ThemeName)) {
        return Copy-HashtableDeep -Source $script:themePresets[$ThemeName]
    }
    
    # Determine themes directory
    if (-not $ThemesDir) {
        # Try to get from app config
        if (Get-Command "Get-AppConfig" -ErrorAction SilentlyContinue) {
            try {
                $config = Get-AppConfig
                $ThemesDir = $config.ThemesDir
            } catch {
                Write-Verbose "Failed to get themes directory from config: $($_.Exception.Message)"
                # Use a default value
                $ThemesDir = Join-Path $PSScriptRoot "..\themes"
            }
        } else {
            # Use a default value
            $ThemesDir = Join-Path $PSScriptRoot "..\themes"
        }
    }
    
    # Try to load from file
    $themePath = Join-Path $ThemesDir "$ThemeName.json"
    if (Test-Path $themePath) {
        try {
            $themeJson = Get-Content -Path $themePath -Raw | ConvertFrom-Json
            
            # Convert JSON to hashtable
            $themeData = ConvertTo-Hashtable -InputObject $themeJson
            
            # Merge with default theme to ensure all properties exist
            $mergedTheme = Merge-ThemeWithDefault -Theme $themeData
            
            return $mergedTheme
        } catch {
            Write-Warning "Failed to load theme file $ThemeName.json: $($_.Exception.Message)"
        }
    }
    
    # If we get here, theme not found, use default
    Write-Warning "Theme '$ThemeName' not found. Using default theme."
    return Copy-HashtableDeep -Source $script:defaultTheme
}

<#
.SYNOPSIS
    Sets the current theme.
.DESCRIPTION
    Sets the current theme, updating script-scope variables for theme and colors.
    Updates $script:useAnsiColors based on theme settings.
.PARAMETER ThemeName
    The name of the theme to set.
.PARAMETER ThemeObject
    Optional theme object to use instead of loading by name.
.EXAMPLE
    Set-CurrentTheme -ThemeName "RetroWave"
.OUTPUTS
    System.Boolean - True if the theme was set successfully, False otherwise
#>
function Set-CurrentTheme {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true, ParameterSetName="ByName")]
        [string]$ThemeName,
        
        [Parameter(Mandatory=$true, ParameterSetName="ByObject")]
        [hashtable]$ThemeObject
    )
    
    # Get the theme either by name or use the provided object
    $theme = $null
    if ($PSCmdlet.ParameterSetName -eq "ByName") {
        $theme = Get-Theme -ThemeName $ThemeName
    } else {
        $theme = $ThemeObject
    }
    
    # Ensure theme was loaded
    if ($null -eq $theme) {
        Write-Warning "Failed to load theme."
        return $false
    }
    
    # Update script-scope variables
    $script:currentTheme = $theme
    $script:colors = $theme.Colors
    
    # Update ANSI color usage based on theme
    if ($theme.UseAnsiColors -is [bool]) {
        $script:useAnsiColors = $theme.UseAnsiColors
    }
    
    # Try to save to config if applicable
    if (Get-Command "Save-AppConfig" -ErrorAction SilentlyContinue) {
        try {
            $config = Get-AppConfig
            $config.DefaultTheme = $theme.Name
            Save-AppConfig -Config $config | Out-Null
        } catch {
            Write-Verbose "Failed to save theme to config: $($_.Exception.Message)"
        }
    }
    
    return $true
}

<#
.SYNOPSIS
    Gets the current theme.
.DESCRIPTION
    Returns the current theme object.
.EXAMPLE
    $theme = Get-CurrentTheme
    Write-Host "Using theme: $($theme.Name)"
.OUTPUTS
    System.Collections.Hashtable - The current theme hashtable
#>
function Get-CurrentTheme {
    [CmdletBinding()]
    param()
    
    # Initialize theme if not already set
    if ($null -eq $script:currentTheme) {
        # Try to get default theme from config
        $themeName = "Default"
        
        if (Get-Command "Get-AppConfig" -ErrorAction SilentlyContinue) {
            try {
                $config = Get-AppConfig
                $themeName = $config.DefaultTheme
            } catch {
                Write-Verbose "Failed to get default theme from config: $($_.Exception.Message)"
            }
        }
        
        $script:currentTheme = Get-Theme -ThemeName $themeName
        $script:colors = $script:currentTheme.Colors
        
        if ($script:currentTheme.UseAnsiColors -is [bool]) {
            $script:useAnsiColors = $script:currentTheme.UseAnsiColors
        }
    }
    
    return $script:currentTheme
}

<#
.SYNOPSIS
    Creates a deep copy of a hashtable.
.DESCRIPTION
    Creates a deep copy of a hashtable, including nested hashtables.
.PARAMETER Source
    The hashtable to copy.
.EXAMPLE
    $copy = Copy-HashtableDeep -Source $original
.OUTPUTS
    System.Collections.Hashtable - A deep copy of the source hashtable
#>
function Copy-HashtableDeep {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [object]$Source
    )
    
    if ($null -eq $Source) {
        return $null
    }
    
    if ($Source -is [hashtable]) {
        $result = @{}
        foreach ($key in $Source.Keys) {
            $result[$key] = Copy-HashtableDeep -Source $Source[$key]
        }
        return $result
    } elseif ($Source -is [array] -or $Source -is [System.Collections.ArrayList]) {
        $result = @()
        foreach ($item in $Source) {
            $result += Copy-HashtableDeep -Source $item
        }
        return $result
    } else {
        return $Source
    }
}

<#
.SYNOPSIS
    Converts a PSObject to a hashtable.
.DESCRIPTION
    Recursively converts a PSObject to a hashtable, including nested objects.
.PARAMETER InputObject
    The PSObject to convert.
.EXAMPLE
    $hashtable = ConvertTo-Hashtable -InputObject $jsonObject
.OUTPUTS
    System.Collections.Hashtable - The resulting hashtable
#>
function ConvertTo-Hashtable {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [object]$InputObject
    )
    
    if ($null -eq $InputObject) {
        return $null
    }
    
    if ($InputObject -is [System.Collections.IEnumerable] -and $InputObject -isnot [string]) {
        # Handle arrays
        $array = @()
        foreach ($item in $InputObject) {
            $array += ConvertTo-Hashtable -InputObject $item
        }
        return $array
    } elseif ($InputObject -is [PSObject]) {
        # Handle PSObjects
        $hash = @{}
        foreach ($property in $InputObject.PSObject.Properties) {
            $hash[$property.Name] = ConvertTo-Hashtable -InputObject $property.Value
        }
        return $hash
    } else {
        # Handle primitive types
        return $InputObject
    }
}

<#
.SYNOPSIS
    Merges a theme with the default theme.
.DESCRIPTION
    Ensures all required theme properties exist by merging the provided theme with the default theme.
.PARAMETER Theme
    The theme to merge with the default theme.
.EXAMPLE
    $completeTheme = Merge-ThemeWithDefault -Theme $customTheme
.OUTPUTS
    System.Collections.Hashtable - The merged theme hashtable
#>
function Merge-ThemeWithDefault {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [hashtable]$Theme
    )
    
    # Start with a deep copy of the default theme
    $defaultCopy = Copy-HashtableDeep -Source $script:defaultTheme
    
    # Recursive merge function
    function Merge-Recursive($target, $source) {
        foreach ($key in $source.Keys) {
            if ($source[$key] -is [hashtable] -and $target.ContainsKey($key) -and $target[$key] -is [hashtable]) {
                # Recursively merge nested hashtables
                $target[$key] = Merge-Recursive -target $target[$key] -source $source[$key]
            } else {
                # Overwrite or add key from source
                $target[$key] = Copy-HashtableDeep -Source $source[$key]
            }
        }
        return $target
    }
    
    # Merge theme into default copy
    $mergedTheme = Merge-Recursive -target $defaultCopy -source $Theme
    
    return $mergedTheme
}

<#
.SYNOPSIS
    Converts a color name to a standardized format.
.DESCRIPTION
    Takes a color in any format (string, ConsoleColor enum, etc.) and
    converts it to a standardized string representation.
.PARAMETER Color
    The color to convert.
.EXAMPLE
    $standardColor = ConvertTo-StandardColorFormat -Color "red"
.OUTPUTS
    System.String - The standardized color name
#>
function ConvertTo-StandardColorFormat {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [object]$Color
    )
    
    if ($Color -is [System.ConsoleColor]) {
        return $Color.ToString()
    } elseif ($Color -is [string]) {
        $validColors = [System.Enum]::GetNames([System.ConsoleColor])
        foreach ($validColor in $validColors) {
            if ($validColor -ieq $Color) { return $validColor } # Case-insensitive match
        }
        Write-Verbose "Color name '$Color' not recognized, using 'White'."
        return "White"
    } else {
        # Handle potential null or other types
        if ($null -eq $Color) { return "White" }
        $colorStr = $Color.ToString()
        if ([System.Enum]::GetNames([System.ConsoleColor]) -contains $colorStr) {
            return $colorStr
        }
        Write-Verbose "Color '$Color' not recognized, using 'White'."
        return "White"
    }
}

<#
.SYNOPSIS
    Gets a ConsoleColor enum from any color representation.
.DESCRIPTION
    Converts a color in any format to a System.ConsoleColor enum value.
.PARAMETER Color
    The color to convert.
.EXAMPLE
    $consoleColor = Get-ConsoleColor -Color "blue"
.OUTPUTS
    System.ConsoleColor - The console color enum value
#>
function Get-ConsoleColor {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [object]$Color
    )
    
    if ($Color -is [System.ConsoleColor]) { return $Color }
    $standardColor = ConvertTo-StandardColorFormat -Color $Color
    
    # Ensure standardColor is valid before parsing
    if ([System.Enum]::IsDefined([System.ConsoleColor], $standardColor)) {
        return [System.ConsoleColor]::Parse([System.ConsoleColor], $standardColor)
    } else {
        return [System.ConsoleColor]::White # Fallback if conversion failed
    }
}

<#
.SYNOPSIS
    Gets the ANSI color code for a PowerShell console color name.
.DESCRIPTION
    Converts a PowerShell color name to an ANSI color code for terminal output.
.PARAMETER Color
    The color to convert.
.PARAMETER Background
    If specified, returns the background color code instead of foreground.
.EXAMPLE
    $ansiCode = Get-AnsiColorCode -Color "Blue"
.OUTPUTS
    System.String - The ANSI color code (without escape sequence)
#>
function Get-AnsiColorCode {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [object]$Color,
        
        [Parameter(Mandatory=$false)]
        [switch]$Background
    )
    
    $colorName = ConvertTo-StandardColorFormat -Color $Color
    $colorMap = if ($Background) { $script:ansiBackgroundColors } else { $script:ansiForegroundColors }
    $defaultCode = if ($Background) { "40" } else { "37" } # Black BG, White FG
    
    if ($colorMap.ContainsKey($colorName)) {
        return $colorMap[$colorName]
    }
    return $defaultCode
}

<#
.SYNOPSIS
    Removes ANSI escape sequences from a string.
.DESCRIPTION
    Strips all ANSI escape sequences from a string, returning just the visible text.
.PARAMETER Text
    The text to process.
.EXAMPLE
    $cleanText = Remove-AnsiCodes -Text $coloredText
.OUTPUTS
    System.String - The text with ANSI codes removed
#>
function Remove-AnsiCodes {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)]
        [string]$Text = ""
    )
    
    if ([string]::IsNullOrEmpty($Text)) { return "" }
    
    if ($null -eq $script:ansiEscapePattern) {
        return $Text
    }
    
    return $script:ansiEscapePattern.Replace($Text, '')
}

<#
.SYNOPSIS
    Gets the visible length of a string by removing ANSI escape sequences.
.DESCRIPTION
    Calculates the visible length of a string by removing ANSI escape sequences.
    Uses caching for performance with repeated calls.
.PARAMETER Text
    The text to measure.
.EXAMPLE
    $length = Get-VisibleStringLength -Text $coloredText
.OUTPUTS
    System.Int32 - The visible length of the string
#>
function Get-VisibleStringLength {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)]
        [string]$Text = ""
    )
    
    if ($null -eq $Text) { return 0 }
    if ($Text.Length -eq 0) { return 0 }
    
    # Use caching for performance with repeated calls
    $cacheKey = [System.BitConverter]::ToString([System.Text.Encoding]::UTF8.GetBytes($Text))
    
    if ($script:stringLengthCache.ContainsKey($cacheKey)) {
        return $script:stringLengthCache[$cacheKey]
    }
    
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
}

<#
.SYNOPSIS
    Safely truncates a string to a specified length.
.DESCRIPTION
    Truncates a string to a specified length, optionally preserving ANSI escape sequences.
.PARAMETER Text
    The text to truncate.
.PARAMETER MaxLength
    The maximum length of the resulting string.
.PARAMETER PreserveAnsi
    If specified, preserves ANSI escape sequences in the truncated string.
.EXAMPLE
    $truncated = Safe-TruncateString -Text $longText -MaxLength 80 -PreserveAnsi
.OUTPUTS
    System.String - The truncated string
#>
function Safe-TruncateString {
    [CmdletBinding()]
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
    
    if ($PreserveAnsi) {
        # Check if text contains ANSI codes
        $hasAnsi = $Text -match '\x1b\['
        
        if (-not $hasAnsi) {
            # No ANSI codes, simple truncation
            if ($MaxLength -le 3) {
                return "..."
            }
            return $Text.Substring(0, [Math]::Min($Text.Length, $MaxLength - 3)) + "..."
        }
        
        # This is a simplified approach for ANSI-preserving truncation
        # Extract visible text while keeping track of ANSI sequences
        $visibleText = ""
        $ansiSequences = @()
        $position = 0
        
        # Parse the string, extracting ANSI sequences
        while ($position -lt $Text.Length) {
            if ($Text[$position] -eq [char]27 -and $position + 1 -lt $Text.Length -and $Text[$position + 1] -eq '[') {
                # Found an ANSI sequence, extract it
                $seqStart = $position
                $position += 2 # Skip escape character and bracket
                
                # Find the end of the sequence (a letter)
                while ($position -lt $Text.Length -and -not [char]::IsLetter($Text[$position])) {
                    $position++
                }
                
                if ($position -lt $Text.Length) {
                    $position++ # Include the letter
                    $sequence = $Text.Substring($seqStart, $position - $seqStart)
                    $ansiSequences += @{ Index = $visibleText.Length; Sequence = $sequence }
                }
            } else {
                # Regular character
                $visibleText += $Text[$position]
                $position++
            }
        }
        
        # Now truncate the visible text
        $truncatedVisible = if ($visibleText.Length > $MaxLength) {
            $visibleText.Substring(0, $MaxLength - 3) + "..."
        } else {
            $visibleText
        }
        
        # Rebuild the string with ANSI sequences
        $result = ""
        $currentPosition = 0
        
        foreach ($seq in $ansiSequences) {
            # Only include sequences that appear before the truncation point
            if ($seq.Index -le $MaxLength - 3) {
                # Add text up to the sequence position
                if ($seq.Index > $currentPosition) {
                    $result += $truncatedVisible.Substring($currentPosition, $seq.Index - $currentPosition)
                    $currentPosition = $seq.Index
                }
                
                # Add the ANSI sequence
                $result += $seq.Sequence
            }
        }
        
        # Add remaining visible text
        if ($currentPosition -lt $truncatedVisible.Length) {
            $result += $truncatedVisible.Substring($currentPosition)
        }
        
        # Ensure we end with a reset code if we have ANSI
        if ($hasAnsi) {
            $result += "`e[0m"
        }
        
        return $result
    } else {
        # Simple truncation without ANSI preservation
        $cleanText = Remove-AnsiCodes -Text $Text
        
        if ($MaxLength -le 3) {
            return "..."
        }
        
        return $cleanText.Substring(0, [Math]::Min($cleanText.Length, $MaxLength - 3)) + "..."
    }
}

<#
.SYNOPSIS
    Writes text to the console with color support.
.DESCRIPTION
    Writes text to the console with color support, using ANSI colors if enabled.
    Supports foreground and background colors and newline control.
.PARAMETER Text
    The text to output.
.PARAMETER ForegroundColor
    The text color.
.PARAMETER BackgroundColor
    The background color.
.PARAMETER NoNewline
    If specified, does not add a newline at the end of the output.
.EXAMPLE
    Write-ColorText -Text "Hello World" -ForegroundColor "Green"
.EXAMPLE
    Write-ColorText -Text "Warning!" -ForegroundColor "Black" -BackgroundColor "Yellow" -NoNewline
#>
function Write-ColorText {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)]
        [string]$Text = "",
        
        [Parameter(Mandatory=$false)]
        $ForegroundColor = "White",
        
        [Parameter(Mandatory=$false)]
        $BackgroundColor = $null,
        
        [Parameter(Mandatory=$false)]
        [switch]$NoNewline
    )
    
    # Handle null text gracefully
    if ($null -eq $Text) { $Text = "" }
    
    # Early exit for empty text with newline
    if ($Text.Length -eq 0 -and -not $NoNewline) {
        Write-Host ""
        return
    }
    
    # Early exit for empty text with NoNewline
    if ($Text.Length -eq 0 -and $NoNewline) {
        return
    }
    
    # Determine whether to use ANSI colors
    if ($script:useAnsiColors) {
        try {
            $escapeChar = [char]27
            $ansiSequence = "$escapeChar["
            $fgCode = Get-AnsiColorCode -Color $ForegroundColor
            $ansiSequence += "$fgCode"
            
            if ($null -ne $BackgroundColor) {
                $bgCode = Get-AnsiColorCode -Color $BackgroundColor -Background
                $ansiSequence += ";$bgCode"
            }
            
            $ansiSequence += "m"
            $resetSequence = "$escapeChar[0m"
            
            # Check if text already contains ANSI codes - prevent double-wrapping
            $hasAnsi = $Text -match '\e\['
            
            $outputText = if ($hasAnsi) {
                # Text already has ANSI, don't wrap it again
                # But ensure it ends with a reset
                if (-not $Text.EndsWith($resetSequence)) {
                    $Text + $resetSequence
                } else {
                    $Text
                }
            } else {
                # Normal wrapping for text without ANSI
                "$ansiSequence$Text$resetSequence"
            }
            
            # Output with or without newline
            if ($NoNewline) {
                Write-Host $outputText -NoNewline
            } else {
                Write-Host $outputText
            }
            
            return
        } catch {
            # Fall through to standard output on error
            Write-Verbose "ANSI output failed: $($_.Exception.Message)"
        }
    }
    
    # Standard PowerShell colored output
    $consoleColor = Get-ConsoleColor -Color $ForegroundColor
    $consoleBgColor = if ($null -ne $BackgroundColor) { Get-ConsoleColor -Color $BackgroundColor } else { $null }
    
    $params = @{ ForegroundColor = $consoleColor }
    if ($NoNewline) { $params.NoNewline = $true }
    if ($null -ne $consoleBgColor) { $params.BackgroundColor = $consoleBgColor }
    
    # Strip any ANSI that might be in the text for safety
    $cleanText = Remove-AnsiCodes -Text $Text
    Write-Host $cleanText @params
}

<#
.SYNOPSIS
    Formats a table cell for display.
.DESCRIPTION
    Formats a table cell with appropriate padding and alignment,
    optionally preserving ANSI escape codes.
.PARAMETER Content
    The cell content.
.PARAMETER Width
    The total width of the formatted cell.
.PARAMETER Alignment
    The text alignment ("Left", "Center", "Right").
.PARAMETER PreserveAnsi
    If specified, preserves ANSI escape sequences in the cell.
.EXAMPLE
    $formattedCell = Format-TableCell -Content "Hello" -Width 10 -Alignment "Center" -PreserveAnsi
.OUTPUTS
    System.String - The formatted cell content
#>
function Format-TableCell {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)]
        [string]$Content = "",
        
        [Parameter(Mandatory=$true)]
        [int]$Width,
        
        [Parameter(Mandatory=$false)]
        [ValidateSet("Left", "Center", "Right")]
        [string]$Alignment = "Left",
        
        [Parameter(Mandatory=$false)]
        [switch]$PreserveAnsi
    )
    
    # Handle empty content
    if ([string]::IsNullOrEmpty($Content)) {
        return " " * $Width
    }
    
    # Get visible length (without ANSI)
    $visibleLength = Get-VisibleStringLength -Text $Content
    
    # Check if we need to truncate
    if ($visibleLength -gt $Width) {
        return Safe-TruncateString -Text $Content -MaxLength $Width -PreserveAnsi:$PreserveAnsi
    }
    
    # Calculate padding
    $padding = $Width - $visibleLength
    $leftPad = 0
    $rightPad = 0
    
    switch ($Alignment.ToLower()) {
        "right" {
            $leftPad = $padding
            $rightPad = 0
        }
        "center" {
            $leftPad = [Math]::Floor($padding / 2)
            $rightPad = $padding - $leftPad
        }
        default { # Left alignment
            $leftPad = 0
            $rightPad = $padding
        }
    }
    
    # Apply padding to content
    if ($PreserveAnsi) {
        # Special handling for ANSI content - more complex but preserves codes
        $resetCode = [char]27 + "[0m"
        $hasResetAtEnd = $Content.EndsWith($resetCode)
        
        # Add padding while preserving ANSI codes
        $result = (" " * $leftPad) + 
                  ($hasResetAtEnd ? $Content.Substring(0, $Content.Length - $resetCode.Length) : $Content) + 
                  (" " * $rightPad)
        
        # Ensure we end with a reset code if ANSI is present
        if ($hasResetAtEnd) {
            $result += $resetCode
        }
        
        return $result
    } else {
        # Simple padding for non-ANSI content
        return (" " * $leftPad) + $Content + (" " * $rightPad)
    }
}

<#
.SYNOPSIS
    Gets a safe console width value.
.DESCRIPTION
    Returns the console width, handling potential errors and ensuring
    a minimum reasonable width for display.
.PARAMETER Override
    Optional override value for testing.
.EXAMPLE
    $width = Get-SafeConsoleWidth
.OUTPUTS
    System.Int32 - The console width
#>
function Get-SafeConsoleWidth {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)]
        [int]$Override = 0
    )
    
    # Return override if specified
    if ($Override -gt 0) {
        return $Override
    }
    
    try {
        # Subtract 1 to prevent wrapping issues with some terminals
        # Keep a reasonable minimum width
        return [Math]::Max(40, $Host.UI.RawUI.WindowSize.Width - 1)
    } catch {
        # Fallback width if can't determine console width
        return 80
    }
}

<#
.SYNOPSIS
    Renders a header with a title and optional subtitle.
.DESCRIPTION
    Renders a header with a title and optional subtitle, using the
    current theme's header style.
.PARAMETER Title
    The header title.
.PARAMETER Subtitle
    Optional subtitle.
.EXAMPLE
    Render-Header -Title "Project Management" -Subtitle "Version 1.0"
#>
function Render-Header {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Title,
        
        [Parameter(Mandatory=$false)]
        [string]$Subtitle = ""
    )
    
    # Ensure we have a current theme
    $theme = Get-CurrentTheme
    
    # Get console width
    $consoleWidth = Get-SafeConsoleWidth
    
    # Get theme settings or defaults
    $headerStyle = $theme.Headers.Style
    $borderChar = $theme.Headers.BorderChar
    $corners = $theme.Headers.Corners
    
    $cornerTL = $corners[0]
    $cornerTR = $corners[1]
    $cornerBL = $corners[2]
    $cornerBR = $corners[3]
    
    $vSideChar = "|" # Default
    
    # Determine vertical side character based on style
    switch ($headerStyle) {
        "Double" { $vSideChar = "║" }
        "Block" { $vSideChar = $borderChar }
        "Minimal" { $vSideChar = " " }
        default { $vSideChar = "│" }
    }
    
    $gradientChars = if ($theme.Headers.ContainsKey("GradientChars")) {
        $theme.Headers.GradientChars
    } else {
        "█▓▒░"
    }
    
    # Border line
    $borderWidth = $consoleWidth - 2
    $borderLine = $borderChar * $borderWidth
    
    # Title padding
    $titleLength = Get-VisibleStringLength -Text $Title
    $paddingLength = [Math]::Max(0, ($consoleWidth - $titleLength - 2)) / 2
    $leftPad = " " * [Math]::Floor($paddingLength)
    $rightPad = " " * [Math]::Ceiling($paddingLength)
    
    # Subtitle padding
    $subLeftPad = ""
    $subRightPad = ""
    if (-not [string]::IsNullOrWhiteSpace($Subtitle)) {
        $subTitleLength = Get-VisibleStringLength -Text $Subtitle
        $subPaddingLength = [Math]::Max(0, ($consoleWidth - $subTitleLength - 2)) / 2
        $subLeftPad = " " * [Math]::Floor($subPaddingLength)
        $subRightPad = " " * [Math]::Ceiling($subPaddingLength)
    }
    
    # Clear the console
    Clear-Host
    
    # Render header with current theme style
    switch ($headerStyle) {
        "Gradient" {
            # Gradient style header
            Write-ColorText "$cornerTL$borderLine$cornerTR" -ForegroundColor $theme.Colors.TableBorder
            Write-ColorText "$vSideChar$leftPad$Title$rightPad$vSideChar" -ForegroundColor $theme.Colors.Header
            
            if (-not [string]::IsNullOrWhiteSpace($Subtitle)) {
                Write-ColorText "$vSideChar$subLeftPad$Subtitle$subRightPad$vSideChar" -ForegroundColor $theme.Colors.Header
            }
            
            # Gradient bottom border
            $gradientWidth = $consoleWidth - 2
            $gradientLine = ""
            
            for ($i = 0; $i -lt $gradientWidth; $i++) {
                $charIndex = [Math]::Floor(($i / $gradientWidth) * $gradientChars.Length)
                $gradientLine += $gradientChars[$charIndex]
            }
            
            Write-ColorText "$cornerBL$gradientLine$cornerBR" -ForegroundColor $theme.Colors.TableBorder
        }
        "Double" {
            # Double-line style header
            Write-ColorText "$cornerTL$borderLine$cornerTR" -ForegroundColor $theme.Colors.TableBorder
            Write-ColorText "$vSideChar$leftPad$Title$rightPad$vSideChar" -ForegroundColor $theme.Colors.Header
            
            if (-not [string]::IsNullOrWhiteSpace($Subtitle)) {
                Write-ColorText "$vSideChar$subLeftPad$Subtitle$subRightPad$vSideChar" -ForegroundColor $theme.Colors.Header
            }
            
            Write-ColorText "$cornerBL$borderLine$cornerBR" -ForegroundColor $theme.Colors.TableBorder
        }
        "Minimal" {
            # Minimal style header
            Write-ColorText "$cornerTL$borderLine$cornerTR" -ForegroundColor $theme.Colors.TableBorder
            Write-ColorText "$Title" -ForegroundColor $theme.Colors.Header
            
            if (-not [string]::IsNullOrWhiteSpace($Subtitle)) {
                Write-ColorText "$Subtitle" -ForegroundColor $theme.Colors.Header
            }
            
            Write-ColorText "$cornerBL$borderLine$cornerBR" -ForegroundColor $theme.Colors.TableBorder
        }
        default {
            # Simple/default style header
            Write-ColorText "$cornerTL$borderLine$cornerTR" -ForegroundColor $theme.Colors.TableBorder
            Write-ColorText "$vSideChar$leftPad$Title$rightPad$vSideChar" -ForegroundColor $theme.Colors.Header
            
            if (-not [string]::IsNullOrWhiteSpace($Subtitle)) {
                Write-ColorText "$vSideChar$subLeftPad$Subtitle$subRightPad$vSideChar" -ForegroundColor $theme.Colors.Header
            }
            
            Write-ColorText "$cornerBL$borderLine$cornerBR" -ForegroundColor $theme.Colors.TableBorder
        }
    }
    
    # Add a blank line after the header
    Write-Host ""
}

<#
.SYNOPSIS
    Displays data in a table format.
.DESCRIPTION
    Renders data in a formatted table, with support for column headers,
    row highlighting, and customizable formatting.
.PARAMETER Data
    The data to display (array of objects).
.PARAMETER Columns
    An array of property names to display as columns.
.PARAMETER Headers
    Optional hashtable mapping column names to display headers.
.PARAMETER Formatters
    Optional hashtable mapping column names to formatter scriptblocks.
.PARAMETER RowColorizer
    Optional scriptblock to determine row color based on content.
.PARAMETER ShowRowNumbers
    If specified, adds a column with row numbers.
.EXAMPLE
    Show-Table -Data $projects -Columns @("Name", "Status", "DueDate") -Headers @{ DueDate = "Due" }
.OUTPUTS
    System.Int32 - The number of rows displayed
#>
function Show-Table {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [array]$Data,
        
        [Parameter(Mandatory=$true)]
        [string[]]$Columns,
        
        [Parameter(Mandatory=$false)]
        [hashtable]$Headers = @{},
        
        [Parameter(Mandatory=$false)]
        [hashtable]$Formatters = @{},
        
        [Parameter(Mandatory=$false)]
        [scriptblock]$RowColorizer = $null,
        
        [Parameter(Mandatory=$false)]
        [switch]$ShowRowNumbers
    )
    
    # Early validation
    if ($null -eq $Data) { $Data = @() }
    
    if ($null -eq $Columns -or $Columns.Count -eq 0) {
        Write-ColorText "Error: No columns specified for table." -ForegroundColor $script:colors.Error
        return 0
    }
    
    # Ensure we have a current theme
    $theme = Get-CurrentTheme
    
    # Get border characters from theme
    $borders = $theme.Table.Chars
    $enableRowSeparator = $theme.Table.RowSeparator
    
    # Create effective headers
    $effectiveHeaders = @{}
    foreach ($col in $Columns) {
        $effectiveHeaders[$col] = if ($Headers.ContainsKey($col)) { $Headers[$col] } else { $col }
    }
    
    # Calculate column widths
    $alignments = if ($script:config -and $script:config.TableOptions.Alignments) {
        $script:config.TableOptions.Alignments
    } else {
        @{} # Empty if not available
    }
    
    $fixedWidths = if ($script:config -and $script:config.TableOptions.FixedWidths) {
        $script:config.TableOptions.FixedWidths
    } else {
        @{} # Empty if not available
    }
    
    $columnWidths = @{}
    foreach ($col in $Columns) {
        # Check if we have a fixed width for this column
        if ($fixedWidths.ContainsKey($col)) {
            $columnWidths[$col] = $fixedWidths[$col]
            continue
        }
        
        # Calculate width based on content
        $headerWidth = Get-VisibleStringLength -Text $effectiveHeaders[$col]
        $contentWidth = 0
        
        # Check content width
        foreach ($item in $Data) {
            if ($null -eq $item) { continue }
            
            $value = $null
            
            # Get property value
            if ($item -is [hashtable] -and $item.ContainsKey($col)) {
                $value = $item[$col]
            } elseif ($item.PSObject.Properties[$col]) {
                $value = $item.PSObject.Properties[$col].Value
            }
            
            # Apply formatter if available
            if ($null -ne $value -and $Formatters.ContainsKey($col)) {
                try {
                    $value = & $Formatters[$col] $value $item
                } catch {
                    $value = "[FMT_ERR]"
                }
            }
            
            # Check width
            if ($null -ne $value) {
                $valueString = $value.ToString()
                $valueWidth = Get-VisibleStringLength -Text $valueString
                if ($valueWidth -gt $contentWidth) {
                    $contentWidth = $valueWidth
                }
            }
        }
        
        # Use the larger of header or content width, plus padding
        $columnWidths[$col] = [Math]::Max($headerWidth, $contentWidth) + 2
    }
    
    # Helper function to build border lines
    function Build-BorderLine {
        param(
            [string]$Left,
            [string]$Middle,
            [string]$Right,
            [string]$Horizontal
        )
        
        $line = $Left
        
        for ($i = 0; $i -lt $Columns.Count; $i++) {
            $col = $Columns[$i]
            $line += $Horizontal * $columnWidths[$col]
            
            if ($i -lt $Columns.Count - 1) {
                $line += $Middle
            }
        }
        
        $line += $Right
        return $line
    }
    
    # Draw top border
    $topBorder = Build-BorderLine -Left $borders.TopLeft -Middle $borders.TopJunction -Right $borders.TopRight -Horizontal $borders.Horizontal
    Write-ColorText $topBorder -ForegroundColor $theme.Colors.TableBorder
    
    # Draw header row
    Write-ColorText $borders.Vertical -ForegroundColor $theme.Colors.TableBorder -NoNewline
    
    foreach ($col in $Columns) {
        $header = $effectiveHeaders[$col]
        $width = $columnWidths[$col]
        $alignment = if ($alignments.ContainsKey($col)) { $alignments[$col] } else { "Left" }
        
        $formattedHeader = Format-TableCell -Content $header -Width $width -Alignment $alignment
        Write-ColorText $formattedHeader -ForegroundColor $theme.Colors.Header -NoNewline
        Write-ColorText $borders.Vertical -ForegroundColor $theme.Colors.TableBorder -NoNewline
    }
    
    Write-Host "" # End header row
    
    # Draw header/data separator
    $headerSeparator = Build-BorderLine -Left $borders.LeftJunction -Middle $borders.CrossJunction -Right $borders.RightJunction -Horizontal $borders.Horizontal
    Write-ColorText $headerSeparator -ForegroundColor $theme.Colors.TableBorder
    
    # Handle empty data
    if ($Data.Count -eq 0) {
        $totalWidth = ($Columns | ForEach-Object { $columnWidths[$_] } | Measure-Object -Sum).Sum + $Columns.Count + 1
        $message = " No data available "
        $messageLen = $message.Length
        $leftPad = [Math]::Floor(($totalWidth - $messageLen) / 2)
        $rightPad = $totalWidth - $messageLen - $leftPad
        
        Write-ColorText $borders.Vertical -ForegroundColor $theme.Colors.TableBorder -NoNewline
        Write-ColorText (" " * $leftPad) -NoNewline
        Write-ColorText $message -ForegroundColor $theme.Colors.Completed -NoNewline
        Write-ColorText (" " * $rightPad) -NoNewline
        Write-ColorText $borders.Vertical -ForegroundColor $theme.Colors.TableBorder
        
        # Draw bottom border
        $bottomBorder = Build-BorderLine -Left $borders.BottomLeft -Middle $borders.BottomJunction -Right $borders.BottomRight -Horizontal $borders.Horizontal
        Write-ColorText $bottomBorder -ForegroundColor $theme.Colors.TableBorder
        
        return 0
    }
    
    # Draw data rows
    $rowNumber = 0
    foreach ($item in $Data) {
        $rowNumber++
        
        if ($null -eq $item) { continue }
        
        # Determine row color
        $rowColor = $theme.Colors.Normal
        if ($null -ne $RowColorizer) {
            try {
                $colorResult = & $RowColorizer $item $rowNumber
                if (-not [string]::IsNullOrEmpty($colorResult)) {
                    $rowColor = $colorResult
                }
            } catch {
                # Ignore colorizer errors, use default color
            }
        }
        
        # Draw the row
        Write-ColorText $borders.Vertical -ForegroundColor $theme.Colors.TableBorder -NoNewline
        
        foreach ($col in $Columns) {
            $value = $null
            
            # Get property value
            if ($item -is [hashtable] -and $item.ContainsKey($col)) {
                $value = $item[$col]
            } elseif ($item.PSObject.Properties[$col]) {
                $value = $item.PSObject.Properties[$col].Value
            }
            
            # Apply formatter if available
            if ($Formatters.ContainsKey($col)) {
                try {
                    $value = & $Formatters[$col] $value $item
                } catch {
                    $value = "[FMT_ERR]"
                }
            }
            
            # Format the cell
            $alignment = if ($alignments.ContainsKey($col)) { $alignments[$col] } else { "Left" }
            $cellContent = if ($null -eq $value) { "" } else { $value.ToString() }
            $formattedCell = Format-TableCell -Content $cellContent -Width $columnWidths[$col] -Alignment $alignment -PreserveAnsi
            
            Write-ColorText $formattedCell -ForegroundColor $rowColor -NoNewline
            Write-ColorText $borders.Vertical -ForegroundColor $theme.Colors.TableBorder -NoNewline
        }
        
        Write-Host "" # End data row
        
        # Draw row separator if enabled and not the last row
        if ($enableRowSeparator -and $rowNumber -lt $Data.Count) {
            $rowSeparator = Build-BorderLine -Left $borders.LeftJunction -Middle $borders.CrossJunction -Right $borders.RightJunction -Horizontal $borders.Horizontal
            Write-ColorText $rowSeparator -ForegroundColor $theme.Colors.TableBorder
        }
    }
    
    # Draw bottom border
    $bottomBorder = Build-BorderLine -Left $borders.BottomLeft -Middle $borders.BottomJunction -Right $borders.BottomRight -Horizontal $borders.Horizontal
    Write-ColorText $bottomBorder -ForegroundColor $theme.Colors.TableBorder
    
    return $rowNumber
}

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
}

<#
.SYNOPSIS
    Shows a progress bar.
.DESCRIPTION
    Displays a progress bar with a percentage and optional message.
.PARAMETER PercentComplete
    The percentage complete (0-100).
.PARAMETER Width
    The width of the progress bar in characters.
.PARAMETER Text
    Optional text to display after the progress bar.
.EXAMPLE
    Show-ProgressBar -PercentComplete 75 -Width 50 -Text "Processing files..."
#>
function Show-ProgressBar {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [int]$PercentComplete,
        
        [Parameter(Mandatory=$false)]
        [int]$Width = 50,
        
        [Parameter(Mandatory=$false)]
        [string]$Text = ""
    )
    
    # Ensure we have a current theme
    $theme = Get-CurrentTheme
    
    # Validate and constrain inputs
    $percent = [Math]::Max(0, [Math]::Min(100, $PercentComplete))
    $maxWidth = (Get-SafeConsoleWidth) - 10 # Space for brackets, percentage, text
    $width = [Math]::Max(10, [Math]::Min($Width, $maxWidth))
    
    # Calculate filled/empty sections
    $filledCount = [Math]::Round(($width * $percent) / 100)
    $emptyCount = $width - $filledCount
    
    # Get characters from theme
    $filledChar = $theme.ProgressBar.FilledChar
    $emptyChar = $theme.ProgressBar.EmptyChar
    $leftCap = $theme.ProgressBar.LeftCap
    $rightCap = $theme.ProgressBar.RightCap
    
    # Draw progress bar
    Write-ColorText $leftCap -ForegroundColor $theme.Colors.Normal -NoNewline
    
    if ($filledCount -gt 0) {
        $filled = $filledChar * $filledCount
        Write-ColorText $filled -ForegroundColor $theme.Colors.Success -NoNewline
    }
    
    if ($emptyCount -gt 0) {
        $empty = $emptyChar * $emptyCount
        Write-ColorText $empty -ForegroundColor $theme.Colors.Completed -NoNewline
    }
    
    Write-ColorText $rightCap -ForegroundColor $theme.Colors.Normal -NoNewline
    Write-ColorText " $($percent.ToString().PadLeft(3))% " -ForegroundColor $theme.Colors.Accent2 -NoNewline
    
    if (-not [string]::IsNullOrEmpty($Text)) {
        Write-ColorText $Text -ForegroundColor $theme.Colors.Normal
    } else {
        Write-Host "" # End line
    }
}

<#
.SYNOPSIS
    Shows a dynamic menu with options.
.DESCRIPTION
    Displays a menu with options, processing user selection and executing associated actions.
.PARAMETER Title
    The title of the menu.
.PARAMETER Subtitle
    Optional subtitle for the menu.
.PARAMETER MenuItems
    Array of menu item objects with Type, Key, Text, and Function properties.
.PARAMETER Prompt
    The prompt text for user input.
.PARAMETER UseNavigationBar
    If specified, shows a navigation bar at the top of the menu.
.EXAMPLE
    $menuItems = @(
        @{ Type = "header"; Text = "Main Menu" },
        @{ Type = "option"; Key = "1"; Text = "View Projects"; Function = { Show-Projects } },
        @{ Type = "option"; Key = "0"; Text = "Exit"; Function = { return $true }; IsExit = $true }
    )
    Show-DynamicMenu -Title "Project Manager" -MenuItems $menuItems
.OUTPUTS
    System.Object - The return value from the selected menu action
#>
function Show-DynamicMenu {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Title,
        
        [Parameter(Mandatory=$false)]
        [string]$Subtitle = "",
        
        [Parameter(Mandatory=$true)]
        [array]$MenuItems,
        
        [Parameter(Mandatory=$false)]
        [string]$Prompt = "Enter selection:",
        
        [Parameter(Mandatory=$false)]
        [switch]$UseNavigationBar
    )
    
    # Ensure we have a current theme
    $theme = Get-CurrentTheme
    
    # Get theme menu settings
    $selectedPrefix = $theme.Menu.SelectedPrefix
    $unselectedPrefix = $theme.Menu.UnselectedPrefix
    
    # Loop for menu redraw after actions
    while ($true) {
        # Render header
        Render-Header -Title $Title -Subtitle $Subtitle
        
        # Show navigation bar if requested and available
        if ($UseNavigationBar -and (Get-Command "Show-NavigationBar" -ErrorAction SilentlyContinue)) {
            Show-NavigationBar
        }
        
        # Display menu items
        $validOptions = @{}
        
        foreach ($item in $MenuItems) {
            if (-not $item.ContainsKey("Type")) { continue }
            
            switch ($item.Type) {
                "header" {
                    Write-ColorText $item.Text -ForegroundColor $theme.Colors.Accent1
                    Write-ColorText ("-" * 30) -ForegroundColor $theme.Colors.TableBorder
                }
                "separator" {
                    Write-ColorText ("-" * 30) -ForegroundColor $theme.Colors.TableBorder
                }
                "option" {
                    $prefix = $unselectedPrefix
                    $color = $theme.Colors.Normal
                    
                    # Handle highlighted options
                    if ($item.ContainsKey("IsHighlighted") -and $item.IsHighlighted) {
                        $prefix = $selectedPrefix
                        $color = $theme.Colors.Accent2
                    }
                    
                    # Handle disabled options
                    if ($item.ContainsKey("IsDisabled") -and $item.IsDisabled) {
                        $color = $theme.Colors.Completed
                    } else {
                        $validOptions[$item.Key] = $item
                    }
                    
                    # Build option text
                    $optionText = "$prefix[$($item.Key)] $($item.Text)"
                    Write-ColorText $optionText -ForegroundColor $color
                }
            }
        }
        
        # Prompt for user input
        Write-Host "`n$Prompt " -ForegroundColor $theme.Colors.Accent2 -NoNewline
        $choice = Read-Host
        
        if ($validOptions.ContainsKey($choice)) {
            $selectedItem = $validOptions[$choice]
            
            if ($selectedItem.ContainsKey("Function")) {
                try {
                    $result = & $selectedItem.Function
                    
                    # Check if this option should exit the menu
                    if ($selectedItem.ContainsKey("IsExit") -and $selectedItem.IsExit) {
                        return $result # Exit the menu loop
                    }
                    
                    # If the function returned a value, return it without exiting
                    if ($null -ne $result) {
                        return $result
                    }
                    
                    # Otherwise, continue the loop (redraw menu)
                } catch {
                    Write-ColorText "Error executing menu action: $($_.Exception.Message)" -ForegroundColor $theme.Colors.Error
                    Read-Host "Press Enter to continue..."
                }
            }
        } else {
            # Invalid selection
            Write-ColorText "Invalid selection. Please try again." -ForegroundColor $theme.Colors.Error
            Start-Sleep -Milliseconds 1000 # Brief pause to show error
        }
    }
}

<#
.SYNOPSIS
    Initializes the theme engine.
.DESCRIPTION
    Initializes the theme engine by loading the default theme
    and checking ANSI color support.
.EXAMPLE
    Initialize-ThemeEngine
.OUTPUTS
    System.Boolean - True if initialization succeeded, False otherwise
#>
function Initialize-ThemeEngine {
    [CmdletBinding()]
    param()
    
    try {
        Write-Verbose "Initializing theme engine..."
        
        # Clear any cached data
        $script:availableThemesCache = $null
        $script:stringLengthCache = @{}
        
        # Set ANSI color support (simplified: assume all modern terminals support it)
        $script:useAnsiColors = $true
        
        # Initialize the current theme from config if possible
        $themeName = "Default"
        
        if (Get-Command "Get-AppConfig" -ErrorAction SilentlyContinue) {
            try {
                $config = Get-AppConfig
                if (-not [string]::IsNullOrEmpty($config.DefaultTheme)) {
                    $themeName = $config.DefaultTheme
                }
            } catch {
                Write-Warning "Failed to get theme from config: $($_.Exception.Message)"
            }
        }
        
        # Load the theme
        $script:currentTheme = Get-Theme -ThemeName $themeName
        $script:colors = $script:currentTheme.Colors
        
        # Set ANSI usage based on theme
        if ($script:currentTheme.UseAnsiColors -is [bool]) {
            $script:useAnsiColors = $script:currentTheme.UseAnsiColors
        }
        
        # Ensure themes directory exists
        if (Get-Command "Get-AppConfig" -ErrorAction SilentlyContinue) {
            try {
                $config = Get-AppConfig
                $themesDir = $config.ThemesDir
                
                if (-not (Test-Path $themesDir -PathType Container)) {
                    New-Item -Path $themesDir -ItemType Directory -Force | Out-Null
                    Write-Verbose "Created themes directory: $themesDir"
                }
                
                # Create default themes if they don't exist
                foreach ($presetName in $script:themePresets.Keys) {
                    $themePath = Join-Path $themesDir "$presetName.json"
                    if (-not (Test-Path $themePath)) {
                        $themeData = $script:themePresets[$presetName]
                        $themeData | ConvertTo-Json -Depth 5 | Out-File -FilePath $themePath -Encoding utf8
                        Write-Verbose "Created theme file: $themePath"
                    }
                }
            } catch {
                Write-Warning "Failed to initialize themes directory: $($_.Exception.Message)"
            }
        }
        
        Write-Verbose "Theme engine initialization complete."
        return $true
    } catch {
        Write-Warning "Failed to initialize theme engine: $($_.Exception.Message)"
        
        # Set failsafe defaults
        $script:currentTheme = $script:defaultTheme
        $script:colors = $script:defaultTheme.Colors
        $script:useAnsiColors = $false
        
        return $false
    }
}

# Export public functions
Export-ModuleMember -Function Initialize-ThemeEngine, Get-Theme, Set-CurrentTheme, Get-CurrentTheme, 
                     Get-AvailableThemes, Write-ColorText, Show-Table, Render-Header, 
                     Show-InfoBox, Show-ProgressBar, Show-DynamicMenu,
                     Get-VisibleStringLength, Safe-TruncateString, Remove-AnsiCodes
