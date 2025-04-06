# Deep Debug Theme Module
# This script provides in-depth debugging for the theme system

# First, import the core module
$scriptDir = $PSScriptRoot
try {
    Import-Module -Name "$scriptDir\Modules\ProjectTracker.Core\ProjectTracker.Core.psd1" -Force -ErrorAction Stop
    Write-Host "Successfully imported ProjectTracker.Core module" -ForegroundColor Green
} catch {
    Write-Host "CRITICAL ERROR: Failed to import ProjectTracker.Core module" -ForegroundColor Red
    Write-Host "Details: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Define theme inspection functions
function Inspect-Theme {
    param (
        [Parameter(Mandatory=$true)]
        [string]$ThemeName
    )
    
    Write-Host "====== DEEP THEME INSPECTION: $ThemeName ======" -ForegroundColor Cyan
    
    # 1. Check theme file
    $config = Get-AppConfig
    $themePath = Join-Path $config.ThemesDir "$ThemeName.json"
    
    Write-Host "Theme file path: $themePath" -ForegroundColor Yellow
    if (Test-Path $themePath) {
        Write-Host "Theme file exists: YES" -ForegroundColor Green
        
        # Load the raw file content
        $rawContent = Get-Content -Path $themePath -Raw
        $fileLength = $rawContent.Length
        Write-Host "File size: $fileLength bytes" -ForegroundColor White
        
        if ($fileLength -lt 20) {
            Write-Host "ERROR: Theme file is suspiciously small!" -ForegroundColor Red
            Write-Host "Raw content: $rawContent" -ForegroundColor Gray
        }
        
        # Try to parse it
        try {
            $jsonObject = $rawContent | ConvertFrom-Json
            Write-Host "Parse as JSON: SUCCESS" -ForegroundColor Green
            
            # Inspect the JSON structure
            Write-Host "JSON Properties:" -ForegroundColor Yellow
            foreach ($prop in $jsonObject.PSObject.Properties) {
                $type = if ($null -eq $prop.Value) { "null" } else { $prop.Value.GetType().Name }
                Write-Host "  - $($prop.Name): $type" -ForegroundColor White
            }
            
            # Check critical properties
            $checkProps = @(
                @{ Name = "Name"; Type = "String" },
                @{ Name = "Description"; Type = "String" },
                @{ Name = "UseAnsiColors"; Type = "Boolean" },
                @{ Name = "Colors"; Type = "PSCustomObject" },
                @{ Name = "Table"; Type = "PSCustomObject" }
            )
            
            foreach ($check in $checkProps) {
                $propName = $check.Name
                $expectedType = $check.Type
                
                if ($jsonObject.PSObject.Properties.Name -contains $propName) {
                    $value = $jsonObject.$propName
                    $actualType = if ($null -eq $value) { "null" } else { $value.GetType().Name }
                    
                    $valid = switch ($expectedType) {
                        "String" { $actualType -eq "String" }
                        "Boolean" { $actualType -eq "Boolean" }
                        "PSCustomObject" { $actualType -eq "PSCustomObject" }
                        default { $false }
                    }
                    
                    $status = if ($valid) { "VALID" } else { "INVALID TYPE" }
                    $statusColor = if ($valid) { "Green" } else { "Red" }
                    
                    Write-Host "  Property '$propName': $status ($actualType)" -ForegroundColor $statusColor
                } else {
                    Write-Host "  Property '$propName': MISSING" -ForegroundColor Red
                }
            }
            
            # Check Colors structure
            if ($jsonObject.PSObject.Properties.Name -contains "Colors") {
                Write-Host "`nInspecting Colors:" -ForegroundColor Yellow
                foreach ($colorProp in $jsonObject.Colors.PSObject.Properties) {
                    $colorValue = $colorProp.Value
                    $colorType = if ($null -eq $colorValue) { "null" } else { $colorValue.GetType().Name }
                    Write-Host "  - $($colorProp.Name): $colorType = $colorValue" -ForegroundColor White
                }
            }
            
            # Check Table.Chars structure
            if ($jsonObject.PSObject.Properties.Name -contains "Table" -and
                $jsonObject.Table.PSObject.Properties.Name -contains "Chars") {
                Write-Host "`nInspecting Table.Chars:" -ForegroundColor Yellow
                foreach ($charProp in $jsonObject.Table.Chars.PSObject.Properties) {
                    $charValue = $charProp.Value
                    $charType = if ($null -eq $charValue) { "null" } else { $charValue.GetType().Name }
                    Write-Host "  - $($charProp.Name): $charType = '$charValue'" -ForegroundColor White
                }
            } else {
                Write-Host "`nERROR: Table.Chars structure is missing!" -ForegroundColor Red
            }
            
        } catch {
            Write-Host "ERROR parsing JSON: $($_.Exception.Message)" -ForegroundColor Red
            
            # Try to debug the JSON format
            Write-Host "`nTrying to identify JSON issues..." -ForegroundColor Yellow
            
            # Check for basic JSON syntax issues
            $hasBraces = $rawContent.Trim().StartsWith("{") -and $rawContent.Trim().EndsWith("}")
            Write-Host "Valid JSON object braces: $(if ($hasBraces) { 'YES' } else { 'NO' })" -ForegroundColor $(if ($hasBraces) { 'Green' } else { 'Red' })
            
            # Check for unescaped quotes in strings
            $unescapedQuotes = [regex]::Matches($rawContent, '(?<!\\)"(?=[^"]*":)').Count
            Write-Host "Found $unescapedQuotes property name quotes" -ForegroundColor White
            
            # Show beginning and end of file
            Write-Host "`nFirst 200 characters:" -ForegroundColor Yellow
            Write-Host $rawContent.Substring(0, [Math]::Min(200, $rawContent.Length)) -ForegroundColor Gray
            
            Write-Host "`nLast 200 characters:" -ForegroundColor Yellow
            if ($rawContent.Length > 200) {
                Write-Host $rawContent.Substring($rawContent.Length - 200) -ForegroundColor Gray
            } else {
                Write-Host "(same as above)" -ForegroundColor Gray
            }
        }
    } else {
        Write-Host "Theme file exists: NO" -ForegroundColor Red
    }
    
    # 2. Try to load through the theme engine
    Write-Host "`n--- Loading Theme Through API ---" -ForegroundColor Yellow
    try {
        $theme = Get-Theme -ThemeName $ThemeName
        
        if ($theme) {
            Write-Host "Get-Theme succeeded: YES" -ForegroundColor Green
            Write-Host "Theme object type: $($theme.GetType().Name)" -ForegroundColor White
            
            # Check hastable structure
            Write-Host "`nHashtable Keys:" -ForegroundColor Yellow
            foreach ($key in $theme.Keys) {
                $value = $theme[$key]
                $type = if ($null -eq $value) { "null" } else { $value.GetType().Name }
                
                if ($value -is [hashtable]) {
                    Write-Host "  - $key $type with $($value.Count) items" -ForegroundColor White
                } else {
                    $displayValue = if ($value -is [string] -or $value -is [bool] -or $value -is [int]) { $value } else { "(complex)" }
                    Write-Host "  - $key $type = $displayValue" -ForegroundColor White
                }
            }
            
            # Check critical theme components
            $criticalComponents = @(
                @{ Name = "Colors"; Type = "hashtable" },
                @{ Name = "Table"; Type = "hashtable" }
            )
            
            foreach ($component in $criticalComponents) {
                $name = $component.Name
                $expectedType = $component.Type
                
                if ($theme.ContainsKey($name)) {
                    $value = $theme[$name]
                    $actualType = if ($null -eq $value) { "null" } else { $value.GetType().Name }
                    
                    $valid = switch ($expectedType) {
                        "hashtable" { $value -is [hashtable] }
                        "string" { $value -is [string] }
                        "bool" { $value -is [bool] }
                        default { $false }
                    }
                    
                    $status = if ($valid) { "VALID" } else { "INVALID TYPE" }
                    $statusColor = if ($valid) { "Green" } else { "Red" }
                    
                    Write-Host "  Component '$name': $status ($actualType)" -ForegroundColor $statusColor
                    
                    # If it's a hashtable, check its keys
                    if ($value -is [hashtable] -and $value.Count -gt 0) {
                        Write-Host "    Keys: $($value.Keys -join ', ')" -ForegroundColor White
                    }
                    
                    # Special handling for Table.Chars
                    if ($name -eq "Table" -and $value -is [hashtable] -and $value.ContainsKey("Chars")) {
                        $chars = $value["Chars"]
                        if ($chars -is [hashtable]) {
                            Write-Host "    Table.Chars: PRESENT ($(if ($chars.Count -gt 0) { "$($chars.Count) items" } else { "empty" }))" -ForegroundColor $(if ($chars.Count -gt 0) { "Green" } else { "Red" })
                            
                            if ($chars.Count -gt 0) {
                                $requiredChars = @("Horizontal", "Vertical", "TopLeft", "TopRight", "BottomLeft", "BottomRight")
                                foreach ($charName in $requiredChars) {
                                    $hasChar = $chars.ContainsKey($charName)
                                    $charValue = if ($hasChar) { "'$($chars[$charName])'" } else { "MISSING" }
                                    Write-Host "      - $charName $charValue" -ForegroundColor $(if ($hasChar) { "White" } else { "Red" })
                                }
                            }
                        } else {
                            Write-Host "    Table.Chars: INVALID (not a hashtable)" -ForegroundColor Red
                        }
                    }
                    
                    # Special handling for Colors
                    if ($name -eq "Colors" -and $value -is [hashtable]) {
                        $requiredColors = @("Normal", "Header", "Accent1", "Error", "Warning", "Success")
                        foreach ($colorName in $requiredColors) {
                            $hasColor = $value.ContainsKey($colorName)
                            $colorValue = if ($hasColor) { $value[$colorName] } else { "MISSING" }
                            Write-Host "      - $colorName $colorValue" -ForegroundColor $(if ($hasColor) { "White" } else { "Red" })
                        }
                    }
                } else {
                    Write-Host "  Component '$name': MISSING" -ForegroundColor Red
                }
            }
            
            # 3. Try to apply the theme
            Write-Host "`n--- Applying Theme ---" -ForegroundColor Yellow
            try {
                $result = Set-CurrentTheme -ThemeName $ThemeName
                
                if ($result) {
                    Write-Host "Set-CurrentTheme succeeded: YES" -ForegroundColor Green
                    
                    # Check actual current theme
                    $currentTheme = Get-CurrentTheme
                    $currentName = $currentTheme.Name
                    
                    if ($currentName -eq $ThemeName) {
                        Write-Host "Current theme is '$currentName' as expected" -ForegroundColor Green
                    } else {
                        Write-Host "ERROR: Current theme is '$currentName', expected '$ThemeName'" -ForegroundColor Red
                    }
                    
                    # Check script-scoped variables (might not be visible from this scope)
                    try {
                        $useAnsiValue = Get-Variable -Name useAnsiColors -Scope Script -ErrorAction Stop
                        Write-Host "script:useAnsiColors = $useAnsiValue" -ForegroundColor Green
                    } catch {
                        Write-Host "Cannot access script:useAnsiColors from this scope" -ForegroundColor Yellow
                        Write-Host "This is expected when running from an external script" -ForegroundColor Yellow
                    }
                    
                    # Test rendering with the current theme
                    Write-Host "`n--- Rendering Test with Current Theme ---" -ForegroundColor Yellow
                    try {
                        # Test ColorText
                        $colors = $currentTheme.Colors
                        Write-Host "Testing Write-ColorText with theme colors:" -ForegroundColor White
                        foreach ($colorKey in $colors.Keys) {
                            try {
                                Write-ColorText "  Sample text in $colorKey color" -ForegroundColor $colors[$colorKey]
                            } catch {
                                Write-Host "  ERROR with color '$colorKey': $($_.Exception.Message)" -ForegroundColor Red
                            }
                        }
                        
                        # Test header
                        Write-Host "`nTesting Render-Header:" -ForegroundColor White
                        try {
                            Render-Header -Title "Test Header for $ThemeName" -Subtitle "This is a test subtitle"
                        } catch {
                            Write-Host "ERROR in Render-Header: $($_.Exception.Message)" -ForegroundColor Red
                            Write-Host $_.ScriptStackTrace -ForegroundColor Gray
                        }
                        
                        # Test table
                        Write-Host "`nTesting Show-Table with current theme:" -ForegroundColor White
                        try {
                            $data = @(
                                [PSCustomObject]@{ ID = 1; Name = "Test 1"; Status = "Active" },
                                [PSCustomObject]@{ ID = 2; Name = "Test 2"; Status = "Completed" }
                            )
                            
                            Show-Table -Data $data -Columns @("ID", "Name", "Status")
                        } catch {
                            Write-Host "ERROR in Show-Table: $($_.Exception.Message)" -ForegroundColor Red
                            Write-Host $_.ScriptStackTrace -ForegroundColor Gray
                        }
                    } catch {
                        Write-Host "ERROR in rendering test: $($_.Exception.Message)" -ForegroundColor Red
                    }
                } else {
                    Write-Host "Set-CurrentTheme succeeded: NO" -ForegroundColor Red
                }
            } catch {
                Write-Host "ERROR applying theme: $($_.Exception.Message)" -ForegroundColor Red
                Write-Host $_.ScriptStackTrace -ForegroundColor Gray
            }
        } else {
            Write-Host "Get-Theme succeeded: NO (returned null)" -ForegroundColor Red
        }
    } catch {
        Write-Host "ERROR loading theme: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host $_.ScriptStackTrace -ForegroundColor Gray
    }
    
    Write-Host "`n====== END THEME INSPECTION ======`n" -ForegroundColor Cyan
}

function Create-NewUnicodeTheme {
    param(
        [Parameter(Mandatory=$true)]
        [string]$ThemeName
    )
    
    Write-Host "Creating new Unicode test theme: $ThemeName" -ForegroundColor Yellow
    
    $unicodeTheme = @{
        "Name" = $ThemeName
        "Description" = "Unicode test theme with ANSI colors"
        "Author" = "Debug Script"
        "Version" = "1.0"
        "UseAnsiColors" = $true
        "Colors" = @{
            "Normal" = "Cyan"
            "Header" = "Magenta"
            "Accent1" = "Yellow"
            "Accent2" = "Cyan"
            "Success" = "Green"
            "Warning" = "Yellow"
            "Error" = "Red"
            "Completed" = "DarkGray"
            "DueSoon" = "Yellow"
            "Overdue" = "Red"
            "TableBorder" = "Magenta"
        }
        "Table" = @{
            "Chars" = @{
                "Horizontal" = "━"
                "Vertical" = "┃"
                "TopLeft" = "┏"
                "TopRight" = "┓"
                "BottomLeft" = "┗"
                "BottomRight" = "┛"
                "LeftJunction" = "┣"
                "RightJunction" = "┫"
                "TopJunction" = "┳"
                "BottomJunction" = "┻"
                "CrossJunction" = "╋"
            }
            "RowSeparator" = $true
            "CellPadding" = 1
            "HeaderStyle" = "Bold"
        }
        "Headers" = @{
            "Style" = "Simple"
            "BorderChar" = "━"
            "Corners" = "┏┓┗┛"
        }
        "Menu" = @{
            "SelectedPrefix" = "►"
            "UnselectedPrefix" = " "
        }
        "ProgressBar" = @{
            "FilledChar" = "█"
            "EmptyChar" = "░"
            "LeftCap" = "【"
            "RightCap" = "】"
        }
    }
    
    # Convert the hashtable to JSON
    $jsonContent = ConvertTo-Json -InputObject $unicodeTheme -Depth 10
    
    # Save to file
    $config = Get-AppConfig
    $themePath = Join-Path $config.ThemesDir "$ThemeName.json"
    
    try {
        # Make sure directory exists
        $themeDir = Split-Path -Path $themePath -Parent
        if (-not (Test-Path -Path $themeDir -PathType Container)) {
            New-Item -Path $themeDir -ItemType Directory -Force | Out-Null
        }
        
        # Write the file
        $jsonContent | Out-File -FilePath $themePath -Encoding utf8 -Force
        
        if (Test-Path $themePath) {
            Write-Host "Successfully created theme file: $themePath" -ForegroundColor Green
            Write-Host "File size: $((Get-Item $themePath).Length) bytes" -ForegroundColor White
            
            # Verify the file can be read back
            $content = Get-Content -Path $themePath -Raw
            Write-Host "Content check: $($content.Substring(0, 50))..." -ForegroundColor White
            
            return $true
        } else {
            Write-Host "ERROR: Failed to create theme file" -ForegroundColor Red
            return $false
        }
    } catch {
        Write-Host "ERROR creating theme file: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host $_.ScriptStackTrace -ForegroundColor Gray
        return $false
    }
}

# Main execution
Write-Host "===== DEEP THEME DEBUGGING =====" -ForegroundColor Cyan

# Create a fresh Unicode theme
$newTheme = "UnicodeDebug"
if (Create-NewUnicodeTheme -ThemeName $newTheme) {
    Write-Host "Successfully created new Unicode theme: $newTheme" -ForegroundColor Green
    
    # Inspect the new theme
    Inspect-Theme -ThemeName $newTheme
    
    # Inspect other themes for comparison
    Inspect-Theme -ThemeName "Default"
    Inspect-Theme -ThemeName "RetroWave"
    Inspect-Theme -ThemeName "NeonCyberpunk"
} else {
    Write-Host "Failed to create new Unicode theme" -ForegroundColor Red
}

Write-Host "===== END OF DEEP THEME DEBUGGING =====" -ForegroundColor Cyan