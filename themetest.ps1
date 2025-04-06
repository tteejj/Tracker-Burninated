# theme-diagnostic.ps1
# Tests theme loading and initialization, isolating theme engine issues

# Set verbosity
$VerbosePreference = 'Continue'
$ErrorActionPreference = 'Continue'

# Get script directory
$scriptDir = $PSScriptRoot

Write-Host "===== Theme Engine Diagnostic Test =====" -ForegroundColor Cyan

# 1. Import Core module only (to test theme engine in isolation)
try {
    Write-Host "STEP 1: Importing Core module..." -ForegroundColor Yellow
    Import-Module -Name "$scriptDir\Modules\ProjectTracker.Core\ProjectTracker.Core.psd1" -Force -ErrorAction Stop
    Write-Host "✓ Core module imported successfully" -ForegroundColor Green
} catch {
    Write-Host "✗ Failed to import Core module: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Exception type: $($_.Exception.GetType().FullName)" -ForegroundColor Red
    Write-Host "Stack trace: $($_.ScriptStackTrace)" -ForegroundColor DarkGray
    exit 1
}

# 2. Test config module first
Write-Host "`nSTEP 2: Testing config access..." -ForegroundColor Yellow
try {
    $config = Get-AppConfig
    Write-Host "✓ Got config successfully" -ForegroundColor Green
    
    # Check theme-related config settings
    Write-Host "  - Base data directory: $($config.BaseDataDir)" -ForegroundColor DarkGray
    Write-Host "  - Themes directory: $($config.ThemesDir)" -ForegroundColor DarkGray
    Write-Host "  - Default theme name: $($config.DefaultTheme)" -ForegroundColor DarkGray
    Write-Host "  - Display date format: $($config.DisplayDateFormat)" -ForegroundColor DarkGray
    
    # Check if themes directory exists
    if (Test-Path $config.ThemesDir) {
        Write-Host "✓ Themes directory exists" -ForegroundColor Green
        
        # List theme files
        $themeFiles = Get-ChildItem -Path $config.ThemesDir -Filter "*.json" -ErrorAction SilentlyContinue
        Write-Host "  - Found $($themeFiles.Count) theme files:" -ForegroundColor DarkGray
        foreach ($file in $themeFiles) {
            Write-Host "    * $($file.Name)" -ForegroundColor DarkGray
        }
    } else {
        Write-Host "✗ Themes directory does not exist: $($config.ThemesDir)" -ForegroundColor Red
    }
} catch {
    Write-Host "✗ Failed to access config: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack trace: $($_.ScriptStackTrace)" -ForegroundColor DarkGray
}

# 3. Test theme engine initialization
Write-Host "`nSTEP 3: Testing theme engine initialization..." -ForegroundColor Yellow
try {
    $result = Initialize-ThemeEngine
    Write-Host "✓ Theme engine initialization: $result" -ForegroundColor Green
} catch {
    Write-Host "✗ Failed to initialize theme engine: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack trace: $($_.ScriptStackTrace)" -ForegroundColor DarkGray
}

# 4. Check available themes
Write-Host "`nSTEP 4: Testing available themes..." -ForegroundColor Yellow
try {
    $themes = Get-AvailableThemes
    Write-Host "✓ Got available themes list: $($themes.Count) themes" -ForegroundColor Green
    
    foreach ($theme in $themes) {
        Write-Host "  === Theme: $($theme.Name) ===" -ForegroundColor Cyan
        Write-Host "  - Type: $($theme.Type)" -ForegroundColor DarkGray
        Write-Host "  - Source: $($theme.Source)" -ForegroundColor DarkGray
        
        # Check if ThemeObject is available
        if ($null -eq $theme.ThemeObject) {
            Write-Host "  ✗ ThemeObject is NULL" -ForegroundColor Red
        } else {
            Write-Host "  ✓ ThemeObject is present" -ForegroundColor Green
        }
    }
} catch {
    Write-Host "✗ Failed to get available themes: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack trace: $($_.ScriptStackTrace)" -ForegroundColor DarkGray
}

# 5. Check current theme
Write-Host "`nSTEP 5: Testing current theme..." -ForegroundColor Yellow
try {
    $currentTheme = Get-CurrentTheme
    if ($null -eq $currentTheme) {
        Write-Host "✗ Current theme is NULL" -ForegroundColor Red
    } else {
        Write-Host "✓ Current theme is '$($currentTheme.Name)'" -ForegroundColor Green
        
        # Check critical theme properties
        if ($null -eq $currentTheme.Colors) {
            Write-Host "  ✗ Theme.Colors is NULL" -ForegroundColor Red
        } else {
            Write-Host "  ✓ Theme.Colors is present with ${($currentTheme.Colors.Count)} color definitions" -ForegroundColor Green
            
            # Check critical colors
            $requiredColors = @("Normal", "Header", "Accent1", "Error", "Warning", "Success", "TableBorder")
            $missingColors = @()
            foreach ($color in $requiredColors) {
                if ($null -eq $currentTheme.Colors[$color] -or $currentTheme.Colors[$color] -eq "") {
                    $missingColors += $color
                }
            }
            
            if ($missingColors.Count -gt 0) {
                Write-Host "  ✗ Missing required colors: $($missingColors -join ', ')" -ForegroundColor Red
            } else {
                Write-Host "  ✓ All required colors are defined" -ForegroundColor Green
            }
        }
        
        if ($null -eq $currentTheme.Table) {
            Write-Host "  ✗ Theme.Table is NULL" -ForegroundColor Red
        } else {
            Write-Host "  ✓ Theme.Table is present" -ForegroundColor Green
            
            if ($null -eq $currentTheme.Table.Chars) {
                Write-Host "    ✗ Theme.Table.Chars is NULL" -ForegroundColor Red
            } else {
                Write-Host "    ✓ Theme.Table.Chars is present with ${($currentTheme.Table.Chars.Count)} char definitions" -ForegroundColor Green
            }
        }
        
        # Print all theme properties for debugging
        Write-Host "`n  === Current Theme Structure ===" -ForegroundColor Cyan
        $currentTheme.GetEnumerator() | Sort-Object Name | ForEach-Object {
            $key = $_.Key
            $valueType = if ($null -eq $_.Value) { "NULL" } else { $_.Value.GetType().Name }
            $valuePreview = if ($null -eq $_.Value) { "NULL" } 
                           elseif ($_.Value -is [hashtable]) { "Hashtable with $($_.Value.Count) items" }
                           elseif ($_.Value -is [array]) { "Array with $($_.Value.Count) items" }
                           else { $_.Value.ToString() }
            
            Write-Host "  - $key : [$valueType] $valuePreview" -ForegroundColor DarkGray
        }
    }
} catch {
    Write-Host "✗ Failed to get current theme: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack trace: $($_.ScriptStackTrace)" -ForegroundColor DarkGray
}

# 6. Test setting a different theme
Write-Host "`nSTEP 6: Testing theme switching..." -ForegroundColor Yellow
try {
    $themeToTest = "RetroWave" # Try a different theme than the default
    $result = Set-CurrentTheme -ThemeName $themeToTest
    Write-Host "✓ Theme change result: $result" -ForegroundColor Green
    
    # Verify the change
    $currentTheme = Get-CurrentTheme
    if ($currentTheme.Name -eq $themeToTest) {
        Write-Host "✓ Theme successfully changed to '$themeToTest'" -ForegroundColor Green
    } else {
        Write-Host "✗ Theme did not change correctly. Current theme: '$($currentTheme.Name)'" -ForegroundColor Red
    }
} catch {
    Write-Host "✗ Failed to change theme: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack trace: $($_.ScriptStackTrace)" -ForegroundColor DarkGray
}

# 7. Test basic UI drawing functions
Write-Host "`nSTEP 7: Testing basic UI output..." -ForegroundColor Yellow

# Show a simple infobox
try {
    Write-Host "Testing Show-InfoBox..." -ForegroundColor Yellow
    Show-InfoBox -Title "Test Info Box" -Message "This is a test message to verify theme rendering." -Type "Info"
    Write-Host "✓ Show-InfoBox executed without errors" -ForegroundColor Green
} catch {
    Write-Host "✗ Show-InfoBox failed: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack trace: $($_.ScriptStackTrace)" -ForegroundColor DarkGray
}

# Test Write-ColorText
try {
    Write-Host "`nTesting Write-ColorText..." -ForegroundColor Yellow
    Write-Host "Normal color text:" -ForegroundColor Yellow
    Write-ColorText "  This text should be in the 'Normal' color from the theme"
    
    Write-Host "Themed colors:" -ForegroundColor Yellow
    $colors = $currentTheme.Colors
    if ($null -ne $colors) {
        foreach ($color in $colors.Keys | Sort-Object) {
            Write-ColorText "  This text should be in the '$color' color" -ForegroundColor $colors[$color]
        }
        Write-Host "✓ Write-ColorText executed without errors" -ForegroundColor Green
    } else {
        Write-Host "✗ Cannot test colors - theme.Colors is NULL" -ForegroundColor Red
    }
} catch {
    Write-Host "✗ Write-ColorText failed: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack trace: $($_.ScriptStackTrace)" -ForegroundColor DarkGray
}

# Test Render-Header
try {
    Write-Host "`nTesting Render-Header..." -ForegroundColor Yellow
    Render-Header -Title "Test Header" -Subtitle "This is a test subtitle"
    Write-Host "✓ Render-Header executed without errors" -ForegroundColor Green
} catch {
    Write-Host "✗ Render-Header failed: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack trace: $($_.ScriptStackTrace)" -ForegroundColor DarkGray
}

# Test Show-Table (most problematic function)
try {
    Write-Host "`nTesting Show-Table..." -ForegroundColor Yellow
    
    # Create test data
    $testData = @(
        [PSCustomObject]@{ Name = "Item 1"; Status = "Active"; Description = "First test item" },
        [PSCustomObject]@{ Name = "Item 2"; Status = "Pending"; Description = "Second test item" }
    )
    
    Write-Host "Attempting to display test table..." -ForegroundColor Yellow
    
    # Inspect/debug display elements before running
    Write-Host "Current theme table settings:" -ForegroundColor DarkGray
    if ($null -ne $currentTheme.Table) {
        $currentTheme.Table | ConvertTo-Json -Depth 3 | Write-Host -ForegroundColor DarkGray
    } else {
        Write-Host "  Theme.Table is NULL" -ForegroundColor Red
    }
    
    Show-Table -Data $testData -Columns @("Name", "Status", "Description")
    Write-Host "✓ Show-Table executed without errors" -ForegroundColor Green
} catch {
    Write-Host "✗ Show-Table failed: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack trace: $($_.ScriptStackTrace)" -ForegroundColor DarkGray
}

Write-Host "`n===== Theme Engine Diagnostic Complete =====" -ForegroundColor Cyan