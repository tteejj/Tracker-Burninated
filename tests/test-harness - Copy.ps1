# test-harness.ps1
# Simple script to test and verify core libraries functionality

# Define paths
$scriptRoot = if ($PSScriptRoot) { $PSScriptRoot } else { "." }
$libPath = Join-Path $scriptRoot "lib"

# Display header
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "           Project Tracker Core Library Tests   " -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host ""

# Track test results
$testsRun = 0
$testsPassed = 0
$testsFailed = 0

# Define test function
function Test-Feature {
    param(
        [string]$Name,
        [scriptblock]$Code,
        [switch]$ContinueOnError
    )
    
    Write-Host "Testing: $Name" -ForegroundColor Yellow -NoNewline
    Write-Host " ..." -NoNewline
    
    $global:testsRun++
    
    try {
        & $Code
        $global:testsPassed++
        Write-Host " [PASSED]" -ForegroundColor Green
    }
    catch {
        $global:testsFailed++
        Write-Host " [FAILED]" -ForegroundColor Red
        Write-Host "  Error: $($_.Exception.Message)" -ForegroundColor Red
        
        if (-not $ContinueOnError) {
            Write-Host "`nTest failed. Stopping tests." -ForegroundColor Red
            Write-Host "Summary: $testsRun tests, $testsPassed passed, $testsFailed failed`n" -ForegroundColor Yellow
            exit 1
        }
    }
}

# Step 1: Load core libraries
Write-Host "Loading core libraries..." -ForegroundColor Cyan
Write-Host ""

# List of libraries to test
$coreLibraries = @(
    "config.ps1",
    "error-handling.ps1",
    "logging.ps1",
    "date-functions.ps1",
    "helper-functions.ps1",
    "data-functions.ps1",
    "theme-engine.ps1"
)

# Load each library
foreach ($lib in $coreLibraries) {
    Test-Feature -Name "Loading $lib" -Code {
        $libFile = Join-Path $libPath $lib
        if (Test-Path $libFile) {
            # Dot-source the script to load its functions
            . $libFile
        } else {
            throw "Library file not found: $libFile"
        }
    } -ContinueOnError
}

Write-Host ""
Write-Host "Testing individual components..." -ForegroundColor Cyan
Write-Host ""

# Test Configuration Functions
Test-Feature -Name "Configuration Functions" -Code {
    $config = Get-AppConfig
    if (-not $config -or -not $config.ContainsKey("BaseDataDir")) {
        throw "Config not loaded properly"
    }
    
    Write-Host ""
    Write-Host "  Config loaded successfully" -ForegroundColor DarkGray
    Write-Host "  Base Directory: $($config.BaseDataDir)" -ForegroundColor DarkGray
    Write-Host "  Log File: $($config.LogFullPath)" -ForegroundColor DarkGray
} -ContinueOnError

# Test Error Handling Functions
Test-Feature -Name "Error Handling Functions" -Code {
    # Just test that the function exists
    if (-not (Get-Command "Handle-Error" -ErrorAction SilentlyContinue)) {
        throw "Handle-Error function not found"
    }
    
    if (-not (Get-Command "Invoke-WithErrorHandling" -ErrorAction SilentlyContinue)) {
        throw "Invoke-WithErrorHandling function not found"
    }
    
    # Test with a controlled error
    $result = Invoke-WithErrorHandling -ScriptBlock {
        "Success"
    } -ErrorContext "Test" -Continue
    
    if ($result -ne "Success") {
        throw "Error handling failed with valid input"
    }
    
    Write-Host ""
    Write-Host "  Error handling functions loaded successfully" -ForegroundColor DarkGray
} -ContinueOnError

# Test Logging Functions
Test-Feature -Name "Logging Functions" -Code {
    if (-not (Get-Command "Write-AppLog" -ErrorAction SilentlyContinue)) {
        throw "Write-AppLog function not found"
    }
    
    # Test log write
    Write-AppLog "Test log entry from test-harness.ps1" -Level INFO
    
    Write-Host ""
    Write-Host "  Logged test message successfully" -ForegroundColor DarkGray
} -ContinueOnError

# Test Date Functions
Test-Feature -Name "Date Functions" -Code {
    if (-not (Get-Command "Parse-DateInput" -ErrorAction SilentlyContinue)) {
        throw "Parse-DateInput function not found"
    }
    
    # Test date parsing
    $testDate = "04/15/2023"
    $parsedDate = Parse-DateInput -InputDate $testDate
    
    if (-not $parsedDate -or $parsedDate -eq "CANCEL") {
        throw "Date parsing failed for: $testDate"
    }
    
    $displayDate = Convert-InternalDateToDisplay -InternalDate $parsedDate
    
    Write-Host ""
    Write-Host "  Date functions working properly" -ForegroundColor DarkGray
    Write-Host "  Parsed date: $parsedDate" -ForegroundColor DarkGray
    Write-Host "  Display date: $displayDate" -ForegroundColor DarkGray
} -ContinueOnError

# Test Helper Functions
Test-Feature -Name "Helper Functions" -Code {
    if (-not (Get-Command "Read-UserInput" -ErrorAction SilentlyContinue)) {
        throw "Read-UserInput function not found"
    }
    
    if (-not (Get-Command "Confirm-Action" -ErrorAction SilentlyContinue)) {
        throw "Confirm-Action function not found"
    }
    
    if (-not (Get-Command "New-ID" -ErrorAction SilentlyContinue)) {
        throw "New-ID function not found"
    }
    
    # Test ID generation
    $id = New-ID
    
    Write-Host ""
    Write-Host "  Helper functions loaded successfully" -ForegroundColor DarkGray
    Write-Host "  Generated ID: $id" -ForegroundColor DarkGray
} -ContinueOnError

# Test Data Functions
Test-Feature -Name "Data Functions" -Code {
    if (-not (Get-Command "Get-EntityData" -ErrorAction SilentlyContinue)) {
        throw "Get-EntityData function not found"
    }
    
    if (-not (Get-Command "Save-EntityData" -ErrorAction SilentlyContinue)) {
        throw "Save-EntityData function not found"
    }
    
    # Create temporary test file
    $testDir = Join-Path $env:TEMP "ProjectTrackerTest"
    $testFile = Join-Path $testDir "test.csv"
    
    if (-not (Test-Path $testDir)) {
        New-Item -Path $testDir -ItemType Directory -Force | Out-Null
    }
    
    # Create test data
    $testData = @(
        [PSCustomObject]@{Name = "Test1"; Value = 1},
        [PSCustomObject]@{Name = "Test2"; Value = 2}
    )
    
    # Save test data
    $success = Save-EntityData -Data $testData -FilePath $testFile
    
    if (-not $success) {
        throw "Failed to save test data"
    }
    
    # Read test data
    $loadedData = @(Get-EntityData -FilePath $testFile)
    
    if ($loadedData.Count -ne 2) {
        throw "Failed to load test data (expected 2 items, got $($loadedData.Count))"
    }
    
    Write-Host ""
    Write-Host "  Data functions working properly" -ForegroundColor DarkGray
    Write-Host "  Saved and loaded test data successfully" -ForegroundColor DarkGray
    
    # Clean up test file
    Remove-Item -Path $testFile -Force -ErrorAction SilentlyContinue
} -ContinueOnError

# Test Theme Engine
Test-Feature -Name "Theme Engine" -Code {
    if (-not (Get-Command "Initialize-ThemeEngine" -ErrorAction SilentlyContinue)) {
        throw "Initialize-ThemeEngine function not found"
    }
    
    # Initialize the theme engine
    Initialize-ThemeEngine | Out-Null
    
    # Get current theme
    $theme = Get-CurrentTheme
    
    if (-not $theme -or -not $theme.ContainsKey("Name")) {
        throw "Theme engine initialization failed"
    }
    
    Write-Host ""
    Write-Host "  Theme engine initialized successfully" -ForegroundColor DarkGray
    Write-Host "  Current theme: $($theme.Name)" -ForegroundColor DarkGray
    
    # Test theme functions
    $availableThemes = Get-AvailableThemes
    Write-Host "  Available themes: $($availableThemes.Count)" -ForegroundColor DarkGray
    
    # Test output functions
    Write-ColorText "This is a test of the colored text output" -ForegroundColor Green
} -ContinueOnError

# Display UI Components
Write-Host ""
Write-Host "Testing UI Components..." -ForegroundColor Cyan
Write-Host ""

# Test Header Rendering
Test-Feature -Name "Header Rendering" -Code {
    if (-not (Get-Command "Render-Header" -ErrorAction SilentlyContinue)) {
        throw "Render-Header function not found"
    }
    
    Render-Header -Title "Test Header" -Subtitle "This is a test"
} -ContinueOnError

# Test Table Display
Test-Feature -Name "Table Display" -Code {
    if (-not (Get-Command "Show-Table" -ErrorAction SilentlyContinue)) {
        throw "Show-Table function not found"
    }
    
    $testData = @(
        [PSCustomObject]@{Name = "Item 1"; Value = 10; Status = "Active"},
        [PSCustomObject]@{Name = "Item 2"; Value = 20; Status = "Pending"},
        [PSCustomObject]@{Name = "Item 3"; Value = 30; Status = "Completed"}
    )
    
    $columns = @("Name", "Value", "Status")
    $headers = @{Value = "Amount"}
    $formatters = @{
        Value = { param($val) "$val units" }
    }
    
    $rowColorizer = {
        param($item)
        if ($item.Status -eq "Completed") {
            return "DarkGray"
        }
        return "White"
    }
    
    Write-Host ""
    Write-Host "  Sample Table:" -ForegroundColor DarkGray
    Show-Table -Data $testData -Columns $columns -Headers $headers -Formatters $formatters -RowColorizer $rowColorizer
} -ContinueOnError

# Test Info Box
Test-Feature -Name "Info Box" -Code {
    if (-not (Get-Command "Show-InfoBox" -ErrorAction SilentlyContinue)) {
        throw "Show-InfoBox function not found"
    }
    
    Show-InfoBox -Title "Test Info Box" -Message "This is a test info box to verify functionality." -Type "Info"
    Show-InfoBox -Title "Test Warning" -Message "This is a warning message." -Type "Warning"
    Show-InfoBox -Title "Test Error" -Message "This is an error message." -Type "Error"
} -ContinueOnError

# Test Progress Bar
Test-Feature -Name "Progress Bar" -Code {
    if (-not (Get-Command "Show-ProgressBar" -ErrorAction SilentlyContinue)) {
        throw "Show-ProgressBar function not found"
    }
    
    Write-Host ""
    Write-Host "  Sample Progress Bars:" -ForegroundColor DarkGray
    Show-ProgressBar -PercentComplete 25 -Width 40 -Text "25% Complete"
    Show-ProgressBar -PercentComplete 50 -Width 40 -Text "50% Complete"
    Show-ProgressBar -PercentComplete 75 -Width 40 -Text "75% Complete"
    Show-ProgressBar -PercentComplete 100 -Width 40 -Text "100% Complete"
} -ContinueOnError

# Print summary
Write-Host ""
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "Test Summary" -ForegroundColor Cyan
Write-Host "================================================" -ForegroundColor Cyan
Write-Host "Total Tests: $testsRun" -ForegroundColor Yellow
Write-Host "Passed:      $testsPassed" -ForegroundColor Green
Write-Host "Failed:      $testsFailed" -ForegroundColor Red
Write-Host ""

if ($testsFailed -gt 0) {
    Write-Host "Some tests failed. Please review the errors above." -ForegroundColor Red
    exit 1
} else {
    Write-Host "All tests passed successfully! Core libraries are functioning properly." -ForegroundColor Green
    exit 0
}
