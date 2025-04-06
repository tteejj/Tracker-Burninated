# menu-diagnostic.ps1
# Tests menu flow to identify issues with navigation and return values

# Set verbosity
$VerbosePreference = 'Continue'
$ErrorActionPreference = 'Continue'

# Get script directory
$scriptDir = $PSScriptRoot

Write-Host "===== Menu Flow Diagnostic Test =====" -ForegroundColor Cyan

# 1. Import Core module
try {
    Write-Host "STEP 1: Importing Core module..." -ForegroundColor Yellow
    Import-Module -Name "$scriptDir\Modules\ProjectTracker.Core\ProjectTracker.Core.psd1" -Force -ErrorAction Stop
    Write-Host "✓ Core module imported successfully" -ForegroundColor Green
} catch {
    Write-Host "✗ Failed to import Core module: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# 2. Initialize environment
Write-Host "`nSTEP 2: Initializing environment..." -ForegroundColor Yellow
try {
    Initialize-DataEnvironment
    Initialize-ThemeEngine
    Write-Host "✓ Environment initialized successfully" -ForegroundColor Green
} catch {
    Write-Host "✗ Failed to initialize environment: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack trace: $($_.ScriptStackTrace)" -ForegroundColor DarkGray
}

# 3. Test simple menu functions
Write-Host "`nSTEP 3: Testing menu function return values..." -ForegroundColor Yellow

# Define a test menu creation function
function Create-TestMenu {
    param(
        [string]$Title = "Test Menu",
        [string]$ExitReturnValue = $null
    )
    
    $menuItems = @()
    
    $menuItems += @{
        Type = "header"
        Text = $Title
    }
    
    $menuItems += @{
        Type = "option"
        Key = "1"
        Text = "Option that returns null"
        Function = {
            Write-Host "  Selected Option 1 (returns null)" -ForegroundColor DarkGray
            return $null
        }
    }
    
    $menuItems += @{
        Type = "option"
        Key = "2"
        Text = "Option that returns string"
        Function = {
            Write-Host "  Selected Option 2 (returns string)" -ForegroundColor DarkGray
            return "StringResult"
        }
    }
    
    $menuItems += @{
        Type = "option"
        Key = "3"
        Text = "Option that returns boolean TRUE"
        Function = {
            Write-Host "  Selected Option 3 (returns TRUE)" -ForegroundColor DarkGray
            return $true
        }
    }
    
    $menuItems += @{
        Type = "option"
        Key = "4"
        Text = "Option that returns boolean FALSE"
        Function = {
            Write-Host "  Selected Option 4 (returns FALSE)" -ForegroundColor DarkGray
            return $false
        }
    }
    
    $menuItems += @{
        Type = "separator"
    }
    
    $menuItems += @{
        Type = "option"
        Key = "0"
        Text = "Exit"
        Function = {
            Write-Host "  Selected Exit (returns $ExitReturnValue)" -ForegroundColor DarkGray
            return $ExitReturnValue
        }
        IsExit = $true
    }
    
    return $menuItems
}

# Test simulation function (simulates user selecting an option)
function Test-MenuSelection {
    param(
        [array]$MenuItems,
        [string]$Selection,
        [string]$Title = "Test Menu"
    )
    
    Write-Host "`n  Testing selection: '$Selection'" -ForegroundColor Yellow
    
    # Find the selected menu item
    $selectedItem = $MenuItems | Where-Object { 
        $_.ContainsKey('Type') -and $_.Type -eq 'option' -and $_.Key -eq $Selection 
    } | Select-Object -First 1
    
    if ($null -eq $selectedItem) {
        Write-Host "  ✗ Selection not found: '$Selection'" -ForegroundColor Red
        return $null
    }
    
    Write-Host "  ✓ Found menu item: $($selectedItem.Text)" -ForegroundColor Green
    
    # Execute the function
    $result = $null
    
    if ($selectedItem.ContainsKey('Function')) {
        Write-Host "  - Executing menu item function..." -ForegroundColor DarkGray
        $result = & $selectedItem.Function
        
        # Show what the function returned
        $resultType = if ($null -eq $result) { "NULL" } else { $result.GetType().Name }
        Write-Host "  - Function returned: [$resultType] $result" -ForegroundColor DarkGray
    } else {
        Write-Host "  ✗ Menu item has no function defined" -ForegroundColor Red
    }
    
    # Check if menu item should exit
    $shouldExit = $selectedItem.ContainsKey('IsExit') -and $selectedItem.IsExit -eq $true
    Write-Host "  - Item IsExit flag: $shouldExit" -ForegroundColor DarkGray
    
    # Simulate Show-DynamicMenu behavior
    $menuReturnValue = if ($shouldExit) { $result } else { $null }
    Write-Host "  - Menu would return: $menuReturnValue" -ForegroundColor DarkGray
    
    return $menuReturnValue
}

# Create test menu and test various selections
$testMenu = Create-TestMenu -Title "Test Menu" -ExitReturnValue $true

# Test each option
Test-MenuSelection -MenuItems $testMenu -Selection "1" -Title "Test Menu"
Test-MenuSelection -MenuItems $testMenu -Selection "2" -Title "Test Menu"
Test-MenuSelection -MenuItems $testMenu -Selection "3" -Title "Test Menu"
Test-MenuSelection -MenuItems $testMenu -Selection "4" -Title "Test Menu"
Test-MenuSelection -MenuItems $testMenu -Selection "0" -Title "Test Menu"

# 4. Test nested menu simulation
Write-Host "`nSTEP 4: Testing nested menu behavior..." -ForegroundColor Yellow

# Create a nested submenu
function Create-SubMenu {
    $menuItems = @()
    
    $menuItems += @{
        Type = "header"
        Text = "Submenu"
    }
    
    $menuItems += @{
        Type = "option"
        Key = "1"
        Text = "Submenu Option that returns string"
        Function = {
            Write-Host "  Selected Submenu Option 1 (returns string)" -ForegroundColor DarkGray
            return "SubMenuResult"
        }
    }
    
    $menuItems += @{
        Type = "option"
        Key = "0"
        Text = "Back"
        Function = {
            Write-Host "  Selected Back (returns null)" -ForegroundColor DarkGray
            return $null
        }
        IsExit = $true
    }
    
    return $menuItems
}

# Create a main menu that calls the submenu
function Create-MainWithSubMenu {
    $menuItems = @()
    
    $menuItems += @{
        Type = "header"
        Text = "Main Menu"
    }
    
    $menuItems += @{
        Type = "option"
        Key = "1"
        Text = "Go to Submenu"
        Function = {
            Write-Host "  Opening submenu..." -ForegroundColor DarkGray
            
            # Create submenu
            $subMenu = Create-SubMenu
            
            # Simulate user selecting option 1 in submenu
            Write-Host "  (Submenu Option 1 selected)" -ForegroundColor DarkGray
            $subResult = Test-MenuSelection -MenuItems $subMenu -Selection "1" -Title "Submenu"
            
            Write-Host "  Submenu returned: $subResult" -ForegroundColor DarkGray
            Write-Host "  Returning from submenu to main menu..." -ForegroundColor DarkGray
            
            # This is how the normal menu would work - we only return the submenu's result if we're exiting
            return $null
        }
    }
    
    $menuItems += @{
        Type = "option"
        Key = "0"
        Text = "Exit"
        Function = {
            Write-Host "  Selected Exit (returns TRUE)" -ForegroundColor DarkGray
            return $true
        }
        IsExit = $true
    }
    
    return $menuItems
}

# Test nested menu flow
$mainMenu = Create-MainWithSubMenu

# Test submenu flow
$result = Test-MenuSelection -MenuItems $mainMenu -Selection "1" -Title "Main Menu"
Write-Host "`n  Main Menu returned: $result" -ForegroundColor Green

# Test exit flow
$result = Test-MenuSelection -MenuItems $mainMenu -Selection "0" -Title "Main Menu"
Write-Host "`n  Main Menu exit returned: $result" -ForegroundColor Green

# 5. Simulate the actual main application loop
Write-Host "`nSTEP 5: Simulating main application loop..." -ForegroundColor Yellow

# Simulate the loop in tracker.ps1
function Simulate-MainLoop {
    $exitRequested = $false
    $loopCount = 0
    $maxLoops = 3
    
    while (-not $exitRequested -and $loopCount -lt $maxLoops) {
        $loopCount++
        Write-Host "  Loop iteration: $loopCount" -ForegroundColor DarkGray
        
        # Simulate menu selection
        if ($loopCount -eq 1) {
            # First iteration - select option 1 (go to submenu)
            Write-Host "  Selecting: Main Menu -> Go to Submenu" -ForegroundColor DarkGray
            $result = Test-MenuSelection -MenuItems $mainMenu -Selection "1" -Title "Main Menu"
        } else {
            # Second iteration - select exit
            Write-Host "  Selecting: Main Menu -> Exit" -ForegroundColor DarkGray
            $result = Test-MenuSelection -MenuItems $mainMenu -Selection "0" -Title "Main Menu"
        }
        
        Write-Host "  Menu returned: $result" -ForegroundColor DarkGray
        
        # Check if we should exit
        if ($result -eq $true) {
            $exitRequested = $true
            Write-Host "  Exit requested, breaking loop" -ForegroundColor Green
        }
    }
    
    Write-Host "  Main loop completed after $loopCount iterations" -ForegroundColor Green
    return $exitRequested
}

# Run the simulation
$simulationResult = Simulate-MainLoop
Write-Host "Main application loop simulation result: $simulationResult" -ForegroundColor Green

Write-Host "`n===== Menu Flow Diagnostic Complete =====" -ForegroundColor Cyan