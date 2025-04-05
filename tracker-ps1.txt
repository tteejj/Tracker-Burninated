# tracker.ps1
# Main entry point for Project Tracker

# Get the script directory
$scriptDir = if ($PSScriptRoot) { $PSScriptRoot } else { "." }

# Process command line arguments
$disableAnsi = $false
foreach ($arg in $args) {
    if ($arg -eq "-DisableAnsi") {
        $disableAnsi = $true
        Write-Host "ANSI colors disabled via command line." -ForegroundColor Yellow
    }
}

# Emergency ANSI override via environment variable
if ($env:PROJECTTRACKER_DISABLE_ANSI -eq "true") {
    $disableAnsi = $true
    Write-Host "ANSI colors disabled via environment variable." -ForegroundColor Yellow
}

# Load the main program
$mainProgram = Join-Path $scriptDir "main-program.ps1"

if (Test-Path $mainProgram) {
    try {
        # Pass variables to the main program
        $global:FORCE_DISABLE_ANSI = $disableAnsi
        
        # Execute the main program
        & $mainProgram
        
        # Return the exit code
        exit $LASTEXITCODE
    } catch {
        Write-Host "ERROR: Failed to execute main program: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host $_.ScriptStackTrace -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "ERROR: Main program not found: $mainProgram" -ForegroundColor Red
    exit 1
}
