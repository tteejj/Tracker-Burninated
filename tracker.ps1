# tracker.ps1 - Main entry point for Project Tracker

# Get the script directory
$scriptDir = $PSScriptRoot # Use the directory where tracker.ps1 is located

# --- Module Import ---
# Use relative paths for development. Adjust if installing modules globally.
try {
    Import-Module -Name "$scriptDir\Modules\ProjectTracker.Core\ProjectTracker.Core.psd1" -ErrorAction Stop -Force
    Import-Module -Name "$scriptDir\Modules\ProjectTracker.Projects\ProjectTracker.Projects.psd1" -ErrorAction Stop -Force
    Import-Module -Name "$scriptDir\Modules\ProjectTracker.Todos\ProjectTracker.Todos.psd1" -ErrorAction Stop -Force
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

        # Set theme based on config
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

# --- Theme UI Functions ---

function Show-ThemeList {
    Render-Header -Title "Available Themes"

    $themes = Get-AvailableThemes

    if ($themes.Count -eq 0) {
        Write-ColorText "No themes available." -ForegroundColor (Get-CurrentTheme).Colors.Warning
        Read-Host "Press Enter to continue..."
        return
    }

    # Prepare a numbered list of themes
    $themeTable = @()
    for ($i = 0; $i -lt $themes.Count; $i++) {
        $themeNum = $i + 1
        $theme = $themes[$i]
        $themeTable += [PSCustomObject]@{
            Num = $themeNum
            Name = $theme.Name
            Type = $theme.Type
            Source = $theme.Source
            Current = if ($theme.Name -eq (Get-CurrentTheme).Name) { "*" } else { "" }
        }
    }

    Show-Table -Data $themeTable -Columns @("Num", "Name", "Type", "Source", "Current")

    # Log the action
    Write-AppLog "Listed available themes" -Level INFO

    Read-Host "Press Enter to continue..."
}

function Change-Theme {
    Render-Header -Title "Change Theme"

    $themes = Get-AvailableThemes

    if ($themes.Count -eq 0) {
        Write-ColorText "No themes available." -ForegroundColor (Get-CurrentTheme).Colors.Warning
        Read-Host "Press Enter to continue..."
        return
    }

    # Display themes with numeric indices
    Write-Host "Select theme by number (0 to cancel):" -ForegroundColor (Get-CurrentTheme).Colors.Accent2
    
    $currentTheme = (Get-CurrentTheme).Name
    
    for ($i = 0; $i -lt $themes.Count; $i++) {
        $themeNum = $i + 1
        $theme = $themes[$i]
        $isCurrentTheme = $theme.Name -eq $currentTheme
        
        if ($isCurrentTheme) {
            Write-Host "[$themeNum] $($theme.Name) (Current)" -ForegroundColor (Get-CurrentTheme).Colors.Accent2
        } else {
            Write-Host "[$themeNum] $($theme.Name)" -ForegroundColor (Get-CurrentTheme).Colors.Normal
        }
    }
    
    $selection = Read-UserInput -Prompt "Enter theme number" -NumericOnly
    
    if ($selection -eq "CANCEL" -or $selection -eq "0") {
        Write-ColorText "Theme change cancelled." -ForegroundColor (Get-CurrentTheme).Colors.Warning
        Read-Host "Press Enter to continue..."
        return
    }
    
    # Convert selection to int and check range
    try {
        $index = [int]$selection - 1
        if ($index -lt 0 -or $index -ge $themes.Count) {
            Write-ColorText "Invalid selection." -ForegroundColor (Get-CurrentTheme).Colors.Error
            Read-Host "Press Enter to continue..."
            return
        }
        
        $themeName = $themes[$index].Name
        
        if (Set-CurrentTheme -ThemeName $themeName) {
            $colors = (Get-CurrentTheme).Colors
            Write-ColorText "Theme changed to $themeName" -ForegroundColor $colors.Success
            Write-AppLog "Changed theme to $themeName" -Level INFO
        } else {
            $colors = (Get-CurrentTheme).Colors
            Write-ColorText "Failed to change theme to $themeName" -ForegroundColor $colors.Error
            Write-AppLog "Failed to change theme to $themeName" -Level ERROR
        }
        
        Read-Host "Press Enter to continue..."
    } catch {
        Write-ColorText "Invalid selection." -ForegroundColor (Get-CurrentTheme).Colors.Error
        Read-Host "Press Enter to continue..."
    }
}

# --- Main Menu Definition ---
function Show-MainMenu {
    # Define menu items using numeric keys only
    $menuItems = @()

    $menuItems += @{ Type = "header"; Text = "Project Tracker" }

    # Project Options
    $menuItems += @{ Type = "option"; Key = "1"; Text = "Project Management"; Function = { Show-ProjectMenu } }

    # Todo Options
    $menuItems += @{ Type = "option"; Key = "2"; Text = "Todo Management"; Function = { Show-TodoMenu } }

    # Time Tracking Options (placeholder)
    $menuItems += @{ Type = "option"; Key = "3"; Text = "Time Tracking"; Function = { Show-InfoBox -Title "Time Tracking" -Message "Time tracking functionality will be available in a future update." -Type Info; Read-Host "Press Enter to continue..."; return $null } }

    # Theme Options
    $menuItems += @{ Type = "option"; Key = "8"; Text = "List Available Themes"; Function = { Show-ThemeList } }
    $menuItems += @{ Type = "option"; Key = "9"; Text = "Change Theme"; Function = { Change-Theme } }

    $menuItems += @{ Type = "separator" }
    $menuItems += @{ Type = "option"; Key = "0"; Text = "Exit"; Function = { 
        # Get confirmation with numeric input
        $confirm = Confirm-Action -ActionDescription "Are you sure you want to exit?"
        if ($confirm) {
            return $true
        } else {
            return $null
        }
    }; IsExit = $true }

    # Show menu using the Core module function - ensure only explicit values are returned
    $result = Show-DynamicMenu -Title "Main Menu" -MenuItems $menuItems -Prompt "Enter option number:"
    
    # Only return true if explicitly set to true
    if ($result -eq $true) {
        return $true
    } else {
        return $null
    }
}

# --- Main Execution ---

# Set global ANSI override if specified
if ($disableAnsi) {
    $global:FORCE_DISABLE_ANSI = $true
}

# Initialize the application
if (-not (Initialize-Application)) {
    Write-Host "Failed to initialize application. Exiting..." -ForegroundColor Red
    exit 1
}

# Main application loop
$exitRequested = $false
while (-not $exitRequested) {
    $result = Show-MainMenu
    
    # Only exit when the result is explicitly $true, not just truthy
    if ($result -eq $true) {
        $exitRequested = $true
    }
}

Write-Host "Thank you for using Project Tracker!" -ForegroundColor Cyan