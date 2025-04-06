# ProjectTracker.Projects.psm1
# Project Management Module for Project Tracker
# Handles creating, updating, listing, and managing projects

# Constants and project configuration
$PROJECTS_HEADERS = @(
    "FullProjectName", "Nickname", "ID1", "ID2", "DateAssigned",
    "DueDate", "BFDate", "CumulativeHrs", "Note", "ProjFolder",
    "ClosedDate", "Status"
)

$REQUIRED_PROJECT_FIELDS = @(
    "FullProjectName", "Nickname", "DateAssigned", "DueDate", "BFDate"
)

# TODO HEADERS needed for updating related todo items
$TODO_HEADERS = @(
    "ID", "Nickname", "TaskDescription", "Importance", "DueDate", 
    "Status", "CreatedDate", "CompletedDate"
)

<#
.SYNOPSIS
    Lists active or all projects.
.DESCRIPTION
    Retrieves and displays a list of projects, either all or only active ones.
    Active projects are those not marked as "Closed".
.PARAMETER IncludeAll
    If specified, includes closed projects in the listing.
.EXAMPLE
    Show-ProjectList
    Show-ProjectList -IncludeAll
.OUTPUTS
    Array of project objects
#>
function Show-ProjectList {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)]
        [switch]$IncludeAll
    )
    
    Write-AppLog "Listing projects (IncludeAll: $IncludeAll)" -Level INFO
    
    try {
        $config = Get-AppConfig
        $ProjectsFilePath = $config.ProjectsFullPath
        
        # Get projects
        $projects = @(Get-EntityData -FilePath $ProjectsFilePath -RequiredHeaders $PROJECTS_HEADERS)
        
        # Filter by status if not including all
        if (-not $IncludeAll) {
            $projects = $projects | Where-Object {
                $_.Status -ne "Closed" -and [string]::IsNullOrWhiteSpace($_.ClosedDate)
            }
        }
        
        # Update hours before display
        foreach ($project in $projects) {
            Update-CumulativeHours -Nickname $project.Nickname
        }
        
        # Re-get projects after update
        $projects = @(Get-EntityData -FilePath $ProjectsFilePath -RequiredHeaders $PROJECTS_HEADERS)
        
        # Filter again in case headers were added
        if (-not $IncludeAll) {
            $projects = $projects | Where-Object {
                $_.Status -ne "Closed" -and [string]::IsNullOrWhiteSpace($_.ClosedDate)
            }
        }
        
        # Display projects
        $viewTitle = if ($IncludeAll) { "All Projects" } else { "Active Projects" }
        Render-Header -Title $viewTitle
        
        if ($projects.Count -eq 0) {
            Write-ColorText "No projects found." -ForegroundColor (Get-CurrentTheme).Colors.Warning
            Read-Host "Press Enter to continue..."
            return $projects
        }
        
        # Define display columns
        $columnsToShow = @("Nickname", "FullProjectName", "DateAssigned", "DueDate", "BFDate", "CumulativeHrs", "Note", "Status")
        
        # Define column headers
        $tableHeaders = @{
            FullProjectName = "Full Name"
            DateAssigned = "Assigned"
            DueDate = "Due"
            BFDate = "BF Date"
            CumulativeHrs = "Hrs"
            Note = "Notes"
        }
        
        # Define column formatters
        $today = (Get-Date).Date
        
        $tableFormatters = @{
            DateAssigned = { param($val) Convert-InternalDateToDisplay $val }
            DueDate = { param($val) Convert-InternalDateToDisplay $val }
            BFDate = { param($val) Convert-InternalDateToDisplay $val }
            CumulativeHrs = {
                param($val)
                try {
                    [double]::Parse($val).ToString("F1")
                } catch {
                    $val
                }
            }
        }
        
        # Define row colorizer
        $rowColorizer = {
            param($item, $rowIndex)
            $colors = (Get-CurrentTheme).Colors
            $status = if ([string]::IsNullOrWhiteSpace($item.Status)) { "Active" } else { $item.Status }
            
            if ($status -eq "Closed") {
                return $colors.Completed
            }
            
            if ($status -eq "On Hold") {
                return $colors.Warning
            }
            
            try {
                $dueDate = $item.DueDate
                if($dueDate -match '^\d{8}$') {
                    $dt = [datetime]::ParseExact($dueDate, "yyyyMMdd", $null).Date
                    if ($dt -lt $today) {
                        return $colors.Overdue
                    }
                    if (($dt - $today).Days -le 7) {
                        return $colors.DueSoon
                    }
                }
            } catch {}
            
            return $colors.Normal
        }
        
        # Display the table
        Show-Table -Data $projects -Columns $columnsToShow -Headers $tableHeaders -Formatters $tableFormatters -RowColorizer $rowColorizer
        
        # Log success
        Write-AppLog "Successfully listed $($projects.Count) projects" -Level INFO
        
        # Wait for user input
        Read-Host "Press Enter to continue..."
        
        # Return projects array for potential use by other functions
        return $projects
    } catch {
        Handle-Error -ErrorRecord $_ -Context "Listing projects" -Continue
        return @()
    }
}

<#
.SYNOPSIS
    Creates a new project with numeric navigation.
.DESCRIPTION
    Creates a new project with the specified properties.
    Takes input from the user for each field with numeric navigation.
.PARAMETER ProjectData
    Optional hashtable containing project data fields.
.EXAMPLE
    New-TrackerProject
#>
function New-TrackerProject {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)]
        [hashtable]$ProjectData = $null
    )
    
    Write-AppLog "Creating new project" -Level INFO
    Render-Header "Create New Project"
    
    try {
        $config = Get-AppConfig
        $ProjectsFilePath = $config.ProjectsFullPath
        $TodosFilePath = $config.TodosFullPath
        
        # Initialize new project object
        $newProj = if ($ProjectData) { 
            [PSCustomObject]$ProjectData 
        } else { 
            [PSCustomObject]@{} 
        }
        
        # Prompt for nickname if not provided
        if (-not $newProj.PSObject.Properties.Name.Contains("Nickname") -or 
            [string]::IsNullOrWhiteSpace($newProj.Nickname)) {
            
            $nicknameValidator = {
                param($input)
                
                if ($input -eq "CANCEL") { return $true } # Special case for cancellation
                
                if ([string]::IsNullOrWhiteSpace($input)) {
                    Write-ColorText "Nickname cannot be empty." -ForegroundColor (Get-CurrentTheme).Colors.Error
                    return $false
                }
                
                if ($input.Length -gt 15) {
                    Write-ColorText "Nickname must be 15 characters or less." -ForegroundColor (Get-CurrentTheme).Colors.Error
                    return $false
                }
                
                # Check if nickname already exists
                $projects = @(Get-EntityData -FilePath $ProjectsFilePath)
                $existingProject = $projects | Where-Object { $_.Nickname -eq $input } | Select-Object -First 1
                
                if ($existingProject) {
                    Write-ColorText "Nickname '$input' already exists." -ForegroundColor (Get-CurrentTheme).Colors.Error
                    return $false
                }
                
                return $true
            }
            
            $nickName = Read-UserInput -Prompt "Enter Nickname (unique, max 15 chars)" -Validator $nicknameValidator -ErrorMessage "Invalid nickname."
            
            if ($nickName -eq "CANCEL") {
                Write-ColorText "Project creation cancelled." -ForegroundColor (Get-CurrentTheme).Colors.Warning
                Read-Host "Press Enter to continue..."
                return $null
            }
            
            $newProj | Add-Member -NotePropertyName "Nickname" -NotePropertyValue $nickName -Force
        }
        
        # Prompt for full project name if not provided
        if (-not $newProj.PSObject.Properties.Name.Contains("FullProjectName") -or 
            [string]::IsNullOrWhiteSpace($newProj.FullProjectName)) {
            
            $fullNameValidator = {
                param($input)
                
                if ($input -eq "CANCEL") { return $true } # Special case for cancellation
                
                if ([string]::IsNullOrWhiteSpace($input)) {
                    Write-ColorText "Full Name cannot be empty." -ForegroundColor (Get-CurrentTheme).Colors.Error
                    return $false
                }
                
                return $true
            }
            
            $fullName = Read-UserInput -Prompt "Enter Full Project Name" -Validator $fullNameValidator -ErrorMessage "Invalid full name."
            
            if ($fullName -eq "CANCEL") {
                Write-ColorText "Project creation cancelled." -ForegroundColor (Get-CurrentTheme).Colors.Warning
                Read-Host "Press Enter to continue..."
                return $null
            }
            
            $newProj | Add-Member -NotePropertyName "FullProjectName" -NotePropertyValue $fullName -Force
        }
        
        # Prompt for ID1 if not provided
        if (-not $newProj.PSObject.Properties.Name.Contains("ID1")) {
            $id1 = Read-UserInput -Prompt "Enter ID1 (e.g., Client Code, optional)"
            
            if ($id1 -eq "CANCEL") {
                Write-ColorText "Project creation cancelled." -ForegroundColor (Get-CurrentTheme).Colors.Warning
                Read-Host "Press Enter to continue..."
                return $null
            }
            
            $newProj | Add-Member -NotePropertyName "ID1" -NotePropertyValue $id1 -Force
        }
        
        # Prompt for ID2 if not provided
        if (-not $newProj.PSObject.Properties.Name.Contains("ID2")) {
            $id2 = Read-UserInput -Prompt "Enter ID2 (e.g., Engagement Code, optional)"
            
            if ($id2 -eq "CANCEL") {
                Write-ColorText "Project creation cancelled." -ForegroundColor (Get-CurrentTheme).Colors.Warning
                Read-Host "Press Enter to continue..."
                return $null
            }
            
            $newProj | Add-Member -NotePropertyName "ID2" -NotePropertyValue $id2 -Force
        }
        
        # Prompt for assigned date if not provided
        if (-not $newProj.PSObject.Properties.Name.Contains("DateAssigned") -or 
            [string]::IsNullOrWhiteSpace($newProj.DateAssigned)) {
            
            $assignedDate = Get-DateInput -PromptText "Enter Assigned Date (MM/DD/YYYY)" -AllowEmptyForToday -AllowCancel
            
            if ($null -eq $assignedDate) {
                Write-ColorText "Project creation cancelled." -ForegroundColor (Get-CurrentTheme).Colors.Warning
                Read-Host "Press Enter to continue..."
                return $null
            }
            
            $newProj | Add-Member -NotePropertyName "DateAssigned" -NotePropertyValue $assignedDate -Force
        }
        
        # Calculate Due Date (default: 42 days from assigned date) if not provided
        if (-not $newProj.PSObject.Properties.Name.Contains("DueDate") -or 
            [string]::IsNullOrWhiteSpace($newProj.DueDate)) {
            
            $dtAssigned = [datetime]::ParseExact($newProj.DateAssigned, "yyyyMMdd", $null)
            $dtDue = $dtAssigned.AddDays(42)
            $dueDate = $dtDue.ToString("yyyyMMdd")
            
            Write-ColorText "Due Date calculated: $(Convert-InternalDateToDisplay $dueDate)" -ForegroundColor (Get-CurrentTheme).Colors.Accent2
            $newProj | Add-Member -NotePropertyName "DueDate" -NotePropertyValue $dueDate -Force
        }
        
        # Prompt for BF Date if not provided
        if (-not $newProj.PSObject.Properties.Name.Contains("BFDate") -or 
            [string]::IsNullOrWhiteSpace($newProj.BFDate)) {
            
            $bfDatePrompt = "Enter BF Date (MM/DD/YYYY, Enter=DueDate)"
            $bfDate = Get-DateInput -PromptText $bfDatePrompt -DefaultValue $newProj.DueDate -AllowCancel
            
            if ($null -eq $bfDate) {
                Write-ColorText "Project creation cancelled." -ForegroundColor (Get-CurrentTheme).Colors.Warning
                Read-Host "Press Enter to continue..."
                return $null
            }
            
            $newProj | Add-Member -NotePropertyName "BFDate" -NotePropertyValue $bfDate -Force
        }
        
        # Prompt for Note if not provided
        if (-not $newProj.PSObject.Properties.Name.Contains("Note")) {
            $note = Read-UserInput -Prompt "Enter Note (optional)"
            
            if ($note -eq "CANCEL") {
                Write-ColorText "Project creation cancelled." -ForegroundColor (Get-CurrentTheme).Colors.Warning
                Read-Host "Press Enter to continue..."
                return $null
            }
            
            $newProj | Add-Member -NotePropertyName "Note" -NotePropertyValue $note -Force
        }
        
        # Prompt for Project Folder if not provided
        if (-not $newProj.PSObject.Properties.Name.Contains("ProjFolder")) {
            $projFolder = Read-UserInput -Prompt "Enter Project Folder Path (optional)"
            
            if ($projFolder -eq "CANCEL") {
                Write-ColorText "Project creation cancelled." -ForegroundColor (Get-CurrentTheme).Colors.Warning
                Read-Host "Press Enter to continue..."
                return $null
            }
            
            $newProj | Add-Member -NotePropertyName "ProjFolder" -NotePropertyValue $projFolder -Force
        }
        
        # Set default values for remaining fields
        if (-not $newProj.PSObject.Properties.Name.Contains("ClosedDate")) {
            $newProj | Add-Member -NotePropertyName "ClosedDate" -NotePropertyValue "" -Force
        }
        
        if (-not $newProj.PSObject.Properties.Name.Contains("Status")) {
            $defaultStatus = $config.DefaultProjectStatus -or "Active"
            $newProj | Add-Member -NotePropertyName "Status" -NotePropertyValue $defaultStatus -Force
        }
        
        if (-not $newProj.PSObject.Properties.Name.Contains("CumulativeHrs")) {
            $newProj | Add-Member -NotePropertyName "CumulativeHrs" -NotePropertyValue "0.0" -Force
        }
        
        # Get existing projects
        $projects = @(Get-EntityData -FilePath $ProjectsFilePath -RequiredHeaders $PROJECTS_HEADERS)
        
        # Add the new project
        $updatedProjects = $projects + $newProj
        
        # Save projects
        if (Save-EntityData -Data $updatedProjects -FilePath $ProjectsFilePath -RequiredHeaders $PROJECTS_HEADERS) {
            Write-ColorText "Project '$($newProj.Nickname)' created successfully!" -ForegroundColor (Get-CurrentTheme).Colors.Success
            
            # Add initial todo using internal format for DueDate
            $todoDescription = if ([string]::IsNullOrWhiteSpace($newProj.Note)) {
                "Initial setup/follow up for $($newProj.Nickname)"
            } else {
                "Follow up: $($newProj.Note)"
            }
            
            # Create todo item
            Add-TodoItem -Nickname $newProj.Nickname -TaskDescription $todoDescription -DueDate $newProj.BFDate -Importance "Normal"
            
            # Log success
            Write-AppLog "Created new project: $($newProj.Nickname)" -Level INFO
            
            Read-Host "Press Enter to continue..."
            return $newProj
        } else {
            Write-ColorText "Failed to save new project." -ForegroundColor (Get-CurrentTheme).Colors.Error
            Read-Host "Press Enter to continue..."
            return $null
        }
    } catch {
        Handle-Error -ErrorRecord $_ -Context "Creating new project" -Continue
        return $null
    }
}

<#
.SYNOPSIS
    Adds a todo item for a project.
.DESCRIPTION
    Creates a new todo item associated with a project.
.PARAMETER Nickname
    The project nickname.
.PARAMETER TaskDescription
    The description of the task.
.PARAMETER DueDate
    The due date for the task (YYYYMMDD format).
.PARAMETER Importance
    The importance level (High, Normal, Low).
.EXAMPLE
    Add-TodoItem -Nickname "WEBSITE" -TaskDescription "Update homepage" -DueDate "20240415" -Importance "High"
.OUTPUTS
    PSObject representing the created todo item, or $null if creation failed
#>
function Add-TodoItem {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Nickname,
        
        [Parameter(Mandatory=$true)]
        [string]$TaskDescription,
        
        [Parameter(Mandatory=$true)]
        [string]$DueDate,
        
        [Parameter(Mandatory=$false)]
        [ValidateSet("High", "Normal", "Low")]
        [string]$Importance = "Normal"
    )
    
    try {
        $config = Get-AppConfig
        $TodosFilePath = $config.TodosFullPath
        
        # Get existing todos
        $todos = @(Get-EntityData -FilePath $TodosFilePath -RequiredHeaders $TODO_HEADERS)
        
        # Create new todo
        $newTodo = [PSCustomObject]@{
            ID = New-ID
            Nickname = $Nickname
            TaskDescription = $TaskDescription
            Importance = $Importance
            DueDate = $DueDate
            Status = "Pending"
            CreatedDate = (Get-Date).ToString("yyyyMMdd")
            CompletedDate = ""
        }
        
        # Add the new todo
        $updatedTodos = $todos + $newTodo
        
        # Save todos
        if (Save-EntityData -Data $updatedTodos -FilePath $TodosFilePath -RequiredHeaders $TODO_HEADERS) {
            Write-Verbose "Todo item created for project '$Nickname'"
            Write-AppLog "Created todo item for project '$Nickname'" -Level INFO
            return $newTodo
        } else {
            Write-Verbose "Failed to save todo item for project '$Nickname'"
            return $null
        }
    } catch {
        Handle-Error -ErrorRecord $_ -Context "Creating todo item" -Continue
        return $null
    }
}

<#
.SYNOPSIS
    Updates a project's details with numeric navigation.
.DESCRIPTION
    Updates an existing project with new values.
    Takes input from the user for each field using numeric options.
.PARAMETER Nickname
    The nickname of the project to update.
.PARAMETER ProjectData
    Optional hashtable containing updated project data fields.
.EXAMPLE
    Update-TrackerProject -Nickname "WEBSITE"
#>
function Update-TrackerProject {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Nickname,
        
        [Parameter(Mandatory=$false)]
        [hashtable]$ProjectData = $null
    )
    
    Write-AppLog "Updating project: $Nickname" -Level INFO
    Render-Header "Update Project Details"
    
    try {
        $config = Get-AppConfig
        $ProjectsFilePath = $config.ProjectsFullPath
        
        # Get existing projects
        $projects = @(Get-EntityData -FilePath $ProjectsFilePath -RequiredHeaders $PROJECTS_HEADERS)
        $originalProject = $projects | Where-Object { $_.Nickname -eq $Nickname } | Select-Object -First 1
        
        if (-not $originalProject) {
            Write-ColorText "Error: Project '$Nickname' not found." -ForegroundColor (Get-CurrentTheme).Colors.Error
            Read-Host "Press Enter to continue..."
            return $null
        }
        
        # Create a copy of the original project to update
        $updatedProj = $originalProject.PSObject.Copy()
        
        # If project data is provided, update fields from it
        if ($ProjectData -and $ProjectData.Count -gt 0) {
            foreach ($key in $ProjectData.Keys) {
                if ($key -eq "Nickname") {
                    # Skip nickname as it's the identifier
                    continue
                }
                
                # Update property if it exists
                if ($updatedProj.PSObject.Properties.Name -contains $key) {
                    $updatedProj.$key = $ProjectData[$key]
                } else {
                    # Add the property if it doesn't exist
                    $updatedProj | Add-Member -NotePropertyName $key -NotePropertyValue $ProjectData[$key] -Force
                }
            }
        } else {
            # Interactive update - prompt for each field with numeric menu
            Write-ColorText "Updating Project: $($updatedProj.Nickname)" -ForegroundColor (Get-CurrentTheme).Colors.Accent2
            Write-ColorText "For each field: enter new value or 0 to cancel, press Enter to keep current value." -ForegroundColor (Get-CurrentTheme).Colors.Accent2
            
            # Full Project Name
            $newFullName = Read-UserInput -Prompt "Full Project Name (current: $($updatedProj.FullProjectName))"
            if ($newFullName -eq "CANCEL") { 
                Write-ColorText "Update cancelled." -ForegroundColor (Get-CurrentTheme).Colors.Warning
                Read-Host "Press Enter to continue..."
                return $null 
            }
            if (-not [string]::IsNullOrWhiteSpace($newFullName) -and $newFullName -ne $updatedProj.FullProjectName) {
                $updatedProj.FullProjectName = $newFullName
            }
            
            # ID1
            $newID1 = Read-UserInput -Prompt "ID1 (current: $($updatedProj.ID1))"
            if ($newID1 -eq "CANCEL") { 
                Write-ColorText "Update cancelled." -ForegroundColor (Get-CurrentTheme).Colors.Warning
                Read-Host "Press Enter to continue..."
                return $null 
            }
            if ($newID1 -ne $updatedProj.ID1) {
                $updatedProj.ID1 = $newID1
            }
            
            # ID2
            $newID2 = Read-UserInput -Prompt "ID2 (current: $($updatedProj.ID2))"
            if ($newID2 -eq "CANCEL") { 
                Write-ColorText "Update cancelled." -ForegroundColor (Get-CurrentTheme).Colors.Warning
                Read-Host "Press Enter to continue..."
                return $null 
            }
            if ($newID2 -ne $updatedProj.ID2) {
                $updatedProj.ID2 = $newID2
            }
            
            # Date Assigned
            $currentAssigned = Convert-InternalDateToDisplay -InternalDate $updatedProj.DateAssigned
            Write-ColorText "Current Assigned Date: $currentAssigned" -ForegroundColor (Get-CurrentTheme).Colors.Normal
            $updateAssigned = Read-UserInput -Prompt "Update Assigned Date? (1=Yes, 0=No)" -NumericOnly
            if ($updateAssigned -eq "CANCEL" -or $updateAssigned -eq "0") {
                # Skip updating this field
            } else {
                $newAssignedDate = Get-DateInput -PromptText "Enter new Assigned Date" -AllowCancel
                if ($null -eq $newAssignedDate) {
                    Write-ColorText "Date update cancelled." -ForegroundColor (Get-CurrentTheme).Colors.Warning
                } else {
                    $updatedProj.DateAssigned = $newAssignedDate
                }
            }
            
            # Due Date
            $currentDue = Convert-InternalDateToDisplay -InternalDate $updatedProj.DueDate
            Write-ColorText "Current Due Date: $currentDue" -ForegroundColor (Get-CurrentTheme).Colors.Normal
            $updateDue = Read-UserInput -Prompt "Update Due Date? (1=Yes, 0=No)" -NumericOnly
            if ($updateDue -eq "CANCEL" -or $updateDue -eq "0") {
                # Skip updating this field
            } else {
                $newDueDate = Get-DateInput -PromptText "Enter new Due Date" -AllowCancel
                if ($null -eq $newDueDate) {
                    Write-ColorText "Date update cancelled." -ForegroundColor (Get-CurrentTheme).Colors.Warning
                } else {
                    $updatedProj.DueDate = $newDueDate
                }
            }
            
            # BF Date
            $currentBF = Convert-InternalDateToDisplay -InternalDate $updatedProj.BFDate
            Write-ColorText "Current BF Date: $currentBF" -ForegroundColor (Get-CurrentTheme).Colors.Normal
            $updateBF = Read-UserInput -Prompt "Update BF Date? (1=Yes, 0=No)" -NumericOnly
            if ($updateBF -eq "CANCEL" -or $updateBF -eq "0") {
                # Skip updating this field
            } else {
                $newBFDate = Get-DateInput -PromptText "Enter new BF Date" -AllowCancel
                if ($null -eq $newBFDate) {
                    Write-ColorText "Date update cancelled." -ForegroundColor (Get-CurrentTheme).Colors.Warning
                } else {
                    $updatedProj.BFDate = $newBFDate
                }
            }
            
            # Note
            $newNote = Read-UserInput -Prompt "Note (current: $($updatedProj.Note))"
            if ($newNote -eq "CANCEL") { 
                Write-ColorText "Update cancelled." -ForegroundColor (Get-CurrentTheme).Colors.Warning
                Read-Host "Press Enter to continue..."
                return $null 
            }
            if ($newNote -ne $updatedProj.Note) {
                $updatedProj.Note = $newNote
            }
            
            # Project Folder
            $newProjFolder = Read-UserInput -Prompt "Project Folder (current: $($updatedProj.ProjFolder))"
            if ($newProjFolder -eq "CANCEL") { 
                Write-ColorText "Update cancelled." -ForegroundColor (Get-CurrentTheme).Colors.Warning
                Read-Host "Press Enter to continue..."
                return $null 
            }
            if ($newProjFolder -ne $updatedProj.ProjFolder) {
                $updatedProj.ProjFolder = $newProjFolder
            }
            
            # Status with numeric menu
            $currentStatus = if ([string]::IsNullOrWhiteSpace($updatedProj.Status)) { "Active" } else { $updatedProj.Status }
            Write-ColorText "Current Status: $currentStatus" -ForegroundColor (Get-CurrentTheme).Colors.Accent2
            Write-ColorText "[1] Active" -ForegroundColor (Get-CurrentTheme).Colors.Success
            Write-ColorText "[2] Closed" -ForegroundColor (Get-CurrentTheme).Colors.Completed
            Write-ColorText "[3] On Hold" -ForegroundColor (Get-CurrentTheme).Colors.Warning
            Write-ColorText "[0] Keep Current" -ForegroundColor (Get-CurrentTheme).Colors.Accent2
            
            $statusChoice = Read-UserInput -Prompt "Select new status" -NumericOnly
            
            if ($statusChoice -eq "CANCEL") {
                Write-ColorText "Update cancelled." -ForegroundColor (Get-CurrentTheme).Colors.Warning
                Read-Host "Press Enter to continue..."
                return $null
            }
            
            switch($statusChoice) {
                '1' { $updatedProj.Status = "Active" }
                '2' { $updatedProj.Status = "Closed" }
                '3' { $updatedProj.Status = "On Hold" }
                '0' {} '' {} default {
                    Write-ColorText "Invalid status choice. Keeping original." -ForegroundColor (Get-CurrentTheme).Colors.Warning
                }
            }
        }
        
        # Update ClosedDate based on Status
        if ($updatedProj.Status -eq "Closed" -and [string]::IsNullOrWhiteSpace($updatedProj.ClosedDate)) {
            $updatedProj.ClosedDate = (Get-Date).ToString("yyyyMMdd") # Store internal format
        } elseif ($updatedProj.Status -ne "Closed") {
            $updatedProj.ClosedDate = ""
        }
        
        # Update the project in the array
        $updatedProjects = @()
        foreach ($proj in $projects) {
            if ($proj.Nickname -eq $Nickname) {
                $updatedProjects += $updatedProj
            } else {
                $updatedProjects += $proj
            }
        }
        
        # Save projects
        if (Save-EntityData -Data $updatedProjects -FilePath $ProjectsFilePath -RequiredHeaders $PROJECTS_HEADERS) {
            Write-ColorText "Project '$($updatedProj.Nickname)' updated successfully!" -ForegroundColor (Get-CurrentTheme).Colors.Success
            
            # Update related todo if BFDate or Note changed
            if (($updatedProj.BFDate -ne $originalProject.BFDate) -or ($updatedProj.Note -ne $originalProject.Note)) {
                Update-TodoForProject -Nickname $updatedProj.Nickname -NewBFDate $updatedProj.BFDate -NewNote $updatedProj.Note
            }
            
            # Log success
            Write-AppLog "Updated project: $($updatedProj.Nickname)" -Level INFO
            
            Read-Host "Press Enter to continue..."
            return $updatedProj
        } else {
            Write-ColorText "Failed to save updated project." -ForegroundColor (Get-CurrentTheme).Colors.Error
            Read-Host "Press Enter to continue..."
            return $null
        }
    } catch {
        Handle-Error -ErrorRecord $_ -Context "Updating project" -Continue
        return $null
    }
}


##More Missing stuff
# 1. For Date Functions region - add this function:

<#
.SYNOPSIS
    Gets the full month name for a month number.
.DESCRIPTION
    Returns the full name of the month for the specified month number (1-12).
.PARAMETER Month
    The month number (1-12).
.EXAMPLE
    $monthName = Get-MonthName -Month 9
.OUTPUTS
    System.String - The full month name
#>
function Get-MonthName {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateRange(1, 12)]
        [int]$Month
    )
    
    # Get the month name from the current culture
    return (Get-Culture).DateTimeFormat.GetMonthName($Month)
}


# 2. For Helper Functions region - add these functions:

<#
.SYNOPSIS
    Shows a simple confirmation dialog.
.DESCRIPTION
    Displays a confirmation dialog with the specified message and returns the user's response.
.PARAMETER Message
    The message to display.
.PARAMETER Title
    The title of the dialog.
.PARAMETER DefaultYes
    If specified, defaults to "Yes" when the user presses Enter.
.EXAMPLE
    if (Show-Confirmation -Message "Are you sure you want to delete this file?" -Title "Confirm Delete") {
        # Deletion code here
    }
.OUTPUTS
    System.Boolean - True if the user confirmed, False otherwise
#>
function Show-Confirmation {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message,
        
        [Parameter(Mandatory=$false)]
        [string]$Title = "Confirm",
        
        [Parameter(Mandatory=$false)]
        [switch]$DefaultYes
    )
    
    # Use info box if available
    if ($script:currentTheme) {
        # Display message with the theme engine
        Show-InfoBox -Title $Title -Message "$Message`n`nEnter Y for Yes, N for No." -Type Warning
    } else {
        # Fall back to simple console output
        Write-Host "`n-- $Title --" -ForegroundColor Yellow
        Write-Host $Message -ForegroundColor White
        Write-Host "------------" -ForegroundColor Yellow
    }
    
    # Get default option display
    $defaultOption = if ($DefaultYes) { "(Y/n)" } else { "(y/N)" }
    
    # Ask for confirmation
    Write-Host "Confirm $defaultOption? " -ForegroundColor Cyan -NoNewline
    $response = Read-Host
    
    # Handle empty response
    if ([string]::IsNullOrWhiteSpace($response)) {
        return $DefaultYes
    }
    
    # Return based on response
    return $response -match '^[yY]'
}

<#
.SYNOPSIS
    Gets the value of an environment variable with a default.
.DESCRIPTION
    Returns the value of the specified environment variable, or a default if not set.
.PARAMETER Name
    The name of the environment variable.
.PARAMETER DefaultValue
    The default value to return if the variable is not set.
.EXAMPLE
    $logLevel = Get-EnvironmentVariable -Name "APP_LOG_LEVEL" -DefaultValue "INFO"
.OUTPUTS
    System.String - The environment variable value or default
#>
function Get-EnvironmentVariable {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Name,
        
        [Parameter(Mandatory=$false)]
        [string]$DefaultValue = ""
    )
    
    $value = [Environment]::GetEnvironmentVariable($Name)
    
    if ([string]::IsNullOrEmpty($value)) {
        return $DefaultValue
    }
    
    return $value
}

<#
.SYNOPSIS
    Joins paths safely, handling errors.
.DESCRIPTION
    Joins path components safely, handling edge cases and errors.
.PARAMETER Path
    The base path.
.PARAMETER ChildPath
    The child path to append.
.EXAMPLE
    $fullPath = Join-PathSafely -Path $baseDir -ChildPath "data/file.txt"
.OUTPUTS
    System.String - The combined path
#>
function Join-PathSafely {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Path,
        
        [Parameter(Mandatory=$true)]
        [string]$ChildPath
    )
    
    # Handle edge cases
    if ([string]::IsNullOrEmpty($Path)) {
        return $ChildPath
    }
    
    if ([string]::IsNullOrEmpty($ChildPath)) {
        return $Path
    }
    
    try {
        # Use .NET Path class for reliable path joining
        return [System.IO.Path]::Combine($Path, $ChildPath)
    } catch {
        Write-Warning "Error joining paths: $Path and $ChildPath - $($_.Exception.Message)"
        # Fall back to manual joining
        if ($Path.EndsWith([System.IO.Path]::DirectorySeparatorChar) -or 
            $Path.EndsWith([System.IO.Path]::AltDirectorySeparatorChar)) {
            return "$Path$ChildPath"
        } else {
            return "$Path$([System.IO.Path]::DirectorySeparatorChar)$ChildPath"
        }
    }
}

<#
.SYNOPSIS
    Gets a unique filename in a directory.
.DESCRIPTION
    Generates a unique filename in the specified directory by appending a number if needed.
.PARAMETER Directory
    The directory to check for existing files.
.PARAMETER FileName
    The base filename to use.
.PARAMETER Extension
    The file extension (without the dot).
.EXAMPLE
    $uniqueName = Get-UniqueFileName -Directory "C:\Temp" -FileName "Report" -Extension "txt"
.OUTPUTS
    System.String - The unique filename (without path)
#>
function Get-UniqueFileName {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Directory,
        
        [Parameter(Mandatory=$true)]
        [string]$FileName,
        
        [Parameter(Mandatory=$true)]
        [string]$Extension
    )
    
    # Ensure extension doesn't start with a dot
    if ($Extension.StartsWith(".")) {
        $Extension = $Extension.Substring(1)
    }
    
    # Check if the initial filename exists
    $baseFileName = "$FileName.$Extension"
    $fullPath = Join-Path -Path $Directory -ChildPath $baseFileName
    
    if (-not (Test-Path -Path $fullPath)) {
        return $baseFileName
    }
    
    # Find a unique name by appending numbers
    $counter = 1
    do {
        $newFileName = "$FileName($counter).$Extension"
        $fullPath = Join-Path -Path $Directory -ChildPath $newFileName
        $counter++
    } while (Test-Path -Path $fullPath)
    
    return $newFileName
}

<#
.SYNOPSIS
    Converts a string to a valid filename.
.DESCRIPTION
    Replaces invalid characters in a string to make it a valid filename.
.PARAMETER InputString
    The string to convert.
.PARAMETER ReplacementChar
    The character to use for replacement. Default is '_'.
.EXAMPLE
    $fileName = ConvertTo-ValidFileName -InputString "Project: 2023/04"
.OUTPUTS
    System.String - The sanitized filename
#>
function ConvertTo-ValidFileName {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$InputString,
        
        [Parameter(Mandatory=$false)]
        [char]$ReplacementChar = '_'
    )
    
    # Get invalid characters from .NET
    $invalidChars = [System.IO.Path]::GetInvalidFileNameChars()
    
    # Replace each invalid character
    $result = $InputString
    foreach ($char in $invalidChars) {
        if ($result.Contains($char)) {
            $result = $result.Replace($char, $ReplacementChar)
        }
    }
    
    return $result
}

<#
.SYNOPSIS
    Gets a temp file path.
.DESCRIPTION
    Creates a temporary file and returns its path.
.PARAMETER Prefix
    Optional prefix for the filename.
.PARAMETER Extension
    The file extension (without the dot).
.PARAMETER CreateFile
    If specified, creates an empty file at the path.
.EXAMPLE
    $tempFile = Get-TempFilePath -Prefix "export" -Extension "csv" -CreateFile
.OUTPUTS
    System.String - The path to the temporary file
#>
function Get-TempFilePath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)]
        [string]$Prefix = "",
        
        [Parameter(Mandatory=$false)]
        [string]$Extension = "tmp",
        
        [Parameter(Mandatory=$false)]
        [switch]$CreateFile
    )
    
    # Ensure extension doesn't start with a dot
    if ($Extension.StartsWith(".")) {
        $Extension = $Extension.Substring(1)
    }
    
    # Generate a unique filename in the temp directory
    $tempDir = [System.IO.Path]::GetTempPath()
    $fileName = if ([string]::IsNullOrEmpty($Prefix)) {
        [System.Guid]::NewGuid().ToString("N")
    } else {
        "$Prefix-$([System.Guid]::NewGuid().ToString("N"))"
    }
    
    $filePath = Join-Path -Path $tempDir -ChildPath "$fileName.$Extension"
    
    # Create the file if requested
    if ($CreateFile) {
        try {
            [System.IO.File]::Create($filePath).Close()
        } catch {
            Write-Warning "Failed to create temp file: $($_.Exception.Message)"
        }
    }
    
    return $filePath
}

<#
.SYNOPSIS
    Generates a random password.
.DESCRIPTION
    Creates a random password with configurable complexity.
.PARAMETER Length
    The length of the password.
.PARAMETER IncludeSpecialChars
    If specified, includes special characters.
.PARAMETER IncludeNumbers
    If specified, includes numeric characters.
.PARAMETER IncludeUppercase
    If specified, includes uppercase letters.
.PARAMETER IncludeLowercase
    If specified, includes lowercase letters.
.EXAMPLE
    $password = New-RandomPassword -Length 12 -IncludeSpecialChars -IncludeNumbers
.OUTPUTS
    System.String - The generated password
#>
function New-RandomPassword {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)]
        [int]$Length = 12,
        
        [Parameter(Mandatory=$false)]
        [switch]$IncludeSpecialChars,
        
        [Parameter(Mandatory=$false)]
        [switch]$IncludeNumbers = $true,
        
        [Parameter(Mandatory=$false)]
        [switch]$IncludeUppercase = $true,
        
        [Parameter(Mandatory=$false)]
        [switch]$IncludeLowercase = $true
    )
    
    # Define character sets
    $lowercase = "abcdefghijklmnopqrstuvwxyz"
    $uppercase = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    $numbers = "0123456789"
    $special = "!@#$%^&*()_-+={}[]|:;<>,.?/~"
    
    # Combine selected character sets
    $charSet = ""
    if ($IncludeLowercase) { $charSet += $lowercase }
    if ($IncludeUppercase) { $charSet += $uppercase }
    if ($IncludeNumbers) { $charSet += $numbers }
    if ($IncludeSpecialChars) { $charSet += $special }
    
    # Ensure at least one character set is selected
    if ([string]::IsNullOrEmpty($charSet)) {
        $charSet = $lowercase
    }
    
    # Generate password
    $random = New-Object System.Random
    $password = ""
    
    for ($i = 0; $i -lt $Length; $i++) {
        $password += $charSet[$random.Next(0, $charSet.Length)]
    }
    
    return $password
}

<#
.SYNOPSIS
    Converts bytes to a human-readable size.
.DESCRIPTION
    Converts a byte count to a human-readable size (KB, MB, GB, etc.).
.PARAMETER Bytes
    The number of bytes.
.PARAMETER Precision
    The number of decimal places to include.
.EXAMPLE
    $size = Convert-BytesToHumanReadable -Bytes 1536000
.OUTPUTS
    System.String - The formatted size
#>
function Convert-BytesToHumanReadable {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [long]$Bytes,
        
        [Parameter(Mandatory=$false)]
        [int]$Precision = 2
    )
    
    $sizes = @("B", "KB", "MB", "GB", "TB", "PB")
    $order = 0
    
    while ($Bytes -ge 1024 -and $order -lt $sizes.Count - 1) {
        $Bytes /= 1024
        $order++
    }
    
    return "{0:N$Precision} {1}" -f $Bytes, $sizes[$order]
}

<#
.SYNOPSIS
    Gets the position of the substring in a string, ignoring case.
.DESCRIPTION
    Returns the position of the substring in a string, with case-insensitive comparison.
.PARAMETER String
    The string to search in.
.PARAMETER SubString
    The substring to find.
.PARAMETER StartIndex
    The starting position of the search.
.EXAMPLE
    $pos = Find-SubstringPosition -String "Hello World" -SubString "world"
.OUTPUTS
    System.Int32 - The position of the substring, or -1 if not found
#>
function Find-SubstringPosition {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$String,
        
        [Parameter(Mandatory=$true)]
        [string]$SubString,
        
        [Parameter(Mandatory=$false)]
        [int]$StartIndex = 0
    )
    
    if ([string]::IsNullOrEmpty($String) -or [string]::IsNullOrEmpty($SubString)) {
        return -1
    }
    
    return $String.ToLower().IndexOf($SubString.ToLower(), $StartIndex)
}

<#
.SYNOPSIS
    Slugifies a string for use in URLs or filenames.
.DESCRIPTION
    Converts a string to a URL-friendly slug.
.PARAMETER Text
    The text to slugify.
.PARAMETER Separator
    The separator character to use. Default is '-'.
.EXAMPLE
    $slug = Convert-ToSlug -Text "Hello World! This is a test."
.OUTPUTS
    System.String - The slugified string
#>
function Convert-ToSlug {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Text,
        
        [Parameter(Mandatory=$false)]
        [string]$Separator = "-"
    )
    
    # Convert to lowercase
    $result = $Text.ToLower()
    
    # Remove accents/diacritics
    $normalizedString = $result.Normalize([System.Text.NormalizationForm]::FormD)
    $stringBuilder = New-Object System.Text.StringBuilder
    
    foreach ($char in $normalizedString.ToCharArray()) {
        $unicodeCategory = [System.Globalization.CharUnicodeInfo]::GetUnicodeCategory($char)
        if ($unicodeCategory -ne [System.Globalization.UnicodeCategory]::NonSpacingMark) {
            [void]$stringBuilder.Append($char)
        }
    }
    
    $result = $stringBuilder.ToString().Normalize([System.Text.NormalizationForm]::FormC)
    
    # Replace spaces with the separator
    $result = $result -replace '\s+', $Separator
    
    # Remove invalid characters
    $result = $result -replace '[^a-z0-9\-_]', ''
    
    # Remove multiple consecutive separators
    $result = $result -replace "$Separator{2,}", $Separator
    
    # Remove separator from beginning and end
    $result = $result.Trim($Separator)
    
    return $result
}

# 3. Add Show-InfoBox function to Display Functions region (since it's at the top of the file)
# First remove it from the beginning of the file, then add it to the appropriate region
##end of that missing stuff



<#
.SYNOPSIS
    Updates todo items related to a project.
.DESCRIPTION
    Updates todo items related to a project when project details change.
.PARAMETER Nickname
    The project nickname.
.PARAMETER NewBFDate
    The new BF date for todos.
.PARAMETER NewNote
    The new note for todos.
.EXAMPLE
    Update-TodoForProject -Nickname "WEBSITE" -NewBFDate "20240430" -NewNote "Updated follow-up note"
.OUTPUTS
    None
#>
function Update-TodoForProject {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Nickname,
        
        [Parameter(Mandatory=$false)]
        [string]$NewBFDate,
        
        [Parameter(Mandatory=$false)]
        [string]$NewNote
    )
    
    if ([string]::IsNullOrWhiteSpace($Nickname)) {
        return
    }
    
    try {
        $config = Get-AppConfig
        $TodosFilePath = $config.TodosFullPath
        
        # Get existing todos
        $todos = @(Get-EntityData -FilePath $TodosFilePath -RequiredHeaders $TODO_HEADERS)
        $updated = $false
        
        foreach ($todo in $todos) {
            if ($todo.Nickname -eq $Nickname -and 
                ($todo.TaskDescription -like "*follow up*" -or $todo.TaskDescription -match "Initial setup/follow up")) {
                
                # Update due date if provided and different
                if (-not [string]::IsNullOrWhiteSpace($NewBFDate) -and $todo.DueDate -ne $NewBFDate) {
                    $todo.DueDate = $NewBFDate
                    $updated = $true
                    Write-Verbose "Updated due date for todo in project '$Nickname'"
                }
                
                # Update description if note provided
                if (-not [string]::IsNullOrWhiteSpace($NewNote)) {
                    $newDesc = "Follow up: $NewNote"
                    if ($todo.TaskDescription -ne $newDesc) {
                        $todo.TaskDescription = $newDesc
                        $updated = $true
                        Write-Verbose "Updated description for todo in project '$Nickname'"
                    }
                }
            }
        }
        
        # Save todos if updated
        if ($updated) {
            if (Save-EntityData -Data $todos -FilePath $TodosFilePath -RequiredHeaders $TODO_HEADERS) {
                Write-AppLog "Updated related todo items for project '$Nickname'" -Level INFO
            } else {
                Write-Verbose "Failed to save updated todo items for project '$Nickname'"
            }
        }
    } catch {
        Handle-Error -ErrorRecord $_ -Context "Updating project todo items" -Continue
    }
}

<#
.SYNOPSIS
    Deletes a project with numeric confirmation.
.DESCRIPTION
    Deletes a project and its related todo items with numeric confirmation.
.PARAMETER Nickname
    The nickname of the project to delete.
.EXAMPLE
    Remove-TrackerProject -Nickname "WEBSITE"
#>
function Remove-TrackerProject {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Nickname
    )

    Write-AppLog "Deleting project: $Nickname" -Level INFO
    Render-Header "Delete Project"

    try {
        $config = Get-AppConfig
        $ProjectsFilePath = $config.ProjectsFullPath
        $TodosFilePath = $config.TodosFullPath
        $colors = (Get-CurrentTheme).Colors

        # Get projects and find the one to delete
        $projects = @(Get-EntityData -FilePath $ProjectsFilePath -RequiredHeaders $PROJECTS_HEADERS)
        $projectToDelete = $projects | Where-Object { $_.Nickname -eq $Nickname } | Select-Object -First 1

        if (-not $projectToDelete) {
            Write-ColorText "Error: Project '$Nickname' not found." -ForegroundColor $colors.Error
            Read-Host "Press Enter to continue..."
            return $false
        }

        # Confirm deletion with numeric input
        Write-ColorText "WARNING: This will permanently delete project '$Nickname' and ALL associated todo items." -ForegroundColor $colors.Error
        Write-ColorText "Project Details:" -ForegroundColor $colors.Warning
        Write-ColorText "  Name: $($projectToDelete.FullProjectName)" -ForegroundColor $colors.Normal
        Write-ColorText "  Status: $($projectToDelete.Status)" -ForegroundColor $colors.Normal

        $confirm = Confirm-Action -ActionDescription "Are you sure you want to delete this project?"

        if (-not $confirm) {
            Write-ColorText "Deletion cancelled." -ForegroundColor $colors.Warning
            Read-Host "Press Enter to continue..."
            return $false
        }

        # Filter out the project to be deleted
        $updatedProjects = $projects | Where-Object { $_.Nickname -ne $Nickname }

        # Get and filter todos associated with the project
        $todos = @(Get-EntityData -FilePath $TodosFilePath -RequiredHeaders $TODO_HEADERS)
        $updatedTodos = $todos | Where-Object { $_.Nickname -ne $Nickname }
        $removedTodoCount = $todos.Count - $updatedTodos.Count

        # Save updated projects
        if (-not (Save-EntityData -Data $updatedProjects -FilePath $ProjectsFilePath -RequiredHeaders $PROJECTS_HEADERS)) {
            Write-ColorText "Error saving updated project list after deletion." -ForegroundColor $colors.Error
            # Attempt to continue to remove todos anyway, but log the error
            Write-AppLog "Error saving project list after deleting $Nickname" -Level ERROR
        }

        # Save updated todos (even if project save failed, try to clean up)
        if (Save-EntityData -Data $updatedTodos -FilePath $TodosFilePath -RequiredHeaders $TODO_HEADERS) {
             Write-AppLog "Removed $removedTodoCount todo item(s) associated with project '$Nickname'." -Level INFO
        } else {
             Write-ColorText "Error saving updated todo list after deletion." -ForegroundColor $colors.Error
             Write-AppLog "Error saving todo list after deleting items for project $Nickname" -Level ERROR
             # If both saves failed, report a more significant failure
             if ($updatedProjects.Count -eq $projects.Count) { # Check if project save also failed
                 Read-Host "Press Enter to continue..."
                 return $false
             }
        }

        Write-ColorText "Project '$Nickname' and associated todos deleted successfully!" -ForegroundColor $colors.Success
        Write-AppLog "Successfully deleted project '$Nickname' and $removedTodoCount associated todos." -Level INFO
        Read-Host "Press Enter to continue..."
        return $true

    } catch {
        Handle-Error -ErrorRecord $_ -Context "Deleting project '$Nickname'" -Continue
        Read-Host "Press Enter to continue..."
        return $false
    }
}
    # --- END OF MISSING/RECONSTRUCTED CODE ---


##Start of missing content
# Add this function to the ProjectTracker.Projects.psm1 file

<#
.SYNOPSIS
    Displays the project management menu with numeric options.
.DESCRIPTION
    Shows a menu with numeric options for managing projects.
.EXAMPLE
    Show-ProjectMenu
#>
# Exit Handling Principles
#
# 1. Menu Functions:
#    - Always return $null from Show-XxxMenu functions unless explicitly exiting the application
#    - Use IsExit = $true for menu items that exit a submenu, not the application
#
# 2. Return Values:
#    - Return $true ONLY when intending to exit the application completely
#    - Return $null to continue in the current menu context
#    - Return other explicit values only when they're expected and handled
#
# 3. Menu Items:
#    - Key "0" is always for "Back" or "Cancel" operations
#    - Keys "1-9" are for options
#
# 4. Confirmation:
#    - Always use 1 for Yes, 0 for No
#    - Use Confirm-Action for all confirmations

# Fix for Show-ProjectMenu (ProjectTracker.Projects.psm1)
function Show-ProjectMenu {
    [CmdletBinding()]
    param()
    
    $menuItems = @()
    
    $menuItems += @{
        Type = "header"
        Text = "Project Management"
    }
    
    # Project menu options
    $menuItems += @{
        Type = "option"
        Key = "1"
        Text = "List Active Projects"
        Function = {
            Show-ProjectList
            return $null
        }
    }
    
    $menuItems += @{
        Type = "option"
        Key = "2"
        Text = "List All Projects"
        Function = {
            Show-ProjectList -IncludeAll
            return $null
        }
    }
    
    $menuItems += @{
        Type = "option"
        Key = "3"
        Text = "Create New Project"
        Function = {
            New-TrackerProject
            return $null
        }
    }
    
    $menuItems += @{
        Type = "option"
        Key = "4"
        Text = "Update Project"
        Function = {
            # First, show the project list
            $projects = Show-ProjectList
            
            # If no projects, return
            if ($projects.Count -eq 0) {
                return $null
            }
            
            # Display numeric list for selection
            Write-Host "Select project to update by number (0 to cancel):" -ForegroundColor $script:colors.Accent2
            
            for ($i = 0; $i -lt $projects.Count; $i++) {
                $projNum = $i + 1
                Write-Host "[$projNum] $($projects[$i].Nickname) - $($projects[$i].FullProjectName)" -ForegroundColor $script:colors.Normal
            }
            
            $selection = Read-UserInput -Prompt "Enter project number" -NumericOnly
            
            if ($selection -eq "CANCEL" -or $selection -eq "0") {
                Write-ColorText "Update cancelled." -ForegroundColor $script:colors.Warning
                Read-Host "Press Enter to continue..."
                return $null
            }
            
            # Convert selection to int and check range
            try {
                $index = [int]$selection - 1
                if ($index -lt 0 -or $index -ge $projects.Count) {
                    Write-ColorText "Invalid selection." -ForegroundColor $script:colors.Error
                    Read-Host "Press Enter to continue..."
                    return $null
                }
                
                # Update the selected project
                Update-TrackerProject -Nickname $projects[$index].Nickname
            } catch {
                Write-ColorText "Invalid selection." -ForegroundColor $script:colors.Error
                Read-Host "Press Enter to continue..."
            }
            
            return $null
        }
    }
    
    $menuItems += @{
        Type = "option"
        Key = "5"
        Text = "Change Project Status"
        Function = {
            # First, show the project list
            $projects = Show-ProjectList
            
            # If no projects, return
            if ($projects.Count -eq 0) {
                return $null
            }
            
            # Display numeric list for selection
            Write-Host "Select project to change status by number (0 to cancel):" -ForegroundColor $script:colors.Accent2
            
            for ($i = 0; $i -lt $projects.Count; $i++) {
                $projNum = $i + 1
                Write-Host "[$projNum] $($projects[$i].Nickname) - $($projects[$i].FullProjectName) (Status: $($projects[$i].Status))" -ForegroundColor $script:colors.Normal
            }
            
            $selection = Read-UserInput -Prompt "Enter project number" -NumericOnly
            
            if ($selection -eq "CANCEL" -or $selection -eq "0") {
                Write-ColorText "Status change cancelled." -ForegroundColor $script:colors.Warning
                Read-Host "Press Enter to continue..."
                return $null
            }
            
            # Convert selection to int and check range
            try {
                $index = [int]$selection - 1
                if ($index -lt 0 -or $index -ge $projects.Count) {
                    Write-ColorText "Invalid selection." -ForegroundColor $script:colors.Error
                    Read-Host "Press Enter to continue..."
                    return $null
                }
                
                $projectNickname = $projects[$index].Nickname
                
                # Status selection menu
                $statusMenu = @()
                $statusMenu += @{ Type = "header"; Text = "Select New Status" }
                $statusMenu += @{ Type = "option"; Key = "1"; Text = "Active"; Function = { return "Active" } }
                $statusMenu += @{ Type = "option"; Key = "2"; Text = "On Hold"; Function = { return "On Hold" } }
                $statusMenu += @{ Type = "option"; Key = "3"; Text = "Closed"; Function = { return "Closed" } }
                $statusMenu += @{ Type = "separator" }
                $statusMenu += @{ Type = "option"; Key = "0"; Text = "Cancel"; Function = { return $null }; IsExit = $true }
                
                $newStatus = Show-DynamicMenu -Title "Select New Status" -MenuItems $statusMenu
                
                if ($null -eq $newStatus) {
                    Write-ColorText "Status change cancelled." -ForegroundColor $script:colors.Warning
                    Read-Host "Press Enter to continue..."
                    return $null
                }
                
                # Change the project status
                Set-TrackerProjectStatus -Nickname $projectNickname -Status $newStatus
            } catch {
                Write-ColorText "Invalid selection." -ForegroundColor $script:colors.Error
                Read-Host "Press Enter to continue..."
            }
            
            return $null
        }
    }
    
    $menuItems += @{
        Type = "option"
        Key = "6"
        Text = "Delete Project"
        Function = {
            # First, show all projects
            $projects = Show-ProjectList -IncludeAll
            
            # If no projects, return
            if ($projects.Count -eq 0) {
                return $null
            }
            
            # Display numeric list for selection
            Write-Host "Select project to DELETE by number (0 to cancel):" -ForegroundColor $script:colors.Accent2
            
            for ($i = 0; $i -lt $projects.Count; $i++) {
                $projNum = $i + 1
                Write-Host "[$projNum] $($projects[$i].Nickname) - $($projects[$i].FullProjectName)" -ForegroundColor $script:colors.Normal
            }
            
            $selection = Read-UserInput -Prompt "Enter project number" -NumericOnly
            
            if ($selection -eq "CANCEL" -or $selection -eq "0") {
                Write-ColorText "Deletion cancelled." -ForegroundColor $script:colors.Warning
                Read-Host "Press Enter to continue..."
                return $null
            }
            
            # Convert selection to int and check range
            try {
                $index = [int]$selection - 1
                if ($index -lt 0 -or $index -ge $projects.Count) {
                    Write-ColorText "Invalid selection." -ForegroundColor $script:colors.Error
                    Read-Host "Press Enter to continue..."
                    return $null
                }
                
                # Delete the selected project
                Remove-TrackerProject -Nickname $projects[$index].Nickname
            } catch {
                Write-ColorText "Invalid selection." -ForegroundColor $script:colors.Error
                Read-Host "Press Enter to continue..."
            }
            
            return $null
        }
    }
    
    $menuItems += @{
        Type = "option"
        Key = "7"
        Text = "Update Project Hours"
        Function = {
            # First, show active projects
            $projects = Show-ProjectList
            
            # If no projects, return
            if ($projects.Count -eq 0) {
                return $null
            }
            
            # Display numeric list for selection
            Write-Host "Select project to update hours by number (0 to cancel):" -ForegroundColor $script:colors.Accent2
            
            for ($i = 0; $i -lt $projects.Count; $i++) {
                $projNum = $i + 1
                Write-Host "[$projNum] $($projects[$i].Nickname) - $($projects[$i].FullProjectName) (Current: $($projects[$i].CumulativeHrs) hrs)" -ForegroundColor $script:colors.Normal
            }
            
            $selection = Read-UserInput -Prompt "Enter project number" -NumericOnly
            
            if ($selection -eq "CANCEL" -or $selection -eq "0") {
                Write-ColorText "Update cancelled." -ForegroundColor $script:colors.Warning
                Read-Host "Press Enter to continue..."
                return $null
            }
            
            # Convert selection to int and check range
            try {
                $index = [int]$selection - 1
                if ($index -lt 0 -or $index -ge $projects.Count) {
                    Write-ColorText "Invalid selection." -ForegroundColor $script:colors.Error
                    Read-Host "Press Enter to continue..."
                    return $null
                }
                
                # Update hours for the selected project
                Update-TrackerProjectHours -Nickname $projects[$index].Nickname
                Read-Host "Press Enter to continue..."
            } catch {
                Write-ColorText "Invalid selection." -ForegroundColor $script:colors.Error
                Read-Host "Press Enter to continue..."
            }
            
            return $null
        }
    }
    
    $menuItems += @{
        Type = "separator"
    }
    
    $menuItems += @{
        Type = "option"
        Key = "0"
        Text = "Back to Main Menu"
        Function = { 
            return $true # This exits the submenu, not the application
        }
        IsExit = $true
    }
    
    # Show menu but always return null to stay in the application
    $menuResult = Show-DynamicMenu -Title "Project Management" -MenuItems $menuItems
    return $null
}

# Fix for Show-TodoMenu (ProjectTracker.Todos.psm1)
#function Show-TodoMenu {
#    $todoMenuItems = @()
    
#    $todoMenuItems += @{
#        Key = "header_1"
#        Text = "Todo Management"
#        Type = "header"
#    }
    
    # Menu items 1-7...
    
#    $todoMenuItems += @{
#        Key = "sep_1"
#        Type = "separator"
#    }
    
#    $todoMenuItems += @{
#        Key = "0"
#        Text = "Back to Main Menu"
#        Function = { 
#            return $true # This exits the submenu, not the application
#        }
#        IsExit = $true
#        Type = "option"
#    }
    
    # Show menu but always return null
#    $menuResult = Show-DynamicMenu -Title "Todo Management" -MenuItems $todoMenuItems
#    return $null

# Add to ProjectTracker.Projects.psm1

<#
.SYNOPSIS
    Gets a project by its nickname.
.DESCRIPTION
    Retrieves a project object by its nickname identifier.
.PARAMETER Nickname
    The project nickname to find.
.EXAMPLE
    $project = Get-TrackerProject -Nickname "WEBSITE"
.OUTPUTS
    PSObject representing the project, or $null if not found
#>
function Get-TrackerProject {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Nickname
    )
    
    try {
        $config = Get-AppConfig
        $ProjectsFilePath = $config.ProjectsFullPath
        
        # Get existing projects
        $projects = @(Get-EntityData -FilePath $ProjectsFilePath -RequiredHeaders $PROJECTS_HEADERS)
        
        # Find the project by nickname
        $project = $projects | Where-Object { $_.Nickname -eq $Nickname } | Select-Object -First 1
        
        if (-not $project) {
            Write-Verbose "Project '$Nickname' not found."
            return $null
        }
        
        return $project
    } catch {
        Handle-Error -ErrorRecord $_ -Context "Getting project by nickname" -Continue
        return $null
    }
}

<#
.SYNOPSIS
    Changes a project's status with numeric selection.
.DESCRIPTION
    Updates the status of a project to Active, On Hold, or Closed using numeric input.
.PARAMETER Nickname
    The nickname of the project to update.
.PARAMETER Status
    The new status (Active, On Hold, Closed).
.EXAMPLE
    Set-TrackerProjectStatus -Nickname "WEBSITE" -Status "Closed"
#>
function Set-TrackerProjectStatus {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Nickname,
        
        [Parameter(Mandatory=$true)]
        [ValidateSet("Active", "On Hold", "Closed")]
        [string]$Status
    )
    
    Write-AppLog "Changing status for project '$Nickname' to '$Status'" -Level INFO
    Render-Header -Title "Change Project Status"
    
    try {
        $config = Get-AppConfig
        $ProjectsFilePath = $config.ProjectsFullPath
        
        # Get existing projects
        $projects = @(Get-EntityData -FilePath $ProjectsFilePath -RequiredHeaders $PROJECTS_HEADERS)
        $project = $projects | Where-Object { $_.Nickname -eq $Nickname } | Select-Object -First 1
        
        if (-not $project) {
            Write-ColorText "Error: Project '$Nickname' not found." -ForegroundColor (Get-CurrentTheme).Colors.Error
            Read-Host "Press Enter to continue..."
            return $false
        }
        
        # Update status and closed date if applicable
        $oldStatus = $project.Status
        $project.Status = $Status
        
        if ($Status -eq "Closed" -and (-not $project.ClosedDate -or [string]::IsNullOrWhiteSpace($project.ClosedDate))) {
            $project.ClosedDate = (Get-Date).ToString("yyyyMMdd")
            Write-Verbose "Set closed date to $($project.ClosedDate)"
        } elseif ($Status -ne "Closed") {
            $project.ClosedDate = ""
        }
        
        # Get numeric confirmation if changing to Closed
        if ($Status -eq "Closed" -and $oldStatus -ne "Closed") {
            if (-not (Confirm-Action -ActionDescription "Are you sure you want to mark this project as Closed?")) {
                Write-ColorText "Status change cancelled." -ForegroundColor (Get-CurrentTheme).Colors.Warning
                Read-Host "Press Enter to continue..."
                return $false
            }
        }
        
        # Save projects
        if (Save-EntityData -Data $projects -FilePath $ProjectsFilePath -RequiredHeaders $PROJECTS_HEADERS) {
            Write-ColorText "Project status changed from '$oldStatus' to '$Status' successfully!" -ForegroundColor (Get-CurrentTheme).Colors.Success
            
            # Log success
            Write-AppLog "Updated project status: $Nickname from '$oldStatus' to '$Status'" -Level INFO
            
            Read-Host "Press Enter to continue..."
            return $true
        } else {
            Write-ColorText "Failed to save project status change." -ForegroundColor (Get-CurrentTheme).Colors.Error
            Read-Host "Press Enter to continue..."
            return $false
        }
    } catch {
        Handle-Error -ErrorRecord $_ -Context "Changing project status" -Continue
        return $false
    }
}

<#
.SYNOPSIS
    Updates a project's cumulative hours.
.DESCRIPTION
    Recalculates a project's cumulative hours based on time entries.
.PARAMETER Nickname
    The nickname of the project to update.
.EXAMPLE
    Update-TrackerProjectHours -Nickname "WEBSITE"
.OUTPUTS
    Boolean indicating success or failure
#>
function Update-TrackerProjectHours {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Nickname
    )
    
    Write-AppLog "Updating hours for project: $Nickname" -Level INFO
    
    try {
        # Use the imported Core module function
        Update-CumulativeHours -Nickname $Nickname
        
        # Get the project to display updated hours
        $config = Get-AppConfig
        $ProjectsFilePath = $config.ProjectsFullPath
        
        $projects = @(Get-EntityData -FilePath $ProjectsFilePath)
        $project = $projects | Where-Object { $_.Nickname -eq $Nickname } | Select-Object -First 1
        
        if ($project) {
            Write-ColorText "Updated hours for project '$Nickname': $($project.CumulativeHrs)" -ForegroundColor (Get-CurrentTheme).Colors.Success
            return $true
        } else {
            Write-ColorText "Project '$Nickname' not found." -ForegroundColor (Get-CurrentTheme).Colors.Warning
            return $false
        }
    } catch {
        Handle-Error -ErrorRecord $_ -Context "Updating project hours" -Continue
        return $false
    }
}




# Ensure this is in the Export-ModuleMember line at the end of the file:
# Export-ModuleMember -Function Show-ProjectList, New-TrackerProject, Update-TrackerProject, Remove-TrackerProject, Get-TrackerProject, Set-TrackerProjectStatus, Update-TrackerProjectHours, Show-ProjectMenu

# Add this at the end of your ProjectTracker.Core.psm1 file

Export-ModuleMember -Function @(
    # Configuration Functions
    'Get-AppConfig', 
    'Save-AppConfig',
    'Merge-Hashtables',

    # Error Handling Functions
    'Handle-Error',
    'Invoke-WithErrorHandling',

    # Logging Functions
    'Write-AppLog',
    'Rotate-LogFile',
    'Get-AppLogContent',

    # Data Functions
    'Ensure-DirectoryExists',
    'Get-EntityData',
    'Save-EntityData',
    'Update-CumulativeHours',
    'Get-EntityById',
    'Update-EntityById',
    'Remove-EntityById',
    'Create-Entity',

    # Date Functions
    'Parse-DateInput',
    'Convert-DisplayDateToInternal',
    'Convert-InternalDateToDisplay',
    'Get-RelativeDateDescription',
    'Get-DateInput',
    'Get-FirstDayOfWeek',
    'Get-WeekNumber',
    'Get-MonthName',
    'Get-RelativeWeekDescription',
    'Get-MonthDateRange',

    # Helper Functions
    'Read-UserInput',
    'Confirm-Action',
    'New-MenuItems',
    'Show-Confirmation',
    'Get-EnvironmentVariable',
    'Join-PathSafely',
    'Get-UniqueFileName',
    'ConvertTo-ValidFileName',
    'Get-TempFilePath',
    'Convert-PriorityToInt',
    'New-ID',
    'New-RandomPassword',
    'Convert-BytesToHumanReadable',
    'Find-SubstringPosition',
    'Convert-ToSlug',

    # Display Functions
    'Get-SafeConsoleWidth',
    'Write-ColorText',
    'Remove-AnsiCodes',
    'Get-VisibleStringLength',
    'Safe-TruncateString',
    'Render-Header',
    'Show-Table',
    'Show-InfoBox',
    'Show-ProgressBar',
    'Show-DynamicMenu',

    # Theme Management Functions
    'Get-Theme',
    'Set-CurrentTheme',
    'Get-CurrentTheme',
    'Get-AvailableThemes',
    'Merge-ThemeRecursive',
    
    # Initialization Functions
    'Initialize-DataEnvironment',
    'Initialize-ThemeEngine',
    'Copy-HashtableDeep',
    'ConvertFrom-JsonToHashtable'
)

# Fix for ProjectTracker.Projects.psm1
# Add this line at the end of Export-ModuleMember -Function Show-ProjectList, New-TrackerProject, Update-TrackerProject, 
Export-ModuleMember -Function Show-ProjectList, New-TrackerProject, Update-TrackerProject, `
    Remove-TrackerProject, Get-TrackerProject, Set-TrackerProjectStatus, `
    Update-TrackerProjectHours, Show-ProjectMenu, Add-TodoItem, Update-TodoForProject