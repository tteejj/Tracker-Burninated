# ProjectTracker.TimeTracking.psm1
# Time Tracking Module for Project Tracker
# Handles creating, updating, listing, and managing time entries

# Constants and configuration
$TIME_HEADERS = @(
    "EntryID", "Date", "WeekStartDate", "Nickname", "ID1", "ID2",
    "Description", "MonHours", "TueHours", "WedHours", "ThuHours",
    "FriHours", "SatHours", "SunHours", "TotalHours"
)

$WEEKDAYS = @("MonHours", "TueHours", "WedHours", "ThuHours", "FriHours", "SatHours", "SunHours")

<#
.SYNOPSIS
    Lists time entries for a specified date range or project.
.DESCRIPTION
    Retrieves and displays a list of time entries, filtered by date range and/or project.
.PARAMETER StartDate
    The start date for filtering entries (YYYYMMDD format).
.PARAMETER EndDate
    The end date for filtering entries (YYYYMMDD format).
.PARAMETER Nickname
    The project nickname to filter by.
.PARAMETER IncludeEmpty
    If specified, includes entries with zero hours.
.EXAMPLE
    Show-TimeEntryList -StartDate "20240401" -EndDate "20240430"
.EXAMPLE
    Show-TimeEntryList -Nickname "WEBSITE"
.OUTPUTS
    Array of time entry objects
#>
function Show-TimeEntryList {
    [CmdletBinding(DefaultParameterSetName="DateRange")]
    param(
        [Parameter(Mandatory=$false, ParameterSetName="DateRange")]
        [string]$StartDate = "",
        
        [Parameter(Mandatory=$false, ParameterSetName="DateRange")]
        [string]$EndDate = "",
        
        [Parameter(Mandatory=$false, ParameterSetName="Project")]
        [string]$Nickname = "",
        
        [Parameter(Mandatory=$false)]
        [switch]$IncludeEmpty
    )
    
    Write-AppLog "Listing time entries" -Level INFO
    
    try {
        $config = Get-AppConfig
        $timeEntriesPath = $config.TimeLogFullPath
        
        # Get time entries
        $entries = @(Get-EntityData -FilePath $timeEntriesPath -RequiredHeaders $TIME_HEADERS)
        
        # Apply filters
        if (-not [string]::IsNullOrWhiteSpace($StartDate)) {
            $entries = $entries | Where-Object { 
                [string]::IsNullOrWhiteSpace($_.Date) -or 
                $_.Date -ge $StartDate 
            }
        }
        
        if (-not [string]::IsNullOrWhiteSpace($EndDate)) {
            $entries = $entries | Where-Object { 
                [string]::IsNullOrWhiteSpace($_.Date) -or 
                $_.Date -le $EndDate 
            }
        }
        
        if (-not [string]::IsNullOrWhiteSpace($Nickname)) {
            $entries = $entries | Where-Object { $_.Nickname -eq $Nickname }
        }
        
        # Filter out entries with zero hours unless IncludeEmpty is specified
        if (-not $IncludeEmpty) {
            $entries = $entries | Where-Object {
                $hasHours = $false
                foreach ($day in $WEEKDAYS) {
                    if (-not [string]::IsNullOrWhiteSpace($_.$day) -and [double]::TryParse($_.$day, [ref]$null)) {
                        if ([double]::Parse($_.$day) -gt 0) {
                            $hasHours = $true
                            break
                        }
                    }
                }
                $hasHours
            }
        }
        
        # Display time entries
        $title = "Time Entries"
        if (-not [string]::IsNullOrWhiteSpace($Nickname)) {
            $title += " for $Nickname"
        } 
        
        if (-not [string]::IsNullOrWhiteSpace($StartDate) -and -not [string]::IsNullOrWhiteSpace($EndDate)) {
            $startDisplay = Convert-InternalDateToDisplay -InternalDate $StartDate
            $endDisplay = Convert-InternalDateToDisplay -InternalDate $EndDate
            $title += " ($startDisplay to $endDisplay)"
        }
        
        Render-Header -Title $title
        
        if ($entries.Count -eq 0) {
            Write-ColorText "No time entries found." -ForegroundColor (Get-CurrentTheme).Colors.Warning
            Read-Host "Press Enter to continue..."
            return @()
        }
        
        # Define display columns
        $columnsToShow = @("WeekStartDate", "Nickname", "MonHours", "TueHours", "WedHours", "ThuHours", "FriHours", "SatHours", "SunHours", "TotalHours", "Description")
        
        # Define column headers
        $tableHeaders = @{
            WeekStartDate = "Week Start"
            MonHours = "Mon"
            TueHours = "Tue"
            WedHours = "Wed"
            ThuHours = "Thu"
            FriHours = "Fri"
            SatHours = "Sat"
            SunHours = "Sun"
            TotalHours = "Total"
        }
        
        # Define column formatters
        $tableFormatters = @{
            WeekStartDate = { param($val) Convert-InternalDateToDisplay $val }
            MonHours = { param($val) Format-HoursValue $val }
            TueHours = { param($val) Format-HoursValue $val }
            WedHours = { param($val) Format-HoursValue $val }
            ThuHours = { param($val) Format-HoursValue $val }
            FriHours = { param($val) Format-HoursValue $val }
            SatHours = { param($val) Format-HoursValue $val }
            SunHours = { param($val) Format-HoursValue $val }
            TotalHours = { param($val) Format-HoursValue $val }
        }
        
        # Sort by date and nickname
        $sortedEntries = $entries | Sort-Object -Property @{Expression = "WeekStartDate"; Descending = $true}, "Nickname"
        
        # Display the table
        Show-Table -Data $sortedEntries -Columns $columnsToShow -Headers $tableHeaders -Formatters $tableFormatters
        
        # Calculate and display total
        $total = 0.0
        foreach ($entry in $entries) {
            if (-not [string]::IsNullOrWhiteSpace($entry.TotalHours)) {
                $hours = 0.0
                if ([double]::TryParse($entry.TotalHours, [ref]$hours)) {
                    $total += $hours
                }
            }
        }
        
        Write-ColorText "`nTotal Hours: $($total.ToString("F1"))" -ForegroundColor (Get-CurrentTheme).Colors.Accent2
        
        # Log success
        Write-AppLog "Successfully listed $($entries.Count) time entries" -Level INFO
        
        # Wait for user input
        Read-Host "Press Enter to continue..."
        
        # Return entries array for potential use by other functions
        return $entries
    } catch {
        Handle-Error -ErrorRecord $_ -Context "Listing time entries" -Continue
        return @()
    }
}

<#
.SYNOPSIS
    Helper function to format hour values consistently.
.DESCRIPTION
    Formats hour values as numbers with one decimal place or empty string for zero/empty values.
.PARAMETER Value
    The hour value to format.
.EXAMPLE
    Format-HoursValue "2.5"
.OUTPUTS
    String representing the formatted value
#>
function Format-HoursValue {
    param(
        [Parameter(Mandatory=$false)]
        [string]$Value
    )
    
    if ([string]::IsNullOrWhiteSpace($Value)) {
        return ""
    }
    
    $hours = 0.0
    if ([double]::TryParse($Value, [ref]$hours)) {
        if ($hours -eq 0) {
            return ""
        }
        return $hours.ToString("F1")
    }
    
    return $Value
}

<#
.SYNOPSIS
    Creates a new time entry.
.DESCRIPTION
    Creates a new time entry for a project with hours for each day of the week.
.PARAMETER TimeData
    Optional hashtable containing time entry data fields.
.EXAMPLE
    New-TimeEntry
.EXAMPLE
    $timeData = @{
        Nickname = "WEBSITE"
        WeekStartDate = "20240401"
        Description = "Front-end development"
        MonHours = "4.0"
        TueHours = "2.5"
    }
    New-TimeEntry -TimeData $timeData
.OUTPUTS
    PSObject representing the created time entry, or $null if creation failed
#>
function New-TimeEntry {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)]
        [hashtable]$TimeData = $null
    )
    
    Write-AppLog "Creating new time entry" -Level INFO
    Render-Header "Create New Time Entry"
    
    try {
        $config = Get-AppConfig
        $timeEntriesPath = $config.TimeLogFullPath
        $projectsPath = $config.ProjectsFullPath
        
        # Initialize new time entry object
        $newEntry = if ($TimeData) { 
            [PSCustomObject]$TimeData 
        } else { 
            [PSCustomObject]@{} 
        }
        
        # Get project if not provided
        if (-not $newEntry.PSObject.Properties.Name.Contains("Nickname") -or 
            [string]::IsNullOrWhiteSpace($newEntry.Nickname)) {
            
            # Get available projects
            $projects = @(Get-EntityData -FilePath $projectsPath | Where-Object { $_.Status -ne "Closed" })
            
            if ($projects.Count -eq 0) {
                Write-ColorText "No active projects found." -ForegroundColor (Get-CurrentTheme).Colors.Error
                Read-Host "Press Enter to continue..."
                return $null
            }
            
            # Display project selection menu
            $projectMenuItems = @()
            $projectMenuItems += @{ Type = "header"; Text = "Select Project" }
            
            $index = 1
            foreach ($project in $projects | Sort-Object Nickname) {
                $projectMenuItems += @{
                    Type = "option"
                    Key = "$index"
                    Text = "$($project.Nickname) - $($project.FullProjectName)"
                    Function = { 
                        param($selectedProject)
                        return $selectedProject
                    }
                    Args = @($project)
                }
                $index++
            }
            
            $projectMenuItems += @{ Type = "separator" }
            $projectMenuItems += @{
                Type = "option"
                Key = "0"
                Text = "Cancel"
                Function = { return $null }
                IsExit = $true
            }
            
            $selectedProject = Show-DynamicMenu -Title "Select Project" -MenuItems $projectMenuItems
            
            if ($null -eq $selectedProject) {
                Write-ColorText "Operation cancelled." -ForegroundColor (Get-CurrentTheme).Colors.Warning
                Read-Host "Press Enter to continue..."
                return $null
            }
            
            $newEntry | Add-Member -NotePropertyName "Nickname" -NotePropertyValue $selectedProject.Nickname -Force
            
            # Also add project ID fields
            if (-not [string]::IsNullOrWhiteSpace($selectedProject.ID1)) {
                $newEntry | Add-Member -NotePropertyName "ID1" -NotePropertyValue $selectedProject.ID1 -Force
            }
            
            if (-not [string]::IsNullOrWhiteSpace($selectedProject.ID2)) {
                $newEntry | Add-Member -NotePropertyName "ID2" -NotePropertyValue $selectedProject.ID2 -Force
            }
        }
        
        # Set week start date if not provided
        if (-not $newEntry.PSObject.Properties.Name.Contains("WeekStartDate") -or 
            [string]::IsNullOrWhiteSpace($newEntry.WeekStartDate)) {
            
            # Determine current week start date (Monday)
            $today = Get-Date
            $weekStart = Get-FirstDayOfWeek -Date $today
            $defaultWeekStart = $weekStart.ToString("yyyyMMdd")
            
            $weekStartDate = Get-DateInput -PromptText "Enter week start date (Monday, MM/DD/YYYY)" -DefaultValue $defaultWeekStart
            $newEntry | Add-Member -NotePropertyName "WeekStartDate" -NotePropertyValue $weekStartDate -Force
        }
        
        # Prompt for description if not provided
        if (-not $newEntry.PSObject.Properties.Name.Contains("Description")) {
            $description = Read-UserInput -Prompt "Enter description of work (optional)"
            $newEntry | Add-Member -NotePropertyName "Description" -NotePropertyValue $description -Force
        }
        
        # Prompt for hours for each day of the week
        $totalHours = 0.0
        
        foreach ($day in $WEEKDAYS) {
            $dayName = $day -replace "Hours", ""
            
            $hours = 0.0
            
            if ($newEntry.PSObject.Properties.Name.Contains($day) -and 
                -not [string]::IsNullOrWhiteSpace($newEntry.$day) -and
                [double]::TryParse($newEntry.$day, [ref]$hours)) {
                # Already have this day's hours in the provided data
                $totalHours += $hours
            } else {
                # Prompt for this day's hours
                $hourInput = Read-UserInput -Prompt "Enter hours for $dayName (0 or blank for none)" -DefaultValue "0"
                
                if ([string]::IsNullOrWhiteSpace($hourInput) -or $hourInput -eq "0") {
                    $newEntry | Add-Member -NotePropertyName $day -NotePropertyValue "0.0" -Force
                } else {
                    $dayHours = 0.0
                    if ([double]::TryParse($hourInput, [ref]$dayHours)) {
                        $newEntry | Add-Member -NotePropertyName $day -NotePropertyValue $dayHours.ToString("F1") -Force
                        $totalHours += $dayHours
                    } else {
                        Write-ColorText "Invalid hours format. Using 0." -ForegroundColor (Get-CurrentTheme).Colors.Warning
                        $newEntry | Add-Member -NotePropertyName $day -NotePropertyValue "0.0" -Force
                    }
                }
            }
        }
        
        # Set entry ID and dates
        $newEntry | Add-Member -NotePropertyName "EntryID" -NotePropertyValue (New-ID) -Force
        $newEntry | Add-Member -NotePropertyName "Date" -NotePropertyValue (Get-Date).ToString("yyyyMMdd") -Force
        $newEntry | Add-Member -NotePropertyName "TotalHours" -NotePropertyValue $totalHours.ToString("F1") -Force
        
        # Get existing time entries
        $entries = @(Get-EntityData -FilePath $timeEntriesPath -RequiredHeaders $TIME_HEADERS)
        
        # Check for duplicates (same project and week)
        $duplicate = $entries | Where-Object { 
            $_.Nickname -eq $newEntry.Nickname -and 
            $_.WeekStartDate -eq $newEntry.WeekStartDate 
        } | Select-Object -First 1
        
        if ($duplicate) {
            Write-ColorText "Warning: An entry already exists for $($newEntry.Nickname) for this week." -ForegroundColor (Get-CurrentTheme).Colors.Warning
            $confirm = Read-UserInput -Prompt "Do you want to create another entry anyway? (y/n)" -DefaultValue "n"
            
            if ($confirm -ne "y") {
                Write-ColorText "Operation cancelled." -ForegroundColor (Get-CurrentTheme).Colors.Warning
                Read-Host "Press Enter to continue..."
                return $null
            }
        }
        
        # Add the new entry
        $updatedEntries = $entries + $newEntry
        
        # Save time entries
        if (Save-EntityData -Data $updatedEntries -FilePath $timeEntriesPath -RequiredHeaders $TIME_HEADERS) {
            Write-ColorText "Time entry created successfully!" -ForegroundColor (Get-CurrentTheme).Colors.Success
            
            # Update project's cumulative hours
            Update-CumulativeHours -Nickname $newEntry.Nickname
            
            # Log success
            Write-AppLog "Created new time entry for project: $($newEntry.Nickname)" -Level INFO
            
            Read-Host "Press Enter to continue..."
            return $newEntry
        } else {
            Write-ColorText "Failed to save time entry." -ForegroundColor (Get-CurrentTheme).Colors.Error
            Read-Host "Press Enter to continue..."
            return $null
        }
    } catch {
        Handle-Error -ErrorRecord $_ -Context "Creating new time entry" -Continue
        return $null
    }
}

<#
.SYNOPSIS
    Gets a time entry by its ID.
.DESCRIPTION
    Retrieves a time entry object by its ID.
.PARAMETER EntryID
    The ID of the time entry to find.
.EXAMPLE
    $entry = Get-TimeEntry -EntryID "12345678-1234-1234-1234-123456789012"
.OUTPUTS
    PSObject representing the time entry, or $null if not found
#>
function Get-TimeEntry {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$EntryID
    )
    
    try {
        $config = Get-AppConfig
        $timeEntriesPath = $config.TimeLogFullPath
        
        # Get existing time entries
        $entries = @(Get-EntityData -FilePath $timeEntriesPath -RequiredHeaders $TIME_HEADERS)
        
        # Find the entry by ID
        $entry = $entries | Where-Object { $_.EntryID -eq $EntryID } | Select-Object -First 1
        
        if (-not $entry) {
            Write-Verbose "Time entry ID '$EntryID' not found."
            return $null
        }
        
        return $entry
    } catch {
        Handle-Error -ErrorRecord $_ -Context "Getting time entry" -Continue
        return $null
    }
}

<#
.SYNOPSIS
    Updates an existing time entry.
.DESCRIPTION
    Updates an existing time entry with new values.
.PARAMETER EntryID
    The ID of the time entry to update.
.PARAMETER TimeData
    Optional hashtable containing updated time entry data fields.
.EXAMPLE
    Update-TimeEntry -EntryID "12345678-1234-1234-1234-123456789012"
.EXAMPLE
    Update-TimeEntry -EntryID "12345678-1234-1234-1234-123456789012" -TimeData @{ Description = "Updated description"; MonHours = "4.5" }
.OUTPUTS
    PSObject representing the updated time entry, or $null if update failed
#>
function Update-TimeEntry {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$EntryID,
        
        [Parameter(Mandatory=$false)]
        [hashtable]$TimeData = $null
    )
    
    Write-AppLog "Updating time entry: $EntryID" -Level INFO
    Render-Header "Update Time Entry"
    
    try {
        $config = Get-AppConfig
        $timeEntriesPath = $config.TimeLogFullPath
        
        # Get existing time entries
        $entries = @(Get-EntityData -FilePath $timeEntriesPath -RequiredHeaders $TIME_HEADERS)
        $originalEntry = $entries | Where-Object { $_.EntryID -eq $EntryID } | Select-Object -First 1
        
        if (-not $originalEntry) {
            Write-ColorText "Error: Time entry ID '$EntryID' not found." -ForegroundColor (Get-CurrentTheme).Colors.Error
            Read-Host "Press Enter to continue..."
            return $null
        }
        
        # Create a copy of the original entry to update
        $updatedEntry = $originalEntry.PSObject.Copy()
        
        # If time data is provided, update fields from it
        if ($TimeData -and $TimeData.Count -gt 0) {
            foreach ($key in $TimeData.Keys) {
                if ($key -eq "EntryID") {
                    # Skip EntryID as it's the identifier
                    continue
                }
                
                # Update property if it exists
                if ($updatedEntry.PSObject.Properties.Name -contains $key) {
                    $updatedEntry.$key = $TimeData[$key]
                } else {
                    # Add the property if it doesn't exist
                    $updatedEntry | Add-Member -NotePropertyName $key -NotePropertyValue $TimeData[$key] -Force
                }
            }
        } else {
            # Interactive update - prompt for each field
            Write-ColorText "`nUpdating Time Entry for $($updatedEntry.Nickname)" -ForegroundColor (Get-CurrentTheme).Colors.Accent2
            Write-ColorText "Week Starting: $(Convert-InternalDateToDisplay $updatedEntry.WeekStartDate)" -ForegroundColor (Get-CurrentTheme).Colors.Accent2
            Write-ColorText "Enter new value or press Enter to keep current. Enter '0' to cancel." -ForegroundColor (Get-CurrentTheme).Colors.Accent2
            
            # Function to prompt for field update
            function Read-UpdateField {
                param($FieldName, [ref]$EntryObject)
                
                $currentValue = $EntryObject.Value.$FieldName
                $input = Read-UserInput -Prompt "$FieldName (current: $currentValue)"
                
                if ($input -eq '0') {
                    return $false # Cancel
                }
                
                if (-not [string]::IsNullOrWhiteSpace($input) -and $input -ne $currentValue) {
                    $EntryObject.Value.$FieldName = $input
                }
                
                return $true # Continue
            }
            
            # Prompt for description update
            if (-not (Read-UpdateField "Description" ([ref]$updatedEntry))) {
                return $null
            }
            
            # Prompt for hours for each day of the week
            $totalHours = 0.0
            
            foreach ($day in $WEEKDAYS) {
                $dayName = $day -replace "Hours", ""
                $currentHours = $updatedEntry.$day
                
                if ([string]::IsNullOrWhiteSpace($currentHours)) {
                    $currentHours = "0.0"
                }
                
                $hourInput = Read-UserInput -Prompt "$dayName Hours (current: $currentHours)"
                
                if ($hourInput -eq "0") {
                    return $null # Cancel
                }
                
                if (-not [string]::IsNullOrWhiteSpace($hourInput)) {
                    $dayHours = 0.0
                    if ([double]::TryParse($hourInput, [ref]$dayHours)) {
                        $updatedEntry.$day = $dayHours.ToString("F1")
                    } else {
                        Write-ColorText "Invalid hours format. Keeping original." -ForegroundColor (Get-CurrentTheme).Colors.Warning
                    }
                }
                
                # Calculate total hours
                $hours = 0.0
                if ([double]::TryParse($updatedEntry.$day, [ref]$hours)) {
                    $totalHours += $hours
                }
            }
            
            # Update total hours
            $updatedEntry.TotalHours = $totalHours.ToString("F1")
            
            # Update entry date
            $updatedEntry.Date = (Get-Date).ToString("yyyyMMdd")
        }
        
        # Update the entry in the array
        $updatedEntries = @()
        foreach ($entry in $entries) {
            if ($entry.EntryID -eq $EntryID) {
                $updatedEntries += $updatedEntry
            } else {
                $updatedEntries += $entry
            }
        }
        
        # Save time entries
        if (Save-EntityData -Data $updatedEntries -FilePath $timeEntriesPath -RequiredHeaders $TIME_HEADERS) {
            Write-ColorText "Time entry updated successfully!" -ForegroundColor (Get-CurrentTheme).Colors.Success
            
            # Update project's cumulative hours
            Update-CumulativeHours -Nickname $updatedEntry.Nickname
            
            # Log success
            Write-AppLog "Updated time entry: $EntryID for project $($updatedEntry.Nickname)" -Level INFO
            
            Read-Host "Press Enter to continue..."
            return $updatedEntry
        } else {
            Write-ColorText "Failed to save updated time entry." -ForegroundColor (Get-CurrentTheme).Colors.Error
            Read-Host "Press Enter to continue..."
            return $null
        }
    } catch {
        Handle-Error -ErrorRecord $_ -Context "Updating time entry" -Continue
        return $null
    }
}

<#
.SYNOPSIS
    Removes a time entry.
.DESCRIPTION
    Deletes a time entry by its ID.
.PARAMETER EntryID
    The ID of the time entry to delete.
.EXAMPLE
    Remove-TimeEntry -EntryID "12345678-1234-1234-1234-123456789012"
.OUTPUTS
    Boolean indicating success or failure
#>
function Remove-TimeEntry {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$EntryID
    )
    
    Write-AppLog "Deleting time entry: $EntryID" -Level INFO
    Render-Header "Delete Time Entry"
    
    try {
        $config = Get-AppConfig
        $timeEntriesPath = $config.TimeLogFullPath
        
        # Get existing time entries
        $entries = @(Get-EntityData -FilePath $timeEntriesPath -RequiredHeaders $TIME_HEADERS)
        $entryToDelete = $entries | Where-Object { $_.EntryID -eq $EntryID } | Select-Object -First 1
        
        if (-not $entryToDelete) {
            Write-ColorText "Error: Time entry ID '$EntryID' not found." -ForegroundColor (Get-CurrentTheme).Colors.Error
            Read-Host "Press Enter to continue..."
            return $false
        }
        
        # Confirm deletion
        Write-ColorText "Are you sure you want to delete this time entry?" -ForegroundColor (Get-CurrentTheme).Colors.Warning
        Write-ColorText "Project: $($entryToDelete.Nickname)" -ForegroundColor (Get-CurrentTheme).Colors.Normal
        Write-ColorText "Week Starting: $(Convert-InternalDateToDisplay $entryToDelete.WeekStartDate)" -ForegroundColor (Get-CurrentTheme).Colors.Normal
        Write-ColorText "Total Hours: $($entryToDelete.TotalHours)" -ForegroundColor (Get-CurrentTheme).Colors.Normal
        
        $confirm = Read-UserInput -Prompt "Type 'yes' to confirm"
        
        if ($confirm -ne "yes") {
            Write-ColorText "Deletion cancelled." -ForegroundColor (Get-CurrentTheme).Colors.Warning
            Read-Host "Press Enter to continue..."
            return $false
        }
        
        # Store the project nickname for updating hours later
        $projectNickname = $entryToDelete.Nickname
        
        # Remove the entry
        $updatedEntries = $entries | Where-Object { $_.EntryID -ne $EntryID }
        
        # Save time entries
        if (Save-EntityData -Data $updatedEntries -FilePath $timeEntriesPath -RequiredHeaders $TIME_HEADERS) {
            Write-ColorText "Time entry deleted successfully!" -ForegroundColor (Get-CurrentTheme).Colors.Success
            
            # Update project's cumulative hours
            Update-CumulativeHours -Nickname $projectNickname
            
            # Log success
            Write-AppLog "Deleted time entry: $EntryID for project $projectNickname" -Level INFO
            
            Read-Host "Press Enter to continue..."
            return $true
        } else {
            Write-ColorText "Failed to save changes after deletion." -ForegroundColor (Get-CurrentTheme).Colors.Error
            Read-Host "Press Enter to continue..."
            return $false
        }
    } catch {
        Handle-Error -ErrorRecord $_ -Context "Deleting time entry" -Continue
        return $false
    }
}

<#
.SYNOPSIS
    Shows a time report with summary information.
.DESCRIPTION
    Displays a summary report of time entries, grouped by project, week, or both.
.PARAMETER GroupBy
    How to group the time entries. Options: Project, Week, Both.
.PARAMETER StartDate
    The start date for filtering entries (YYYYMMDD format).
.PARAMETER EndDate
    The end date for filtering entries (YYYYMMDD format).
.EXAMPLE
    Show-TimeReport -GroupBy "Project" -StartDate "20240401" -EndDate "20240430"
.OUTPUTS
    None
#>
function Show-TimeReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)]
        [ValidateSet("Project", "Week", "Both")]
        [string]$GroupBy = "Project",
        
        [Parameter(Mandatory=$false)]
        [string]$StartDate = "",
        
        [Parameter(Mandatory=$false)]
        [string]$EndDate = ""
    )
    
    Write-AppLog "Generating time report (GroupBy: $GroupBy)" -Level INFO
    
    try {
        $config = Get-AppConfig
        $timeEntriesPath = $config.TimeLogFullPath
        $projectsPath = $config.ProjectsFullPath
        
        # Get time entries
        $entries = @(Get-EntityData -FilePath $timeEntriesPath -RequiredHeaders $TIME_HEADERS)
        
        # Apply date filters
        if (-not [string]::IsNullOrWhiteSpace($StartDate)) {
            $entries = $entries | Where-Object { 
                [string]::IsNullOrWhiteSpace($_.WeekStartDate) -or 
                $_.WeekStartDate -ge $StartDate 
            }
        }
        
        if (-not [string]::IsNullOrWhiteSpace($EndDate)) {
            $entries = $entries | Where-Object { 
                [string]::IsNullOrWhiteSpace($_.WeekStartDate) -or 
                $_.WeekStartDate -le $EndDate 
            }
        }
        
        # Get projects for names
        $projects = @(Get-EntityData -FilePath $projectsPath)
        
        # Build title based on parameters
        $title = "Time Report"
        if (-not [string]::IsNullOrWhiteSpace($StartDate) -and -not [string]::IsNullOrWhiteSpace($EndDate)) {
            $startDisplay = Convert-InternalDateToDisplay -InternalDate $StartDate
            $endDisplay = Convert-InternalDateToDisplay -InternalDate $EndDate
            $title += " ($startDisplay to $endDisplay)"
        }
        
        Render-Header -Title $title -Subtitle "Grouped by $GroupBy"
        
        if ($entries.Count -eq 0) {
            Write-ColorText "No time entries found for the selected period." -ForegroundColor (Get-CurrentTheme).Colors.Warning
            Read-Host "Press Enter to continue..."
            return
        }
        
        # Group and summarize based on GroupBy parameter
        switch ($GroupBy) {
            "Project" {
                # Group by project
                $projectGroups = @{}
                
                foreach ($entry in $entries) {
                    $nickname = $entry.Nickname
                    
                    if (-not $projectGroups.ContainsKey($nickname)) {
                        $projectGroups[$nickname] = @{
                            Nickname = $nickname
                            TotalHours = 0.0
                            Entries = 0
                            Weeks = @{}
                        }
                    }
                    
                    # Add hours
                    $hours = 0.0
                    if (-not [string]::IsNullOrWhiteSpace($entry.TotalHours) -and 
                        [double]::TryParse($entry.TotalHours, [ref]$hours)) {
                        $projectGroups[$nickname].TotalHours += $hours
                        $projectGroups[$nickname].Entries++
                        
                        # Track weeks
                        if (-not [string]::IsNullOrWhiteSpace($entry.WeekStartDate)) {
                            if (-not $projectGroups[$nickname].Weeks.ContainsKey($entry.WeekStartDate)) {
                                $projectGroups[$nickname].Weeks[$entry.WeekStartDate] = 0.0
                            }
                            $projectGroups[$nickname].Weeks[$entry.WeekStartDate] += $hours
                        }
                    }
                }
                
                # Create report data
                $reportData = @()
                
                foreach ($key in $projectGroups.Keys) {
                    $group = $projectGroups[$key]
                    
                    # Find project name
                    $projectName = $key # Default to nickname
                    $project = $projects | Where-Object { $_.Nickname -eq $key } | Select-Object -First 1
                    if ($project) {
                        $projectName = $project.FullProjectName
                    }
                    
                    $reportData += [PSCustomObject]@{
                        Nickname = $key
                        ProjectName = $projectName
                        TotalHours = $group.TotalHours
                        Entries = $group.Entries
                        WeekCount = $group.Weeks.Count
                    }
                }
                
                # Sort by total hours descending
                $sortedData = $reportData | Sort-Object -Property TotalHours -Descending
                
                # Display table
                $tableHeaders = @{
                    Nickname = "Project"
                    ProjectName = "Full Name"
                    TotalHours = "Total Hours"
                    Entries = "Entries"
                    WeekCount = "Weeks"
                }
                
                $tableFormatters = @{
                    TotalHours = { param($val) $val.ToString("F1") }
                }
                
                Show-Table -Data $sortedData -Columns @("Nickname", "ProjectName", "TotalHours", "Entries", "WeekCount") -Headers $tableHeaders -Formatters $tableFormatters
                
                # Calculate grand total
                $grandTotal = ($sortedData | Measure-Object -Property TotalHours -Sum).Sum
                Write-ColorText "`nGrand Total: $($grandTotal.ToString("F1")) hours across $($sortedData.Count) projects" -ForegroundColor (Get-CurrentTheme).Colors.Accent2
            }
            "Week" {
                # Group by week
                $weekGroups = @{}
                
                foreach ($entry in $entries) {
                    $weekStart = $entry.WeekStartDate
                    
                    if ([string]::IsNullOrWhiteSpace($weekStart)) {
                        # Skip entries without week start date
                        continue
                    }
                    
                    if (-not $weekGroups.ContainsKey($weekStart)) {
                        $weekGroups[$weekStart] = @{
                            WeekStart = $weekStart
                            TotalHours = 0.0
                            Projects = @{}
                        }
                    }
                    
                    # Add hours
                    $hours = 0.0
                    if (-not [string]::IsNullOrWhiteSpace($entry.TotalHours) -and 
                        [double]::TryParse($entry.TotalHours, [ref]$hours)) {
                        $weekGroups[$weekStart].TotalHours += $hours
                        
                        # Track projects
                        $nickname = $entry.Nickname
                        if (-not $weekGroups[$weekStart].Projects.ContainsKey($nickname)) {
                            $weekGroups[$weekStart].Projects[$nickname] = 0.0
                        }
                        $weekGroups[$weekStart].Projects[$nickname] += $hours
                    }
                }
                
                # Create report data
                $reportData = @()
                
                foreach ($key in $weekGroups.Keys) {
                    $group = $weekGroups[$key]
                    
                    # Convert week start to display format
                    $weekStartDisplay = Convert-InternalDateToDisplay -InternalDate $key
                    
                    # Calculate week end date (6 days after start)
                    $weekStartDate = [DateTime]::ParseExact($key, "yyyyMMdd", $null)
                    $weekEndDate = $weekStartDate.AddDays(6)
                    $weekEndDisplay = $weekEndDate.ToString($config.DisplayDateFormat)
                    
                    $reportData += [PSCustomObject]@{
                        WeekStart = $key
                        WeekStartDisplay = $weekStartDisplay
                        WeekEndDisplay = $weekEndDisplay
                        TotalHours = $group.TotalHours
                        ProjectCount = $group.Projects.Count
                    }
                }
                
                # Sort by week start date descending
                $sortedData = $reportData | Sort-Object -Property WeekStart -Descending
                
                # Display table
                $tableHeaders = @{
                    WeekStartDisplay = "Week Start"
                    WeekEndDisplay = "Week End"
                    TotalHours = "Total Hours"
                    ProjectCount = "Projects"
                }
                
                $tableFormatters = @{
                    TotalHours = { param($val) $val.ToString("F1") }
                }
                
                Show-Table -Data $sortedData -Columns @("WeekStartDisplay", "WeekEndDisplay", "TotalHours", "ProjectCount") -Headers $tableHeaders -Formatters $tableFormatters
                
                # Calculate grand total
                $grandTotal = ($sortedData | Measure-Object -Property TotalHours -Sum).Sum
                $weekCount = $sortedData.Count
                Write-ColorText "`nGrand Total: $($grandTotal.ToString("F1")) hours across $weekCount weeks" -ForegroundColor (Get-CurrentTheme).Colors.Accent2
                
                # Calculate average hours per week
                if ($weekCount -gt 0) {
                    $avgHoursPerWeek = $grandTotal / $weekCount
                    Write-ColorText "Average: $($avgHoursPerWeek.ToString("F1")) hours per week" -ForegroundColor (Get-CurrentTheme).Colors.Accent2
                }
            }
            "Both" {
                # Create a matrix of projects x weeks
                $projectWeekMatrix = @{}
                $weekList = @()
                $projectList = @()
                
                foreach ($entry in $entries) {
                    $nickname = $entry.Nickname
                    $weekStart = $entry.WeekStartDate
                    
                    if ([string]::IsNullOrWhiteSpace($weekStart)) {
                        # Skip entries without week start date
                        continue
                    }
                    
                    # Ensure project is in list
                    if (-not $projectList.Contains($nickname)) {
                        $projectList += $nickname
                    }
                    
                    # Ensure week is in list
                    if (-not $weekList.Contains($weekStart)) {
                        $weekList += $weekStart
                    }
                    
                    # Create project entry if needed
                    if (-not $projectWeekMatrix.ContainsKey($nickname)) {
                        $projectWeekMatrix[$nickname] = @{
                            Nickname = $nickname
                            TotalHours = 0.0
                            Weeks = @{}
                        }
                    }
                    
                    # Create week entry if needed
                    if (-not $projectWeekMatrix[$nickname].Weeks.ContainsKey($weekStart)) {
                        $projectWeekMatrix[$nickname].Weeks[$weekStart] = 0.0
                    }
                    
                    # Add hours
                    $hours = 0.0
                    if (-not [string]::IsNullOrWhiteSpace($entry.TotalHours) -and 
                        [double]::TryParse($entry.TotalHours, [ref]$hours)) {
                        $projectWeekMatrix[$nickname].TotalHours += $hours
                        $projectWeekMatrix[$nickname].Weeks[$weekStart] += $hours
                    }
                }
                
                # Sort the lists
                $projectList = $projectList | Sort-Object
                $weekList = $weekList | Sort-Object -Descending
                
                # Create column list - we'll have one column per week plus project and total
                $columns = @("Nickname")
                foreach ($week in $weekList) {
                    $columns += "Week_$week"
                }
                $columns += "TotalHours"
                
                # Create report data
                $reportData = @()
                
                foreach ($project in $projectList) {
                    $row = [ordered]@{
                        Nickname = $project
                    }
                    
                    # Add each week's hours
                    foreach ($week in $weekList) {
                        $weekHours = 0.0
                        if ($projectWeekMatrix[$project].Weeks.ContainsKey($week)) {
                            $weekHours = $projectWeekMatrix[$project].Weeks[$week]
                        }
                        $row["Week_$week"] = $weekHours
                    }
                    
                    # Add total hours
                    $row["TotalHours"] = $projectWeekMatrix[$project].TotalHours
                    
                    $reportData += [PSCustomObject]$row
                }
                
                # Sort by total hours descending
                $sortedData = $reportData | Sort-Object -Property TotalHours -Descending
                
                # Create table headers
                $tableHeaders = @{
                    Nickname = "Project"
                    TotalHours = "Total"
                }
                
                foreach ($week in $weekList) {
                    # Convert week to display format
                    $weekStartDisplay = Convert-InternalDateToDisplay -InternalDate $week
                    $tableHeaders["Week_$week"] = $weekStartDisplay
                }
                
                # Create formatters
                $tableFormatters = @{
                    TotalHours = { param($val) $val.ToString("F1") }
                }
                
                foreach ($week in $weekList) {
                    $tableFormatters["Week_$week"] = { param($val) if ($val -eq 0) { "" } else { $val.ToString("F1") } }
                }
                
                # Display table - limit to 5 most recent weeks to prevent overflow
                $displayColumns = @("Nickname")
                $weekCounter = 0
                foreach ($week in $weekList) {
                    $displayColumns += "Week_$week"
                    $weekCounter++
                    if ($weekCounter -ge 5) {
                        break
                    }
                }
                $displayColumns += "TotalHours"
                
                Show-Table -Data $sortedData -Columns $displayColumns -Headers $tableHeaders -Formatters $tableFormatters
                
                # Calculate grand total
                $grandTotal = ($sortedData | Measure-Object -Property TotalHours -Sum).Sum
                Write-ColorText "`nGrand Total: $($grandTotal.ToString("F1")) hours across $($projectList.Count) projects and $($weekList.Count) weeks" -ForegroundColor (Get-CurrentTheme).Colors.Accent2
            }
        }
        
        # Log success
        Write-AppLog "Successfully generated time report (GroupBy: $GroupBy)" -Level INFO
        
        # Wait for user input
        Read-Host "Press Enter to continue..."
    } catch {
        Handle-Error -ErrorRecord $_ -Context "Generating time report" -Continue
    }
}

<#
.SYNOPSIS
    Shows the time tracking menu.
.DESCRIPTION
    Displays a menu with options for managing time entries and reports.
.EXAMPLE
    Show-TimeMenu
.OUTPUTS
    Boolean indicating if the menu should exit
#>
function Show-TimeMenu {
    [CmdletBinding()]
    param()
    
    $menuItems = @()
    
    $menuItems += @{
        Type = "header"
        Text = "Time Tracking"
    }
    
    $menuItems += @{
        Type = "option"
        Key = "1"
        Text = "View Time Entries"
        Function = {
            # Prompt for filter type
            $filterMenuItems = @()
            $filterMenuItems += @{ Type = "header"; Text = "Select Filter Type" }
            $filterMenuItems += @{ Type = "option"; Key = "1"; Text = "View All Entries"; Function = { Show-TimeEntryList; return $null } }
            $filterMenuItems += @{ Type = "option"; Key = "2"; Text = "Filter by Date Range"; Function = {
                $startDate = Get-DateInput -PromptText "Enter start date" -AllowCancel
                if ($null -eq $startDate) { return $null }
                
                $endDate = Get-DateInput -PromptText "Enter end date" -DefaultValue (Get-Date).ToString("yyyyMMdd") -AllowCancel
                if ($null -eq $endDate) { return $null }
                
                Show-TimeEntryList -StartDate $startDate -EndDate $endDate
                return $null
            }}
            $filterMenuItems += @{ Type = "option"; Key = "3"; Text = "Filter by Project"; Function = {
                # Get projects
                $config = Get-AppConfig
                $projects = @(Get-EntityData -FilePath $config.ProjectsFullPath)
                
                # Display project selection menu
                $projectMenuItems = @()
                $projectMenuItems += @{ Type = "header"; Text = "Select Project" }
                
                $index = 1
                foreach ($project in $projects | Sort-Object Nickname) {
                    $projectMenuItems += @{
                        Type = "option"
                        Key = "$index"
                        Text = "$($project.Nickname) - $($project.FullProjectName)"
                        Function = { 
                            param($selectedProject)
                            Show-TimeEntryList -Nickname $selectedProject.Nickname
                            return $null
                        }
                        Args = @($project)
                    }
                    $index++
                }
                
                $projectMenuItems += @{ Type = "separator" }
                $projectMenuItems += @{
                    Type = "option"
                    Key = "0"
                    Text = "Cancel"
                    Function = { return $null }
                    IsExit = $true
                }
                
                return Show-DynamicMenu -Title "Select Project" -MenuItems $projectMenuItems
            }}
            $filterMenuItems += @{ Type = "separator" }
            $filterMenuItems += @{
                Type = "option"
                Key = "0"
                Text = "Back"
                Function = { return $null }
                IsExit = $true
            }
            
            return Show-DynamicMenu -Title "Filter Time Entries" -MenuItems $filterMenuItems
        }
    }
    
    $menuItems += @{
        Type = "option"
        Key = "2"
        Text = "Add New Time Entry"
        Function = {
            New-TimeEntry
            return $null
        }
    }
    
    $menuItems += @{
        Type = "option"
        Key = "3"
        Text = "Update Time Entry"
        Function = {
            # First list time entries
            $entries = Show-TimeEntryList
            
            if ($entries.Count -eq 0) {
                return $null
            }
            
            # Prompt for entry ID
            $entryID = Read-UserInput -Prompt "Enter Entry ID to update (or 0 to cancel)"
            
            if ($entryID -eq "0") {
                Write-ColorText "Update cancelled." -ForegroundColor (Get-CurrentTheme).Colors.Warning
                Read-Host "Press Enter to continue..."
                return $null
            }
            
            # Update the entry
            Update-TimeEntry -EntryID $entryID
            return $null
        }
    }
    
    $menuItems += @{
        Type = "option"
        Key = "4"
        Text = "Delete Time Entry"
        Function = {
            # First list time entries
            $entries = Show-TimeEntryList
            
            if ($entries.Count -eq 0) {
                return $null
            }
            
            # Prompt for entry ID
            $entryID = Read-UserInput -Prompt "Enter Entry ID to delete (or 0 to cancel)"
            
            if ($entryID -eq "0") {
                Write-ColorText "Deletion cancelled." -ForegroundColor (Get-CurrentTheme).Colors.Warning
                Read-Host "Press Enter to continue..."
                return $null
            }
            
            # Delete the entry
            Remove-TimeEntry -EntryID $entryID
            return $null
        }
    }
    
    $menuItems += @{
        Type = "option"
        Key = "5"
        Text = "View Time Reports"
        Function = {
            # Prompt for report type
            $reportMenuItems = @()
            $reportMenuItems += @{ Type = "header"; Text = "Select Report Type" }
            $reportMenuItems += @{ Type = "option"; Key = "1"; Text = "By Project"; Function = {
                $startDate = Get-DateInput -PromptText "Enter start date (optional, press Enter to skip)" -AllowCancel -AllowEmpty
                if ($startDate -eq "CANCEL") { return $null }
                
                $endDate = ""
                if (-not [string]::IsNullOrWhiteSpace($startDate)) {
                    $endDate = Get-DateInput -PromptText "Enter end date" -DefaultValue (Get-Date).ToString("yyyyMMdd") -AllowCancel
                    if ($null -eq $endDate) { return $null }
                }
                
                Show-TimeReport -GroupBy "Project" -StartDate $startDate -EndDate $endDate
                return $null
            }}
            $reportMenuItems += @{ Type = "option"; Key = "2"; Text = "By Week"; Function = {
                $startDate = Get-DateInput -PromptText "Enter start date (optional, press Enter to skip)" -AllowCancel -AllowEmpty
                if ($startDate -eq "CANCEL") { return $null }
                
                $endDate = ""
                if (-not [string]::IsNullOrWhiteSpace($startDate)) {
                    $endDate = Get-DateInput -PromptText "Enter end date" -DefaultValue (Get-Date).ToString("yyyyMMdd") -AllowCancel
                    if ($null -eq $endDate) { return $null }
                }
                
                Show-TimeReport -GroupBy "Week" -StartDate $startDate -EndDate $endDate
                return $null
            }}
            $reportMenuItems += @{ Type = "option"; Key = "3"; Text = "Matrix (Projects x Weeks)"; Function = {
                $startDate = Get-DateInput -PromptText "Enter start date (optional, press Enter to skip)" -AllowCancel -AllowEmpty
                if ($startDate -eq "CANCEL") { return $null }
                
                $endDate = ""
                if (-not [string]::IsNullOrWhiteSpace($startDate)) {
                    $endDate = Get-DateInput -PromptText "Enter end date" -DefaultValue (Get-Date).ToString("yyyyMMdd") -AllowCancel
                    if ($null -eq $endDate) { return $null }
                }
                
                Show-TimeReport -GroupBy "Both" -StartDate $startDate -EndDate $endDate
                return $null
            }}
            $reportMenuItems += @{ Type = "separator" }
            $reportMenuItems += @{
                Type = "option"
                Key = "0"
                Text = "Back"
                Function = { return $null }
                IsExit = $true
            }
            
            return Show-DynamicMenu -Title "Time Reports" -MenuItems $reportMenuItems
        }
    }
    
    $menuItems += @{
        Type = "separator"
    }
    
    $menuItems += @{
        Type = "option"
        Key = "0"
        Text = "Back to Main Menu"
        Function = { return $true }
        IsExit = $false  # Changed to false to prevent exiting application
    }
    
    return Show-DynamicMenu -Title "Time Tracking" -MenuItems $menuItems
}

# Export functions
Export-ModuleMember -Function Show-TimeEntryList, New-TimeEntry, Update-TimeEntry, Remove-TimeEntry, Get-TimeEntry, Show-TimeReport, Show-TimeMenu