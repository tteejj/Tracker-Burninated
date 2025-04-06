# test-time-tracking.ps1
# Simple script to test that the TimeTracking module loads correctly and functions are available

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
} catch {
    Write-Host "✗ Failed to import Core module: $_" -ForegroundColor Red
    exit 1
}

# Test Projects module
Write-BoldText "`nTesting ProjectTracker.Projects Module"
try {
    Import-Module -Name "$scriptDir\Modules\ProjectTracker.Projects\ProjectTracker.Projects.psd1" -Force -ErrorAction Stop
    Write-Host "✓ Projects module imported successfully" -ForegroundColor Green
} catch {
    Write-Host "✗ Failed to import Projects module: $_" -ForegroundColor Red
    exit 1
}

# Test Time Tracking module
Write-BoldText "`nTesting ProjectTracker.TimeTracking Module"
try {
    Import-Module -Name "$scriptDir\Modules\ProjectTracker.TimeTracking\ProjectTracker.TimeTracking.psd1" -Force -ErrorAction Stop
    Write-Host "✓ TimeTracking module imported successfully" -ForegroundColor Green
    
    # Test a few representative functions from the TimeTracking module
    $timeTrackingFunctionsToTest = @(
        'Show-TimeEntryList',
        'New-TimeEntry',
        'Update-TimeEntry',
        'Remove-TimeEntry',
        'Get-TimeEntry',
        'Show-TimeReport',
        'Show-TimeMenu'
    )
    
    $timeTrackingSuccess = $true
    foreach ($func in $timeTrackingFunctionsToTest) {
        $timeTrackingSuccess = $timeTrackingSuccess -and (Test-Command -CommandName $func -ModuleName "ProjectTracker.TimeTracking")
    }
    
    if ($timeTrackingSuccess) {
        Write-Host "✓ All tested TimeTracking functions are available" -ForegroundColor Green
    } else {
        Write-Host "✗ Some TimeTracking functions are missing" -ForegroundColor Red
    }
} catch {
    Write-Host "✗ Failed to import TimeTracking module: $_" -ForegroundColor Red
    exit 1
}

# Test Cross-Module Function Calls
Write-BoldText "`nTesting Cross-Module Function Calls"
try {
    # Test calling a Core function from TimeTracking context
    $script = {
        # Test calling Get-AppConfig (Core) from TimeTracking context
        $testConfig = Get-AppConfig
        
        # Check that TimeLogFullPath property exists
        if ($testConfig.TimeLogFullPath) {
            Write-Host "✓ Successfully accessed Core function from TimeTracking context" -ForegroundColor Green
        } else {
            Write-Host "✗ Core function accessible but returned unexpected data" -ForegroundColor Red
        }
        
        # Test calling a Projects function from TimeTracking context
        if (Get-Command 'Get-TrackerProject' -ErrorAction SilentlyContinue) {
            Write-Host "✓ Projects functions are accessible from TimeTracking context" -ForegroundColor Green
        } else {
            Write-Host "✗ Projects functions are not accessible from TimeTracking context" -ForegroundColor Red
        }
    }
    
    # Execute the script
    & $script
} catch {
    Write-Host "✗ Failed to test cross-module function calls: $_" -ForegroundColor Red
}

# Test Data File Structure
Write-BoldText "`nTesting Time Tracking Data File Structure"
try {
    # Initialize data environment to ensure files exist
    Initialize-DataEnvironment | Out-Null
    
    # Get config to find file paths
    $config = Get-AppConfig
    
    # Check for time log file
    if (Test-Path -Path $config.TimeLogFullPath) {
        Write-Host "✓ Time log file exists at: $($config.TimeLogFullPath)" -ForegroundColor Green
        
        # Check file structure
        $timeEntries = Get-EntityData -FilePath $config.TimeLogFullPath
        
        # Check if required headers exist
        $requiredHeaders = @("EntryID", "Date", "WeekStartDate", "Nickname", "TotalHours")
        $missingHeaders = @()
        
        if ($timeEntries.Count -gt 0) {
            $actualHeaders = $timeEntries[0].PSObject.Properties.Name
            
            foreach ($header in $requiredHeaders) {
                if ($actualHeaders -notcontains $header) {
                    $missingHeaders += $header
                }
            }
        } else {
            # Check first line of file for headers
            $firstLine = Get-Content -Path $config.TimeLogFullPath -TotalCount 1
            
            foreach ($header in $requiredHeaders) {
                if ($firstLine -notmatch $header) {
                    $missingHeaders += $header
                }
            }
        }
        
        if ($missingHeaders.Count -eq 0) {
            Write-Host "✓ Time log file has all required headers" -ForegroundColor Green
        } else {
            Write-Host "✗ Time log file is missing headers: $($missingHeaders -join ', ')" -ForegroundColor Red
        }
    } else {
        Write-Host "✗ Time log file does not exist at: $($config.TimeLogFullPath)" -ForegroundColor Red
    }
} catch {
    Write-Host "✗ Failed to test time tracking data file structure: $_" -ForegroundColor Red
}

Write-BoldText "`nTimeTracking module testing completed" -ForegroundColor Cyan