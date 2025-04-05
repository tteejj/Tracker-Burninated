# main-program.ps1
# Main entry point for Project Tracker
# Simple implementation to test core libraries

# Load core libraries
$scriptRoot = if ($PSScriptRoot) { $PSScriptRoot } else { "." }
$libPath = Join-Path $scriptRoot "lib"

# Core libraries to load
$coreLibraries = @(
    "config.ps1",
    "error-handling.ps1",
    "logging.ps1",
    "theme-engine.ps1",
    "date-functions.ps1",
    "helper-functions.ps1"
)

# Load each library
foreach ($lib in $coreLibraries) {
    $libFile = Join-Path $libPath $lib
    if (Test-Path $libFile) {
        try {
            . $libFile
        } catch {
            Write-Host "ERROR: Failed to load library $lib - $($_.Exception.Message)" -ForegroundColor Red
            exit 1
        }
    } else {
        Write-Host "ERROR: Library file not found: $libFile" -ForegroundColor Red
        exit 1
    }
}

# Initialize theme engine
if (Get-Command "Initialize-ThemeEngine" -ErrorAction SilentlyContinue) {
    Initialize-ThemeEngine | Out-Null
}

# Initialize application
function Initialize-Application {
    $config = Get-AppConfig
    
    # Create data directory if it doesn't exist
    if (-not (Test-Path $config.BaseDataDir -PathType Container)) {
        try {
            New-Item -Path $config.BaseDataDir -ItemType Directory -Force | Out-Null
            Write-AppLog "Created data directory: $($config.BaseDataDir)" -Level INFO
        } catch {
            Handle-Error -ErrorRecord $_ -Context "Creating data directory"
            return $false
        }
    }
    
    # Set current theme
    if (Get-Command "Set-CurrentTheme" -ErrorAction SilentlyContinue) {
        Set-CurrentTheme -ThemeName $config.DefaultTheme | Out-Null
    }
    
    return $true
}

# Show main menu
function Show-MainMenu {
    $menuItems = @()
    
    $menuItems += @{
        Type = "header"
        Text = "Project Tracker (Core Test)"
    }
    
    $menuItems += @{
        Type = "option"
        Key = "1"
        Text = "List Available Themes"
        Function = { Show-ThemeList }
    }
    
    $menuItems += @{
        Type = "option"
        Key = "2"
        Text = "Change Theme"
        Function = { Change-Theme }
    }
    
    $menuItems += @{
        Type = "option"
        Key = "3"
        Text = "Show Date Functions"
        Function = { Show-DateFunctions }
    }
    
    $menuItems += @{
        Type = "option"
        Key = "4"
        Text = "Show Table Example"
        Function = { Show-TableExample }
    }
    
    $menuItems += @{
        Type = "separator"
    }
    
    $menuItems += @{
        Type = "option"
        Key = "0"
        Text = "Exit"
        Function = { return $true }
        IsExit = $true
    }
    
    # Show menu and get result
    return Show-DynamicMenu -Title "Project Tracker" -Subtitle "Core Libraries Test" -MenuItems $menuItems
}

# Show available themes
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
            Current = if ($theme.Name -eq (Get-CurrentTheme).Name) { "✓" } else { "" }
        }
    }
    
    Show-Table -Data $themeTable -Columns @("Name", "Type", "Source", "Current")
    
    # Log the action
    Write-AppLog "Listed available themes" -Level INFO
    
    Read-Host "Press Enter to continue..."
}

# Change the current theme
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
                    Write-ColorText "Theme changed to $ThemeName" -ForegroundColor $script:colors.Success
                    Write-AppLog "Changed theme to $ThemeName" -Level INFO
                } else {
                    Write-ColorText "Failed to change theme to $ThemeName" -ForegroundColor $script:colors.Error
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

# Show date functions
function Show-DateFunctions {
    Render-Header -Title "Date Functions Demo"
    
    # Get today's date in various formats
    $today = Get-Date
    $internalFormat = $today.ToString("yyyyMMdd")
    
    Write-ColorText "Today's date:" -ForegroundColor $script:colors.Accent1
    Write-ColorText "  Internal format: $internalFormat" -ForegroundColor $script:colors.Normal
    Write-ColorText "  Display format: $(Convert-InternalDateToDisplay -InternalDate $internalFormat)" -ForegroundColor $script:colors.Normal
    
    # Date parsing examples
    Write-ColorText "`nDate parsing examples:" -ForegroundColor $script:colors.Accent1
    
    $testDates = @(
        "4/15/2023",
        "04/15/2023",
        "2023-04-15",
        "15/04/2023",
        "20230415"
    )
    
    foreach ($date in $testDates) {
        $parsed = Parse-DateInput -InputDate $date
        $result = if ($parsed) { "Success: $parsed" } else { "Failed" }
        Write-ColorText "  Parse '$date': $result" -ForegroundColor $script:colors.Normal
    }
    
    # Relative date examples
    Write-ColorText "`nRelative date examples:" -ForegroundColor $script:colors.Accent1
    
    $dateOffsets = @(-7, -2, -1, 0, 1, 2, 7, 30)
    
    foreach ($offset in $dateOffsets) {
        $date = $today.AddDays($offset)
        $description = Get-RelativeDateDescription -Date $date
        Write-ColorText "  $($date.ToString('yyyy-MM-dd')): $description" -ForegroundColor $script:colors.Normal
    }
    
    # Date input function
    Write-ColorText "`nInteractive date input (Ctrl+C to cancel):" -ForegroundColor $script:colors.Accent1
    
    try {
        $inputDate = Get-DateInput -PromptText "Enter a date" -AllowEmptyForToday -AllowCancel
        
        if ($inputDate) {
            Write-ColorText "You entered: $inputDate ($(Convert-InternalDateToDisplay -InternalDate $inputDate))" -ForegroundColor $script:colors.Success
        } else {
            Write-ColorText "Date input cancelled." -ForegroundColor $script:colors.Warning
        }
    } catch {
        Write-ColorText "Date input cancelled." -ForegroundColor $script:colors.Warning
    }
    
    # Log the action
    Write-AppLog "Viewed date functions demo" -Level INFO
    
    Read-Host "`nPress Enter to continue..."
}

# Show table example
function Show-TableExample {
    Render-Header -Title "Table Display Example"
    
    # Create sample data
    $projects = @(
        [PSCustomObject]@{
            ID = 1
            Nickname = "WEBSITE"
            FullProjectName = "Company Website Redesign"
            Status = "Active"
            DateAssigned = "20230301"
            DueDate = "20230430"
            Importance = "High"
            CumulativeHrs = 24.5
        },
        [PSCustomObject]@{
            ID = 2
            Nickname = "MOBILE"
            FullProjectName = "Mobile App Development"
            Status = "On Hold"
            DateAssigned = "20230201"
            DueDate = "20230630"
            Importance = "Normal"
            CumulativeHrs = 45.0
        },
        [PSCustomObject]@{
            ID = 3
            Nickname = "TRAINING"
            FullProjectName = "Staff Training Program"
            Status = "Completed"
            DateAssigned = "20230115"
            DueDate = "20230331"
            Importance = "Low"
            CumulativeHrs = 18.75
        },
        [PSCustomObject]@{
            ID = 4
            Nickname = "MARKETING"
            FullProjectName = "Q2 Marketing Campaign"
            Status = "Active"
            DateAssigned = "20230315"
            DueDate = "20230515"
            Importance = "High"
            CumulativeHrs = 10.25
        }
    )
    
    # Column headers and formatters
    $headers = @{
        FullProjectName = "Project Name"
        DateAssigned = "Assigned"
        DueDate = "Due Date"
        CumulativeHrs = "Hours"
    }
    
    $formatters = @{
        DateAssigned = { param($val) Convert-InternalDateToDisplay -InternalDate $val }
        DueDate = { param($val) Convert-InternalDateToDisplay -InternalDate $val }
        CumulativeHrs = { param($val) [double]::Parse($val).ToString("F1") }
    }
    
    $rowColorizer = {
        param($item, $rowIndex)
        
        switch ($item.Status) {
            "Active" {
                # Check if project is due soon (within 7 days)
                $dueDate = [datetime]::ParseExact($item.DueDate, "yyyyMMdd", $null)
                $today = (Get-Date).Date
                $daysUntilDue = ($dueDate - $today).Days
                
                if ($daysUntilDue -lt 0) {
                    return $script:colors.Overdue
                } elseif ($daysUntilDue -le 7) {
                    return $script:colors.DueSoon
                } else {
                    return $script:colors.Normal
                }
            }
            "On Hold" { return $script:colors.Warning }
            "Completed" { return $script:colors.Completed }
            default { return $script:colors.Normal }
        }
    }
    
    # Show the table
    Write-ColorText "Projects:" -ForegroundColor $script:colors.Accent1
    Show-Table -Data $projects -Columns @("ID", "Nickname", "FullProjectName", "Status", "DateAssigned", "DueDate", "CumulativeHrs") -Headers $headers -Formatters $formatters -RowColorizer $rowColorizer
    
    # Create sample tasks
    $tasks = @(
        [PSCustomObject]@{
            ID = 1
            Nickname = "WEBSITE"
            TaskDescription = "Design homepage mockup"
            Status = "Completed"
            DueDate = "20230320"
            Importance = "High"
        },
        [PSCustomObject]@{
            ID = 2
            Nickname = "WEBSITE"
            TaskDescription = "Implement responsive design"
            Status = "In Progress"
            DueDate = "20230410"
            Importance = "High"
        },
        [PSCustomObject]@{
            ID = 3
            Nickname = "MOBILE"
            TaskDescription = "Create wireframes"
            Status = "On Hold"
            DueDate = "20230315"
            Importance = "Normal"
        },
        [PSCustomObject]@{
            ID = 4
            Nickname = "MARKETING"
            TaskDescription = "Draft email campaign"
            Status = "Not Started"
            DueDate = "20230430"
            Importance = "Normal"
        },
        [PSCustomObject]@{
            ID = 5
            Nickname = "MARKETING"
            TaskDescription = "Social media schedule"
            Status = "Not Started"
            DueDate = "20230508"
            Importance = "Low"
        }
    )
    
    # Task formatters
    $taskFormatters = @{
        DueDate = { param($val) Convert-InternalDateToDisplay -InternalDate $val }
        Importance = { param($val) 
            switch ($val) {
                "High" { return Write-ColorText $val -ForegroundColor "Red" -NoNewline; $val }
                "Normal" { return Write-ColorText $val -ForegroundColor "Yellow" -NoNewline; $val }
                "Low" { return Write-ColorText $val -ForegroundColor "Gray" -NoNewline; $val }
                default { return $val }
            }
        }
    }
    
    # Task color rules
    $taskColorizer = {
        param($item, $rowIndex)
        
        switch ($item.Status) {
            "Completed" { return $script:colors.Completed }
            "On Hold" { return $script:colors.Warning }
            default {
                # Check due date
                $dueDate = [datetime]::ParseExact($item.DueDate, "yyyyMMdd", $null)
                $today = (Get-Date).Date
                $daysUntilDue = ($dueDate - $today).Days
                
                if ($daysUntilDue -lt 0) {
                    return $script:colors.Overdue
                } elseif ($daysUntilDue -le 7) {
                    return $script:colors.DueSoon
                } else {
                    return $script:colors.Normal
                }
            }
        }
    }
    
    # Show tasks table
    Write-ColorText "`nTasks:" -ForegroundColor $script:colors.Accent1
    Show-Table -Data $tasks -Columns @("ID", "Nickname", "TaskDescription", "Status", "DueDate", "Importance") -Formatters $taskFormatters -RowColorizer $taskColorizer
    
    # Log the action
    Write-AppLog "Viewed table examples" -Level INFO
    
    Read-Host "`nPress Enter to continue..."
}

# Main execution logic
function Start-Application {
    # Initialize
    if (-not (Initialize-Application)) {
        Write-Host "Initialization failed. Exiting." -ForegroundColor Red
        exit 1
    }
    
    # Log startup
    Write-AppLog "Application started" -Level INFO
    
    # Main menu loop
    while ($true) {
        $exitRequested = Show-MainMenu
        
        if ($exitRequested -eq $true) {
            break
        }
    }
    
    # Log shutdown
    Write-AppLog "Application shutting down" -Level INFO
}

# Start the application
Start-Application
