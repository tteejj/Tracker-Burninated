# Theme System Diagnostic Script
# Run this script from the root directory of your Project Tracker installation

# 1. Setup - make sure we load the Core module
$scriptDir = $PSScriptRoot
Write-Host "Running diagnostic from: $scriptDir" -ForegroundColor Cyan

# Try to import the Core module
try {
    Import-Module -Name "$scriptDir\Modules\ProjectTracker.Core\ProjectTracker.Core.psd1" -Force -ErrorAction Stop
    Write-Host "Successfully imported ProjectTracker.Core module" -ForegroundColor Green
} catch {
    Write-Host "CRITICAL ERROR: Failed to import ProjectTracker.Core module" -ForegroundColor Red
    Write-Host "Details: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack Trace: $($_.ScriptStackTrace)" -ForegroundColor Red
    exit 1
}

Write-Host "`n============= THEME DIAGNOSTIC REPORT =============" -ForegroundColor Cyan

# 2. Check config settings
Write-Host "`n-- CONFIGURATION SETTINGS --" -ForegroundColor Yellow
try {
    $config = Get-AppConfig
    Write-Host "BaseDataDir: $($config.BaseDataDir)" -ForegroundColor White
    Write-Host "ThemesDir: $($config.ThemesDir)" -ForegroundColor White
    Write-Host "DefaultTheme: $($config.DefaultTheme)" -ForegroundColor White
    Write-Host "DisplayDateFormat: $($config.DisplayDateFormat)" -ForegroundColor White
    
    # Check if directories exist
    Write-Host "`nChecking directories:" -ForegroundColor Yellow
    if (Test-Path $config.BaseDataDir) {
        Write-Host "BaseDataDir exists: $($config.BaseDataDir)" -ForegroundColor Green
    } else {
        Write-Host "ERROR: BaseDataDir doesn't exist: $($config.BaseDataDir)" -ForegroundColor Red
    }
    
    if (Test-Path $config.ThemesDir) {
        Write-Host "ThemesDir exists: $($config.ThemesDir)" -ForegroundColor Green
    } else {
        Write-Host "ERROR: ThemesDir doesn't exist: $($config.ThemesDir)" -ForegroundColor Red
    }
} catch {
    Write-Host "ERROR getting configuration: $($_.Exception.Message)" -ForegroundColor Red
}

# 3. Scan theme files
Write-Host "`n-- THEME FILES INVENTORY --" -ForegroundColor Yellow
try {
    $themeFiles = @()
    if (Test-Path $config.ThemesDir) {
        $themeFiles = Get-ChildItem -Path $config.ThemesDir -Filter "*.json" -File
        
        if ($themeFiles.Count -eq 0) {
            Write-Host "Warning: No theme files found in $($config.ThemesDir)" -ForegroundColor Yellow
        } else {
            Write-Host "Found $($themeFiles.Count) theme files:" -ForegroundColor Green
            
            foreach ($themeFile in $themeFiles) {
                Write-Host "  - $($themeFile.Name)" -ForegroundColor White
                
                # Try to parse the theme file
                try {
                    $themeContent = Get-Content -Path $themeFile.FullName -Raw
                    $themeJson = $themeContent | ConvertFrom-Json
                    
                    # Check for required properties
                    $hasName = $themeJson.PSObject.Properties.Name -contains 'Name'
                    $hasColors = $themeJson.PSObject.Properties.Name -contains 'Colors'
                    $hasTable = $themeJson.PSObject.Properties.Name -contains 'Table'
                    
                    $status = if ($hasName -and $hasColors -and $hasTable) { "Valid" } else { "INVALID" }
                    $statusColor = if ($status -eq "Valid") { "Green" } else { "Red" }
                    
                    Write-Host "    Status: $status" -ForegroundColor $statusColor
                    Write-Host "    Theme Name: $($themeJson.Name)" -ForegroundColor White
                    Write-Host "    UseAnsiColors: $($themeJson.UseAnsiColors)" -ForegroundColor White
                    
                    # List missing properties
                    if (-not $hasName) { Write-Host "    MISSING: Name property" -ForegroundColor Red }
                    if (-not $hasColors) { Write-Host "    MISSING: Colors property" -ForegroundColor Red }
                    if (-not $hasTable) { Write-Host "    MISSING: Table property" -ForegroundColor Red }
                    
                    # Check Table.Chars if exists
                    if ($hasTable -and ($themeJson.Table.PSObject.Properties.Name -contains 'Chars')) {
                        Write-Host "    Table.Chars: Present" -ForegroundColor Green
                    } elseif ($hasTable) {
                        Write-Host "    MISSING: Table.Chars property" -ForegroundColor Red
                    }
                } catch {
                    Write-Host "    ERROR: Failed to parse theme file: $($_.Exception.Message)" -ForegroundColor Red
                }
            }
        }
    } else {
        Write-Host "ERROR: Cannot scan themes directory because it doesn't exist" -ForegroundColor Red
    }
} catch {
    Write-Host "ERROR scanning theme files: $($_.Exception.Message)" -ForegroundColor Red
}

# 4. Check available themes
Write-Host "`n-- AVAILABLE THEMES --" -ForegroundColor Yellow
try {
    $themes = Get-AvailableThemes
    if ($themes -and $themes.Count -gt 0) {
        Write-Host "Found $($themes.Count) available themes:" -ForegroundColor Green
        
        foreach ($theme in $themes) {
            Write-Host "  - $($theme.Name) ($($theme.Type))" -ForegroundColor White
        }
    } else {
        Write-Host "ERROR: No themes available" -ForegroundColor Red
    }
} catch {
    Write-Host "ERROR accessing available themes: $($_.Exception.Message)" -ForegroundColor Red
}

# 5. Test theme loading
Write-Host "`n-- THEME LOADING TEST --" -ForegroundColor Yellow
$testThemes = @(
    "Default",
    "RetroWave",
    "NeonCyberpunk",
    "NonExistentTheme"  # This should fail gracefully
)

foreach ($testTheme in $testThemes) {
    Write-Host "`nTesting theme: $testTheme" -ForegroundColor Yellow
    
    try {
        $theme = Get-Theme -ThemeName $testTheme
        
        if ($theme) {
            Write-Host "  Successfully loaded theme: $($theme.Name)" -ForegroundColor Green
            
            # Check basic properties
            $checks = @(
                @{ Name = "Colors dictionary"; Check = { $theme.ContainsKey("Colors") -and $theme.Colors -is [hashtable] -and $theme.Colors.Count -gt 0 } },
                @{ Name = "Table dictionary"; Check = { $theme.ContainsKey("Table") -and $theme.Table -is [hashtable] } },
                @{ Name = "Table.Chars dictionary"; Check = { $theme.ContainsKey("Table") -and $theme.Table.ContainsKey("Chars") -and $theme.Table.Chars -is [hashtable] } },
                @{ Name = "UseAnsiColors property"; Check = { $theme.ContainsKey("UseAnsiColors") } }
            )
            
            foreach ($check in $checks) {
                $result = & $check.Check
                $resultText = if ($result) { "PASS" } else { "FAIL" }
                $resultColor = if ($result) { "Green" } else { "Red" }
                
                Write-Host "    $($check.Name): $resultText" -ForegroundColor $resultColor
            }
            
            # Check Color keys
            $requiredColors = @("Normal", "Header", "TableBorder", "Error", "Warning", "Success")
            foreach ($colorKey in $requiredColors) {
                $hasColor = $theme.Colors.ContainsKey($colorKey)
                $resultText = if ($hasColor) { "PRESENT" } else { "MISSING" }
                $resultColor = if ($hasColor) { "Green" } else { "Red" }
                
                Write-Host "    Color '$colorKey': $resultText" -ForegroundColor $resultColor
            }
            
            # Check Table chars
            if ($theme.Table.ContainsKey("Chars")) {
                $requiredChars = @("Horizontal", "Vertical", "TopLeft", "TopRight", "BottomLeft", "BottomRight")
                foreach ($charKey in $requiredChars) {
                    $hasChar = $theme.Table.Chars.ContainsKey($charKey)
                    $resultText = if ($hasChar) { "PRESENT" } else { "MISSING" }
                    $resultColor = if ($hasChar) { "Green" } else { "Red" }
                    
                    Write-Host "    Table.Chars '$charKey': $resultText" -ForegroundColor $resultColor
                }
            }
        } else {
            if ($testTheme -eq "NonExistentTheme") {
                Write-Host "  Expected: Could not load non-existent theme" -ForegroundColor Yellow
            } else {
                Write-Host "  ERROR: Failed to load theme, returned null" -ForegroundColor Red
            }
        }
    } catch {
        if ($testTheme -eq "NonExistentTheme") {
            Write-Host "  Expected error for non-existent theme: $($_.Exception.Message)" -ForegroundColor Yellow
        } else {
            Write-Host "  ERROR: Exception loading theme: $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}

# 6. Test theme switching
Write-Host "`n-- THEME SWITCHING TEST --" -ForegroundColor Yellow
try {
    $initialTheme = Get-CurrentTheme
    Write-Host "Initial theme: $($initialTheme.Name)" -ForegroundColor White
    
    # Try switching to different themes
    $themesToTest = @("Default", "RetroWave", "NeonCyberpunk")
    
    foreach ($themeName in $themesToTest) {
        Write-Host "`nSwitching to theme: $themeName" -ForegroundColor Yellow
        
        $result = Set-CurrentTheme -ThemeName $themeName
        if ($result) {
            $currentTheme = Get-CurrentTheme
            
            if ($currentTheme.Name -eq $themeName) {
                Write-Host "  Successfully switched to theme: $($currentTheme.Name)" -ForegroundColor Green
                
                # Test theme variables
                Write-Host "  Checking script variables:" -ForegroundColor White
                $useAnsiValue = $script:useAnsiColors
                if ($null -eq $useAnsiValue) {
                    Write-Host "    ERROR: Cannot access script:useAnsiColors - not accessible from this scope" -ForegroundColor Red
                } else {
                    Write-Host "    script:useAnsiColors = $useAnsiValue" -ForegroundColor Green
                }
                
                # Test some color rendering
                Write-Host "  Testing color rendering:" -ForegroundColor White
                try {
                    Write-ColorText "    This text should be in Normal color" -ForegroundColor $currentTheme.Colors.Normal
                    Write-ColorText "    This text should be in Header color" -ForegroundColor $currentTheme.Colors.Header
                    Write-ColorText "    This text should be in Error color" -ForegroundColor $currentTheme.Colors.Error
                } catch {
                    Write-Host "    ERROR rendering colors: $($_.Exception.Message)" -ForegroundColor Red
                }
                
                # Test a header
                Write-Host "`n  Testing header rendering:" -ForegroundColor White
                try {
                    Render-Header -Title "Test Header for $themeName" -Subtitle "Theme test subtitle"
                } catch {
                    Write-Host "    ERROR rendering header: $($_.Exception.Message)" -ForegroundColor Red
                }
                
                # Test a small table
                Write-Host "`n  Testing table rendering:" -ForegroundColor White
                try {
                    $data = @(
                        [PSCustomObject]@{ ID = 1; Name = "Item 1"; Status = "Active" },
                        [PSCustomObject]@{ ID = 2; Name = "Item 2"; Status = "Completed" }
                    )
                    
                    Show-Table -Data $data -Columns @("ID", "Name", "Status")
                } catch {
                    Write-Host "    ERROR rendering table: $($_.Exception.Message)" -ForegroundColor Red
                }
            } else {
                Write-Host "  ERROR: Set-CurrentTheme succeeded but Get-CurrentTheme returned wrong theme: $($currentTheme.Name)" -ForegroundColor Red
            }
        } else {
            Write-Host "  ERROR: Failed to switch theme" -ForegroundColor Red
        }
    }
    
    # Restore original theme
    Set-CurrentTheme -ThemeName $initialTheme.Name | Out-Null
} catch {
    Write-Host "ERROR testing theme switching: $($_.Exception.Message)" -ForegroundColor Red
}

# 7. Check ANSI detection logic
Write-Host "`n-- ANSI SUPPORT DETECTION --" -ForegroundColor Yellow
try {
    $isPSCore = $PSVersionTable.PSEdition -eq 'Core'
    $isVSCode = $env:TERM_PROGRAM -eq 'vscode' -or $host.Name -match 'Visual Studio Code'
    $isWindowsTerminal = $env:WT_SESSION -ne $null
    
    Write-Host "PowerShell Core (should support ANSI): $isPSCore" -ForegroundColor White
    Write-Host "VS Code Terminal (should support ANSI): $isVSCode" -ForegroundColor White  
    Write-Host "Windows Terminal (should support ANSI): $isWindowsTerminal" -ForegroundColor White
    
    $shouldSupportAnsi = $isPSCore -or $isVSCode -or $isWindowsTerminal
    Write-Host "ANSI support detected: $shouldSupportAnsi" -ForegroundColor $(if ($shouldSupportAnsi) { "Green" } else { "Yellow" })
    
    # Test ANSI directly
    Write-Host "`nANSI Color Test:" -ForegroundColor White
    Write-Host "`e[31mThis should be red`e[0m"
    Write-Host "`e[32mThis should be green`e[0m"
    Write-Host "`e[33mThis should be yellow`e[0m"
    Write-Host "`e[34mThis should be blue`e[0m"
    Write-Host "`e[35mThis should be magenta`e[0m"
    Write-Host "`e[36mThis should be cyan`e[0m"
    
    Write-Host "`nUnicode Test:" -ForegroundColor White
    Write-Host "Box Drawing: ┌───┐"
    Write-Host "             │   │"
    Write-Host "             └───┘"
    Write-Host "Symbols: ★ ☆ ◆ ◇ ● ○ ◎ ◉ ♠ ♥ ♦ ♣"
} catch {
    Write-Host "ERROR testing ANSI support: $($_.Exception.Message)" -ForegroundColor Red
}

# 8. Create a diagnostic Unicode theme
Write-Host "`n-- CREATING UNICODE TEST THEME --" -ForegroundColor Yellow
try {
    $unicodeTheme = @{
        Name = "UnicodeTest"
        Description = "Unicode test theme with ANSI colors"
        Author = "Diagnostic"
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
            Chars = @{
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
            RowSeparator = $true
            CellPadding = 1
            HeaderStyle = "Bold"
        }
        Headers = @{
            Style = "Simple"
            BorderChar = "─"
            Corners = "┌┐└┘"
        }
        Menu = @{
            SelectedPrefix = "►"
            UnselectedPrefix = " "
        }
        ProgressBar = @{
            FilledChar = "█"
            EmptyChar = "░"
            LeftCap = "["
            RightCap = "]"
        }
    }
    
    # Save the theme
    $themePath = Join-Path $config.ThemesDir "UnicodeTest.json"
    ConvertTo-Json -InputObject $unicodeTheme -Depth 10 | Out-File -FilePath $themePath -Encoding utf8
    
    if (Test-Path $themePath) {
        Write-Host "Successfully created Unicode test theme: $themePath" -ForegroundColor Green
        
        # Try to load and apply it
        Write-Host "`nTesting Unicode theme:" -ForegroundColor Yellow
        $result = Set-CurrentTheme -ThemeName "UnicodeTest"
        
        if ($result) {
            $currentTheme = Get-CurrentTheme
            Write-Host "Successfully switched to theme: $($currentTheme.Name)" -ForegroundColor Green
            
            # Test rendering with Unicode theme
            Render-Header -Title "Unicode Theme Test" -Subtitle "Should use Unicode box characters"
            
            $data = @(
                [PSCustomObject]@{ ID = 1; Name = "Unicode Test 1"; Status = "Active" },
                [PSCustomObject]@{ ID = 2; Name = "Unicode Test 2"; Status = "Completed" }
            )
            
            Show-Table -Data $data -Columns @("ID", "Name", "Status")
            
            # Restore original theme
            Set-CurrentTheme -ThemeName "Default" | Out-Null
        } else {
            Write-Host "ERROR: Failed to switch to Unicode test theme" -ForegroundColor Red
        }
    } else {
        Write-Host "ERROR: Failed to create Unicode test theme" -ForegroundColor Red
    }
} catch {
    Write-Host "ERROR creating Unicode test theme: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "`n=========== END OF DIAGNOSTIC REPORT ===========`n" -ForegroundColor Cyan