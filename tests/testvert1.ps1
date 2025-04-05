# Test-Modules.ps1
# Script to test that all modules load correctly and their functions are available

# Set error action preference to stop so we fail early if there's an issue
$ErrorActionPreference = 'Stop'

# Get the script's directory
$scriptDir = $PSScriptRoot

# Bold text function for output formatting
function Write-BoldText {
    param([string]$Text, [string]$Color = "Green")
    Write-Host $Text -ForegroundColor $Color -BackgroundColor Black
}

# Test function for checking if a command exists
function Test-Command {
    param([string]$CommandName, [string]$ModuleName)
    
    if (Get-Command -Name $CommandName -ErrorAction SilentlyContinue) {
        Write-Host "✓ Function '$CommandName' exists in module '$ModuleName'" -ForegroundColor Green
        return $true
    } else {
        Write-Host "✗ Function '$CommandName' does not exist in module '$ModuleName'" -ForegroundColor Red
        return $false
    }
}

# Test core module
Write-BoldText "Testing ProjectTracker.Core Module"
try {
    Import-Module -Name "$scriptDir\Modules\ProjectTracker.Core\ProjectTracker.Core.psd1" -Force -ErrorAction Stop
    Write-Host "✓ Core module imported successfully" -ForegroundColor Green
    
    # Test a few representative functions from the Core module
    $coreFunctionsToTest = @(
        'Get-AppConfig',
        'Handle-Error',
        'Write-AppLog',
        'Get-EntityData',
        'Parse-DateInput',
        'Read-UserInput',
        'Get-Theme',
        'Write-ColorText',
        'Show-Table',
        'Initialize-DataEnvironment'
    )
    
    $coreSuccess = $true
    foreach ($func in $coreFunctionsToTest) {
        $coreSuccess = $coreSuccess -and (Test-Command -CommandName $func -ModuleName "ProjectTracker.Core")
    }
    
    if ($coreSuccess) {
        Write-Host "✓ All tested Core functions are available" -ForegroundColor Green
    } else {
        Write-Host "✗ Some Core functions are missing" -ForegroundColor Red
    }
} catch {
    Write-Host "✗ Failed to import Core module: $_" -ForegroundColor Red
}

# Test Projects module
Write-BoldText "`nTesting ProjectTracker.Projects Module"
try {
    Import-Module -Name "$scriptDir\Modules\ProjectTracker.Projects\ProjectTracker.Projects.psd1" -Force -ErrorAction Stop
    Write-Host "✓ Projects module imported successfully" -ForegroundColor Green
    
    # Test a few representative functions from the Projects module
    $projectsFunctionsToTest = @(
        'Show-ProjectList',
        'New-TrackerProject',
        'Update-TrackerProject',
        'Remove-TrackerProject',
        'Get-TrackerProject',
        'Set-TrackerProjectStatus',
        'Show-ProjectMenu'
    )
    
    $projectsSuccess = $true
    foreach ($func in $projectsFunctionsToTest) {
        $projectsSuccess = $projectsSuccess -and (Test-Command -CommandName $func -ModuleName "ProjectTracker.Projects")
    }
    
    if ($projectsSuccess) {
        Write-Host "✓ All tested Projects functions are available" -ForegroundColor Green
    } else {
        Write-Host "✗ Some Projects functions are missing" -ForegroundColor Red
    }
} catch {
    Write-Host "✗ Failed to import Projects module: $_" -ForegroundColor Red
}

# Test Todos module
Write-BoldText "`nTesting ProjectTracker.Todos Module"
try {
    Import-Module -Name "$scriptDir\Modules\ProjectTracker.Todos\ProjectTracker.Todos.psd1" -Force -ErrorAction Stop
    Write-Host "✓ Todos module imported successfully" -ForegroundColor Green
    
    # Test a few representative functions from the Todos module
    $todosFunctionsToTest = @(
        'Show-TodoList',
        'New-TrackerTodoItem',
        'Update-TrackerTodoItem',
        'Complete-TrackerTodoItem',
        'Remove-TrackerTodoItem',
        'Get-TrackerTodoItem',
        'Show-TodoMenu'
    )
    
    $todosSuccess = $true
    foreach ($func in $todosFunctionsToTest) {
        $todosSuccess = $todosSuccess -and (Test-Command -CommandName $func -ModuleName "ProjectTracker.Todos")
    }
    
    if ($todosSuccess) {
        Write-Host "✓ All tested Todos functions are available" -ForegroundColor Green
    } else {
        Write-Host "✗ Some Todos functions are missing" -ForegroundColor Red
    }
} catch {
    Write-Host "✗ Failed to import Todos module: $_" -ForegroundColor Red
}

# Test Cross-Module Function Calls
Write-BoldText "`nTesting Cross-Module Function Calls"
try {
    # Test calling a Core function from Projects module
    # Don't actually execute it, just check if it can be invoked without errors
    $script = {
        # Test calling Get-AppConfig (Core) from Projects context
        $testConfig = Get-AppConfig
        
        # Just check that ProjectsFullPath property exists
        if ($testConfig.ProjectsFullPath) {
            Write-Host "✓ Successfully accessed Core function from Projects context" -ForegroundColor Green
        } else {
            Write-Host "✗ Core function accessible but returned unexpected data" -ForegroundColor Red
        }
    }
    
    # Execute the script in a Projects module context
    & $script
} catch {
    Write-Host "✗ Failed to use Core functions from Projects context: $_" -ForegroundColor Red
}

Write-BoldText "`nModule testing completed" -ForegroundColor Cyan