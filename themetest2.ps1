# themetest.ps1
# Run this script to diagnose theme-related issues

# Import modules with force to ensure latest version
Import-Module "$PSScriptRoot\Modules\ProjectTracker.Core\ProjectTracker.Core.psd1" -Force

Write-Host "===== Theme Engine Diagnostic =====" -ForegroundColor Cyan

# Test theme engine initialization
try {
    Initialize-ThemeEngine
    Write-Host "✓ Theme engine initialized" -ForegroundColor Green
}
catch {
    Write-Host "✗ Theme engine initialization failed $($_.Exception.Message)" -ForegroundColor Red
}

# Check available themes
try {
    $themes = Get-AvailableThemes
    Write-Host "Found $($themes.Count) themes:" -ForegroundColor Green
    foreach ($theme in $themes) {
        Write-Host "  - $($theme.Name) ($($theme.Type))" -ForegroundColor White
    }
}
catch {
    Write-Host "✗ Get-AvailableThemes failed: $($_.Exception.Message)" -ForegroundColor Red
}

# Try changing themes
$themesToTest = @("Default", "NeonCyberpunk", "RetroWave")
foreach ($themeName in $themesToTest) {
    try {
        Write-Host "Attempting to switch to $themeName..." -ForegroundColor White
        $result = Set-CurrentTheme -ThemeName $themeName
        if ($result) {
            Write-Host "✓ Successfully switched to $themeName" -ForegroundColor Green
        }
        else {
            Write-Host "✗ Set-CurrentTheme returned false for $themeName" -ForegroundColor Red
        }
    }
    catch {
        Write-Host "✗ Theme switching failed for $themeName $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Test table rendering
try {
    # Create simple test data
    $testData = @(
        [PSCustomObject]@{Name="Item 1"; Value=100; Status="Active"},
        [PSCustomObject]@{Name="Item 2"; Value=200; Status="Inactive"}
    )
    
    Show-Table -Data $testData -Columns @("Name", "Value", "Status")
    Write-Host "✓ Show-Table executed without errors" -ForegroundColor Green
}
catch {
    Write-Host "✗ Show-Table failed: $($_.Exception.Message)" -ForegroundColor Red
}

Write-Host "===== Theme Engine Diagnostic Complete =====" -ForegroundColor Cyan