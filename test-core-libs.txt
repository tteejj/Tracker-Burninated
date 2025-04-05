# tests/test-core-libs.ps1
# Test harness for the core libraries
# Runs basic tests to verify functionality

# Clear the console
Clear-Host
Write-Host "========================================="
Write-Host "Project Tracker Core Libraries Test" -ForegroundColor Cyan
Write-Host "========================================="
Write-Host

# Track test results
$totalTests = 0
$passedTests = 0

# Helper function to run a test
function Test-Function {
    param(
        [string]$Name,
        [scriptblock]$Test,
        [scriptblock]$Expected
    )
    
    $global:totalTests++
    
    Write-Host "Testing $Name... " -NoNewline
    
    try {
        $result = & $Test
        $expectedResult = & $Expected
        
        if ($result -eq $expectedResult) {
            Write-Host "PASSED" -ForegroundColor Green
            $global:passedTests++
        } else {
            Write-Host "FAILED" -ForegroundColor Red
            Write-Host "  Expected: $expectedResult"
            Write-Host "  Actual:   $result"
        }
    } catch {
        Write-Host "ERROR" -ForegroundColor Red
        Write-Host "  Exception: $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Helper function to test file existence
function Test-FileExists {
    param([string]$Path)
    
    $global:totalTests++
    
    Write-Host "Testing file exists: $Path... " -NoNewline
    
    if (Test-Path $Path) {
        Write-Host "PASSED" -ForegroundColor Green
        $global:passedTests++
    } else {
        Write-Host "FAILED" -ForegroundColor Red
    }
}

# Load core libraries
Write-Host "Loading core libraries..." -ForegroundColor Yellow
$scriptRoot = if ($PSScriptRoot) { $PSScriptRoot } else { "." }
$libPath = Join-Path (Split-Path -Parent $scriptRoot) "lib"

# Create a list of core library files to load
$libraryFiles = @(
    "config.ps1",
    "error-handling.ps1",
    "logging.ps1",
    "theme-engine.ps1",
    "date-functions.ps1",
    "helper-functions.ps1"
)

# Verify all library files exist
foreach ($file in $libraryFiles) {
    $filePath = Join-Path $libPath $file
    Test-FileExists -Path $filePath
}

# Load each library
foreach ($file in $libraryFiles) {
    $filePath = Join-Path $libPath $file
    
    if (Test-Path $filePath) {
        try {
            Write-Host "Loading $file... " -NoNewline
            . $filePath
            Write-Host "OK" -ForegroundColor Green
        } catch {
            Write-Host "ERROR" -ForegroundColor Red
            Write-Host "  $($_.Exception.Message)" -ForegroundColor Red
        }
    }
}

Write-Host
Write-Host "Running tests..." -ForegroundColor Yellow
Write-Host "----------------------------------------"

# Test config.ps1
if (Get-Command "Get-AppConfig" -ErrorAction SilentlyContinue) {
    Test-Function -Name "Get-AppConfig returns a hashtable" -Test {
        $config = Get-AppConfig
        $config -is [hashtable]
    } -Expected { $true }
    
    Test-Function -Name "Get-AppConfig contains BaseDataDir" -Test {
        $config = Get-AppConfig
        $config.ContainsKey("BaseDataDir")
    } -Expected { $true }
}

# Test error-handling.ps1
if (Get-Command "Invoke-WithErrorHandling" -ErrorAction SilentlyContinue) {
    Test-Function -Name "Invoke-WithErrorHandling success path" -Test {
        Invoke-WithErrorHandling -ScriptBlock { 1 + 1 } -ErrorContext "Test"
    } -Expected { 2 }
    
    Test-Function -Name "Invoke-WithErrorHandling with Continue returns default" -Test {
        Invoke-WithErrorHandling -ScriptBlock { throw "Test error" } -ErrorContext "Test" -Continue -Silent -DefaultValue 42
    } -Expected { 42 }
}

# Test theme-engine.ps1
if (Get-Command "Get-Theme" -ErrorAction SilentlyContinue) {
    Test-Function -Name "Get-Theme returns default theme" -Test {
        $theme = Get-Theme -ThemeName "Default"
        $theme.Name
    } -Expected { "Default" }
    
    # Initialize the theme engine if the function exists
    if (Get-Command "Initialize-ThemeEngine" -ErrorAction SilentlyContinue) {
        Initialize-ThemeEngine | Out-Null
    }
    
    # Test Write-ColorText
    if (Get-Command "Write-ColorText" -ErrorAction SilentlyContinue) {
        Write-Host "Testing Write-ColorText with various colors:"
        Write-ColorText "  This text should be in default color" -ForegroundColor "White"
        Write-ColorText "  This text should be in red" -ForegroundColor "Red"
        Write-ColorText "  This text should be in green" -ForegroundColor "Green"
        Write-ColorText "  This text should be in blue" -ForegroundColor "Blue"
        Write-ColorText "  This text should be in yellow" -ForegroundColor "Yellow"
        Write-Host
    }
    
    # Test Render-Header
    if (Get-Command "Render-Header" -ErrorAction SilentlyContinue) {
        Write-Host "Testing Render-Header:"
        Render-Header -Title "Test Header" -Subtitle "This is a test"
        Write-Host
    }
}

# Test date-functions.ps1
if (Get-Command "Parse-DateInput" -ErrorAction SilentlyContinue) {
    Test-Function -Name "Parse-DateInput with MM/DD/YYYY" -Test {
        Parse-DateInput -InputDate "04/15/2023"
    } -Expected { "20230415" }
    
    Test-Function -Name "Convert-InternalDateToDisplay" -Test {
        # Assuming default display format is MM/dd/yyyy
        Convert-InternalDateToDisplay -InternalDate "20230415" -DisplayFormat "MM/dd/yyyy"
    } -Expected { "04/15/2023" }
}

# Test helper-functions.ps1
if (Get-Command "Convert-PriorityToInt" -ErrorAction SilentlyContinue) {
    Test-Function -Name "Convert-PriorityToInt with High" -Test {
        Convert-PriorityToInt -Priority "High"
    } -Expected { 1 }
    
    Test-Function -Name "Convert-PriorityToInt with Low" -Test {
        Convert-PriorityToInt -Priority "Low"
    } -Expected { 3 }
}

if (Get-Command "ConvertTo-ValidFileName" -ErrorAction SilentlyContinue) {
    Test-Function -Name "ConvertTo-ValidFileName" -Test {
        ConvertTo-ValidFileName -InputString "File: Test/2023"
    } -Expected { "File_ Test_2023" }
}

# Test a simple table if the function exists
if (Get-Command "Show-Table" -ErrorAction SilentlyContinue) {
    Write-Host "Testing Show-Table:"
    
    # Create some sample data
    $testData = @(
        [PSCustomObject]@{ Name = "Project 1"; Status = "Active"; DueDate = "20230415" },
        [PSCustomObject]@{ Name = "Project 2"; Status = "Completed"; DueDate = "20230301" },
        [PSCustomObject]@{ Name = "Project 3"; Status = "On Hold"; DueDate = "20230701" }
    )
    
    # Define formatters
    $formatters = @{
        DueDate = { param($val) Convert-InternalDateToDisplay -InternalDate $val }
    }
    
    # Display the table
    Show-Table -Data $testData -Columns @("Name", "Status", "DueDate") -Formatters $formatters
    
    Write-Host
}

# Test InfoBox if it exists
if (Get-Command "Show-InfoBox" -ErrorAction SilentlyContinue) {
    Write-Host "Testing Show-InfoBox:"
    Show-InfoBox -Title "Test Info Box" -Message "This is a test message to see how the info box appears with theme settings." -Type Info
    Write-Host
    
    Show-InfoBox -Title "Test Warning Box" -Message "This is a test warning message." -Type Warning
    Write-Host
    
    Show-InfoBox -Title "Test Error Box" -Message "This is a test error message." -Type Error
    Write-Host
    
    Show-InfoBox -Title "Test Success Box" -Message "This is a test success message." -Type Success
    Write-Host
}

# Summary of test results
Write-Host "========================================="
Write-Host "Test Summary:" -ForegroundColor Yellow
Write-Host "  Total Tests: $totalTests"
Write-Host "  Passed Tests: $passedTests" -ForegroundColor $(if ($passedTests -eq $totalTests) { "Green" } else { "Red" })
Write-Host "  Failed Tests: $($totalTests - $passedTests)" -ForegroundColor $(if ($passedTests -eq $totalTests) { "Green" } else { "Red" })
Write-Host "========================================="

# Return success if all tests passed
exit ($passedTests -eq $totalTests)
