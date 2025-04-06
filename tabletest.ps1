# tabletest.ps1
# Run this script to diagnose the Show-Table function

# Import modules with force
Import-Module "$PSScriptRoot\Modules\ProjectTracker.Core\ProjectTracker.Core.psd1" -Force

Write-Host "===== Show-Table Diagnostic =====" -ForegroundColor Cyan

# Make sure we have a theme set
Initialize-ThemeEngine
Set-CurrentTheme -ThemeName "Default"

# Test Render-Header first (simpler UI component)
try {
    Render-Header -Title "Test Header"
    Write-Host "✓ Render-Header executed without errors" -ForegroundColor Green
}
catch {
    Write-Host "✗ Render-Header failed: $($_.Exception.Message)" -ForegroundColor Red
}

# Test Show-Table with stepped debugging
Write-Host "Testing Show-Table..." -ForegroundColor Cyan
try {
    # Create simple test data
    $testData = @(
        [PSCustomObject]@{Name="Item 1"; Value=100; Status="Active"},
        [PSCustomObject]@{Name="Item 2"; Value=200; Status="Inactive"}
    )
    
    Write-Host "Attempting to display test table..." -ForegroundColor White
    
    # First test - basic table
    Write-Host "Test 1: Basic table rendering" -ForegroundColor Yellow
    $testDataCopy = @() + $testData # Make a copy to be safe
    Show-Table -Data $testDataCopy -Columns @("Name", "Value", "Status")
}
catch {
    Write-Host "✗ Show-Table failed: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack trace: at $($_.ScriptStackTrace)" -ForegroundColor Red
}

Write-Host "===== Show-Table Diagnostic Complete =====" -ForegroundColor Cyan