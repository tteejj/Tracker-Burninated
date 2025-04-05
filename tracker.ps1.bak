# tracker.ps1 - Main entry point for Project Tracker

# Get the script directory
$scriptDir = $PSScriptRoot # Use the directory where tracker.ps1 is located

# --- Module Import ---
# Use relative paths for development. Adjust if installing modules globally.
try {
    Import-Module -Name "$scriptDir\Modules\ProjectTracker.Core\ProjectTracker.Core.psd1" -ErrorAction Stop

    # Add other modules as they are created:
    # Import-Module -Name "$scriptDir\Modules\ProjectTracker.Projects\ProjectTracker.Projects.psd1" -ErrorAction Stop
    # Import-Module -Name "$scriptDir\Modules\ProjectTracker.Todos\ProjectTracker.Todos.psd1" -ErrorAction Stop

} catch {
    Write-Host "ERROR: Failed to import required Project Tracker modules." -ForegroundColor Red
    Write-Host "Details: $($_.Exception.Message)" -ForegroundColor Red
    Read-Host "Press Enter to exit"
    exit 1
}

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

# --- Application Initialization ---
function Initialize-Application {
    try {
        Write-AppLog "Initializing application..." -Level INFO

        # Initialize Core components (Data Env, Theme)
        Initialize-DataEnvironment # From Core Module
        Initialize-ThemeEngine     # From Core Module

        # Load config AFTER data env is initialized (in case config file needs creation)
        $config = Get-AppConfig    # From Core Module

        # Set theme based on config (Initialize-ThemeEngine might do this already, double-check its logic)
        Set-CurrentTheme -ThemeName $config.DefaultTheme # From Core Module

        # Handle ANSI override if specified via command line or environment
        if ($global:FORCE_DISABLE_ANSI) {
            # Since we can't directly modify $script:useAnsiColors in the module,
            # we need to update the theme to one that has UseAnsiColors = $false
            $theme = Get-CurrentTheme
            $theme.UseAnsiColors = $false
            Set-CurrentTheme -ThemeObject $theme
        }

        Write-AppLog "Initialization complete. Using Theme: $($config.DefaultTheme)" -Level INFO
        return $true
    } catch {
        Handle-Error -ErrorRecord $_ -Context "Application Initialization"
        return $false
    }
}

# --- Main Menu Definition ---
function Show-MainMenu {
    # Define menu items using the new function call pattern
    $menuItems = @()

    $menuItems += @{ Type = "header"; Text = "Project Tracker" }

    # Project Options
    $menuItems += @{ Type = "option"; Key = "1"; Text = "Project Management"; Function = { Show-ProjectMenu } }

    # Todo Options
    $menuItems += @{ Type = "option"; Key = "2"; Text = "Todo Management"; Function = { Show-TodoMenu } }

    # Time Tracking Options
    $menuItems += @{ Type = "option"; Key = "3"; Text = "Time Tracking"; Function = { Show-TimeTrackingMenu } }

    # Theme Options
    $menuItems += @{ Type = "option"; Key = "8"; Text = "List Available Themes"; Function = { Show-ThemeList } }
    $menuItems += @{ Type = "option"; Key = "9"; Text = "Change Theme"; Function = { Change-Theme } }

    $menuItems += @{ Type = "separator" }
    $menuItems += @{ Type = "option"; Key = "0"; Text = "Exit"; Function = { return $true }; IsExit = $true }

    # Show menu using the Core module function
    return Show-DynamicMenu -Title "Main Menu" -MenuItems $menuItems -Prompt "Select option:"
}

# --- UI Helper Functions ---
function Show-ProjectMenu {
    # This will be implemented when the Projects module is available
    Show-InfoBox -Title "Project Management" -Message "Project management functionality will be available when the Projects module is implemented." -Type Info
    Read-Host "Press Enter to continue..."
    return $false
}

function Show-TodoMenu {
    # This will be implemented when the Todos module is available
    Show-InfoBox -Title "Todo Management" -Message "Todo management functionality will be available when the Todos module is implemented." -Type Info
    Read-Host "Press Enter to continue..."
    return $false
}

function Show-TimeTrackingMenu {
    # This will be implemented when the TimeTracking module is available
    Show-InfoBox -Title "Time Tracking" -Message "Time tracking functionality will be available when the TimeTracking module is implemented." -Type Info
    Read-Host "Press Enter to continue..."
    return $false
}

function Show-ThemeList {
    Render-Header -Title "Available Themes"

    $themes = Get-AvailableThemes

    if ($themes.Count -eq 0) {
        Write-ColorText "No themes available." -ForegroundColor $script:colors.Warning
        Read-Host "Press Enter to continue..."
        return
    }

    $themeTable = @()
    foreach ($theme in $themes) {
        $themeTable += [PSCustomObject]@{
            Name = $theme.Name
            Type = $theme.Type
            Source = $theme.Source
            Current = if ($theme.Name -eq (Get-CurrentTheme).Name) { "*" } else { "" }
        }
    }

    Show-Table -Data $themeTable -Columns @("Name", "Type", "Source", "Current")

    # Log the action
    Write-AppLog "Listed available themes" -Level INFO

    Read-Host "Press Enter to continue..."
}

function Change-Theme {
    Render-Header -Title "Change Theme"

    $themes = Get-AvailableThemes

    if ($themes.Count -eq 0) {
        Write-ColorText "No themes available." -ForegroundColor $script:colors.Warning
        Read-Host "Press Enter to continue..."
        return
    }

    $menuItems = @()

    $menuItems += @{
        Type = "header"
        Text = "Select Theme"
    }

    $currentTheme = (Get-CurrentTheme).Name

    foreach ($theme in $themes) {
        $isHighlighted = $theme.Name -eq $currentTheme

        $menuItems += @{
            Type = "option"
            Key = $theme.Name
            Text = "$($theme.Name) ($(if ($isHighlighted) { 'Current' } else { $theme.Type }))"
            IsHighlighted = $isHighlighted
            Function = {
                param([string]$ThemeName)

                if (Set-CurrentTheme -ThemeName $ThemeName) {
                    $colors = (Get-CurrentTheme).Colors
                    Write-ColorText "Theme changed to $ThemeName" -ForegroundColor $colors.Success
                    Write-AppLog "Changed theme to $ThemeName" -Level INFO
                } else {
                    $colors = (Get-CurrentTheme).Colors
                    Write-ColorText "Failed to change theme to $ThemeName" -ForegroundColor $colors.Error
                    Write-AppLog "Failed to change theme to $ThemeName" -Level ERROR
                }

                Read-Host "Press Enter to continue..."
            }.GetNewClosure()
        }
    }

    $menuItems += @{
        Type = "separator"
    }

    $menuItems += @{
        Type = "option"
        Key = "0"
        Text = "Back"
        Function = { return $null }
        IsExit = $true
    }

    return Show-DynamicMenu -Title "Select Theme" -MenuItems $menuItems
}

# --- Main Execution ---

# Initialize the application
if (-not (Initialize-Application)) {
    Write-Host "Failed to initialize application. Exiting..." -ForegroundColor Red
    exit 1
}

# Set global ANSI override if specified
if ($disableAnsi) {
    $global:FORCE_DISABLE_ANSI = $true
}

# Main application loop
$exitRequested = $false
while (-not $exitRequested) {
    $exitRequested = Show-MainMenu
}

Write-Host "Thank you for using Project Tracker!" -ForegroundColor Cyan