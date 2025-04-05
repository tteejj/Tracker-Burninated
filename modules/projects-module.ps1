# modules/projects.ps1
# Project Management Module for Project Tracker
# Handles creating, updating, listing, and managing projects

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("List", "New", "Update", "Delete", "Get", "ChangeStatus", "UpdateHours")]
    [string]$Action,
    
    [Parameter(Mandatory=$true)]
    [string]$DataPath, # Base data path
    
    [Parameter(Mandatory=$false)]
    [hashtable]$Theme = $null, # Optional theme object
    
    [Parameter(Mandatory=$false)]
    [hashtable]$Config = $null, # Optional config object
    
    [Parameter(ParameterSetName='Get')]
    [Parameter(ParameterSetName='Update')]
    [Parameter(ParameterSetName='Delete')]
    [Parameter(ParameterSetName='ChangeStatus')]
    [string]$Nickname,
    
    [Parameter(ParameterSetName='New')]
    [Parameter(ParameterSetName='Update')]
    [hashtable]$ProjectData,
    
    [Parameter(ParameterSetName='List')]
    [switch]$IncludeAll, # Include closed projects
    
    [Parameter(ParameterSetName='ChangeStatus')]
    [ValidateSet("Active", "On Hold", "Closed")]
    [string]$Status = "Active"
)

# Load dependencies
try {
    # Library imports
    . "$PSScriptRoot/../lib/config.ps1"
    . "$PSScriptRoot/../lib/error-handling.ps1"
    . "$PSScriptRoot/../lib/logging.ps1"
    . "$PSScriptRoot/../lib/data-functions.ps1"
    . "$PSScriptRoot/../lib/theme-engine.ps1"
    . "$PSScriptRoot/../lib/helper-functions.ps1"
    . "$PSScriptRoot/../lib/date-functions.ps1"
} catch {
    Write-Error "Failed to load core libraries: $($_.Exception.Message)"
    exit 1
}

# Initialize Config and Theme
try {
    $script:AppConfig = if ($Config) { $Config } else { Get-AppConfig }
    
    # Set theme, fallback to default from config if not passed or invalid
    if ($Theme -is [hashtable]) {
        $script:currentTheme = $Theme
    } else {
        $script:currentTheme = Get-Theme -ThemeName $script:AppConfig.DefaultTheme
    }
    
    # Ensure theme colors are set for easy access
    Set-CurrentTheme -ThemeObject $script:currentTheme | Out-Null
} catch {
    Write-Error "Failed to initialize config or theme: $($_.Exception.Message)"
    exit 1
}

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

# Construct full data file paths using $DataPath and config filenames
$ProjectsFilePath = Join-Path $DataPath $script:AppConfig.ProjectsFile
$TodosFilePath = Join-Path $DataPath $script:AppConfig.TodosFile

# Define Module Functions

<#
.SYNOPSIS
    Lists active or all projects.
.DESCRIPTION
    Retrieves and displays a list of projects, either all or only active ones.
    Active projects are those not marked as "Closed".
.PARAMETER IncludeAll
    If true, includes closed projects in the listing.
#>
function Invoke-ListAction {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)]
        [bool]$IncludeAll = $false
    )
    
    Write-AppLog "Listing projects (IncludeAll: $IncludeAll)" -Level INFO
    
    try {
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
            Update-CumulativeHours -Nickname $project.Nickname -Config $script:AppConfig
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
            Write-ColorText "No projects found." -ForegroundColor $script:colors.Warning
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
            $status = if ([string]::IsNullOrWhiteSpace($item.Status)) { "Active" } else { $item.Status }
            
            if ($status -eq "Closed") {
                return $script:colors.Completed
            }
            
            if ($status -eq "On Hold") {
                return $script:colors.Warning
            }
            
            try {
                $dueDate = $item.DueDate
                if($dueDate -match '^\d{8}$') {
                    $dt = [datetime]::ParseExact($dueDate, "yyyyMMdd", $null).Date
                    if ($dt -lt $today) {
                        return $script:colors.Overdue
                    }
                    if (($dt - $today).Days -le 7) {
                        return $script:colors.DueSoon
                    }
                }
            } catch {}
            
            return $script:colors.Normal
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
        Handle-Error -ErrorRecord $_ -Context "Listing projects"
        return @()
    }
}

<#
.SYNOPSIS
    Creates a new project.
.DESCRIPTION
    Creates a new project with the specified properties.
    Takes input from the user for each field if not provided in $ProjectData.
.PARAMETER ProjectData
    Optional hashtable containing project data fields.
#>
function Invoke-NewAction {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)]
        [hashtable]$ProjectData = $null
    )
    
    Write-AppLog "Creating new project" -Level INFO
    Render-Header "Create New Project"
    
    try {
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
                
                if ([string]::IsNullOrWhiteSpace($input)) {
                    Write-ColorText "Nickname cannot be empty." -ForegroundColor $script:colors.Error
                    return $false
                }
                
                if ($input.Length -gt 15) {
                    Write-ColorText "Nickname must be 15 characters or less." -ForegroundColor $script:colors.Error
                    return $false
                }
                
                # Check if nickname already exists
                $projects = @(Get-EntityData -FilePath $ProjectsFilePath)
                $existingProject = $projects | Where-Object { $_.Nickname -eq $input } | Select-Object -First 1
                
                if ($existingProject) {
                    Write-ColorText "Nickname '$input' already exists." -ForegroundColor $script:colors.Error
                    return $false
                }
                
                return $true
            }
            
            $nickName = Read-UserInput -Prompt "Enter Nickname (unique, max 15 chars)" -Validator $nicknameValidator -ErrorMessage "Invalid nickname."
            $newProj | Add-Member -NotePropertyName "Nickname" -NotePropertyValue $nickName -Force
        }
        
        # Prompt for full project name if not provided
        if (-not $newProj.PSObject.Properties.Name.Contains("FullProjectName") -or 
            [string]::IsNullOrWhiteSpace($newProj.FullProjectName)) {
            
            $fullNameValidator = {
                param($input)
                
                if ([string]::IsNullOrWhiteSpace($input)) {
                    Write-ColorText "Full Name cannot be empty." -ForegroundColor $script:colors.Error
                    return $false
                }
                
                return $true
            }
            
            $fullName = Read-UserInput -Prompt "Enter Full Project Name" -Validator $fullNameValidator -ErrorMessage "Invalid full name."
            $newProj | Add-Member -NotePropertyName "FullProjectName" -NotePropertyValue $fullName -Force
        }
        
        # Prompt for ID1 if not provided
        if (-not $newProj.PSObject.Properties.Name.Contains("ID1")) {
            $id1 = Read-UserInput -Prompt "Enter ID1 (e.g., Client Code, optional)"
            $newProj | Add-Member -NotePropertyName "ID1" -NotePropertyValue $id1 -Force
        }
        
        # Prompt for ID2 if not provided
        if (-not $newProj.PSObject.Properties.Name.Contains("ID2")) {
            $id2 = Read-UserInput -Prompt "Enter ID2 (e.g., Engagement Code, optional)"
            $newProj | Add-Member -NotePropertyName "ID2" -NotePropertyValue $id2 -Force
        }
        
        # Prompt for assigned date if not provided
        if (-not $newProj.PSObject.Properties.Name.Contains("DateAssigned") -or 
            [string]::IsNullOrWhiteSpace($newProj.DateAssigned)) {
            
            $assignedDate = Get-DateInput -PromptText "Enter Assigned Date (MM/DD/YYYY)" -AllowEmptyForToday
            $newProj | Add-Member -NotePropertyName "DateAssigned" -NotePropertyValue $assignedDate -Force
        }
        
        # Calculate Due Date (default: 42 days from assigned date) if not provided
        if (-not $newProj.PSObject.Properties.Name.Contains("DueDate") -or 
            [string]::IsNullOrWhiteSpace($newProj.DueDate)) {
            
            $dtAssigned = [datetime]::ParseExact($newProj.DateAssigned, "yyyyMMdd", $null)
            $dtDue = $dtAssigned.AddDays(42)
            $dueDate = $dtDue.ToString("yyyyMMdd")
            
            Write-ColorText "Due Date calculated: $(Convert-InternalDateToDisplay $dueDate)" -ForegroundColor $script:colors.Accent2
            $newProj | Add-Member -NotePropertyName "DueDate" -NotePropertyValue $dueDate -Force
        }
        
        # Prompt for BF Date if not provided
        if (-not $newProj.PSObject.Properties.Name.Contains("BFDate") -or 
            [string]::IsNullOrWhiteSpace($newProj.BFDate)) {
            
            $bfDatePrompt = "Enter BF Date (MM/DD/YYYY, Enter=DueDate)"
            $bfDate = Get-DateInput -PromptText $bfDatePrompt -DefaultValue $newProj.DueDate
            $newProj | Add-Member -NotePropertyName "BFDate" -NotePropertyValue $bfDate -Force
        }
        
        # Prompt for Note if not provided
        if (-not $newProj.PSObject.Properties.Name.Contains("Note")) {
            $note = Read-UserInput -Prompt "Enter Note (optional)"
            $newProj | Add-Member -NotePropertyName "Note" -NotePropertyValue $note -Force
        }
        
        # Prompt for Project Folder if not provided
        if (-not $newProj.PSObject.Properties.Name.Contains("ProjFolder")) {
            $projFolder = Read-UserInput -Prompt "Enter Project Folder Path (optional)"
            $newProj | Add-Member -NotePropertyName "ProjFolder" -NotePropertyValue $projFolder -Force
        }
        
        # Set default values for remaining fields
        if (-not $newProj.PSObject.Properties.Name.Contains("ClosedDate")) {
            $newProj | Add-Member -NotePropertyName "ClosedDate" -NotePropertyValue "" -Force
        }
        
        if (-not $newProj.PSObject.Properties.Name.Contains("Status")) {
            $newProj | Add-Member -NotePropertyName "Status" -NotePropertyValue "Active" -Force
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
            Write-ColorText "Project '$($newProj.Nickname)' created successfully!" -ForegroundColor $script:colors.Success
            
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
            Write-ColorText "Failed to save new project." -ForegroundColor $script:colors.Error
            Read-Host "Press Enter to continue..."
            return $null
        }
    } catch {
        Handle-Error -ErrorRecord $_ -Context "Creating new project"
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
        # Get existing todos
        $todos = @(Get-EntityData -FilePath $TodosFilePath -RequiredHeaders $TODO_HEADERS)
        
        # Create new todo
        $newTodo = [PSCustomObject]@{
            ID = [guid]::NewGuid().ToString()
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
    Updates a project's details.
.DESCRIPTION
    Updates an existing project with new values.
    Takes input from the user for each field if not provided in $ProjectData.
.PARAMETER Nickname
    The nickname of the project to update.
.PARAMETER ProjectData
    Optional hashtable containing updated project data fields.
#>
function Invoke-UpdateAction {
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
        # Get existing projects
        $projects = @(Get-EntityData -FilePath $ProjectsFilePath -RequiredHeaders $PROJECTS_HEADERS)
        $originalProject = $projects | Where-Object { $_.Nickname -eq $Nickname } | Select-Object -First 1
        
        if (-not $originalProject) {
            Write-ColorText "Error: Project '$Nickname' not found." -ForegroundColor $script:colors.Error
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
            # Interactive update - prompt for each field
            Write-ColorText "`nUpdating Project: $($updatedProj.Nickname)" -ForegroundColor $script:colors.Accent2
            Write-ColorText "Enter new value or press Enter to keep current. Enter '0' to cancel." -ForegroundColor $script:colors.Accent2
            
            # Function to prompt for field update
            function Read-UpdateField {
                param($FieldName, [ref]$ProjectObject, [switch]$IsDate)
                
                $currentValue = $ProjectObject.Value.$FieldName
                $displayCurrent = if ($IsDate) { Convert-InternalDateToDisplay $currentValue } else { $currentValue }
                $input = Read-UserInput -Prompt "$FieldName (current: $displayCurrent)"
                
                if ($input -eq '0') {
                    return $false # Cancel
                }
                
                if (-not [string]::IsNullOrWhiteSpace($input) -and $input -ne $currentValue) {
                    if ($IsDate) {
                        $internalDate = Parse-DateInput -InputDate $input
                        if ($internalDate -and $internalDate -ne "CANCEL") {
                            $ProjectObject.Value.$FieldName = $internalDate # Store internal format
                        } elseif ($internalDate -ne "CANCEL") {
                            Write-ColorText "Invalid date format. Keeping original." -ForegroundColor $script:colors.Warning
                        } else {
                            return $false # Cancelled during date parse
                        }
                    } else {
                        $ProjectObject.Value.$FieldName = $input
                    }
                }
                
                return $true # Continue
            }
            
            # Prompt for each field
            if (-not (Read-UpdateField "FullProjectName" ([ref]$updatedProj))) {
                return $null
            }
            
            if (-not (Read-UpdateField "ID1" ([ref]$updatedProj))) {
                return $null
            }
            
            if (-not (Read-UpdateField "ID2" ([ref]$updatedProj))) {
                return $null
            }
            
            if (-not (Read-UpdateField "DateAssigned" ([ref]$updatedProj) -IsDate)) {
                return $null
            }
            
            if (-not (Read-UpdateField "DueDate" ([ref]$updatedProj) -IsDate)) {
                return $null
            }
            
            if (-not (Read-UpdateField "BFDate" ([ref]$updatedProj) -IsDate)) {
                return $null
            }
            
            if (-not (Read-UpdateField "Note" ([ref]$updatedProj))) {
                return $null
            }
            
            if (-not (Read-UpdateField "ProjFolder" ([ref]$updatedProj))) {
                return $null
            }
            
            # Status update
            $currentStatus = if ([string]::IsNullOrWhiteSpace($updatedProj.Status)) { "Active" } else { $updatedProj.Status }
            
            Write-ColorText "Current Status: $currentStatus" -ForegroundColor $script:colors.Accent2
            Write-ColorText "[1] Active" -ForegroundColor $script:colors.Success
            Write-ColorText "[2] Closed" -ForegroundColor $script:colors.Completed
            Write-ColorText "[3] On Hold" -ForegroundColor $script:colors.Warning
            Write-ColorText "[0] Keep Current" -ForegroundColor $script:colors.Accent2
            
            $statusChoice = Read-UserInput -Prompt "Select new status"
            
            switch($statusChoice) {
                '1' { $updatedProj.Status = "Active" }
                '2' { $updatedProj.Status = "Closed" }
                '3' { $updatedProj.Status = "On Hold" }
                '0' {} '' {} default {
                    Write-ColorText "Invalid status choice. Keeping original." -ForegroundColor $script:colors.Warning
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
            Write-ColorText "Project '$($updatedProj.Nickname)' updated successfully!" -ForegroundColor $script:colors.Success
            
            # Update related todo if BFDate or Note changed
            if (($updatedProj.BFDate -ne $originalProject.BFDate) -or ($updatedProj.Note -ne $originalProject.Note)) {
                Update-TodoForProject -Nickname $updatedProj.Nickname -NewBFDate $updatedProj.BFDate -NewNote $updatedProj.Note
            }
            
            # Log success
            Write-AppLog "Updated project: $($updatedProj.Nickname)" -Level INFO
            
            Read-Host "Press Enter to continue..."
            return $updatedProj
        } else {
            Write-ColorText "Failed to save updated project." -ForegroundColor $script:colors.Error
            Read-Host "Press Enter to continue..."
            return $null
        }
    } catch {
        Handle-Error -ErrorRecord $_ -Context "Updating project"
        return $null
    }
}

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
    Deletes a project.
.DESCRIPTION
    Deletes a project and its related todo items.
.PARAMETER Nickname
    The nickname of the project to delete.
#>
function Invoke-DeleteAction {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Nickname
    )
    
    Write-AppLog "Deleting project: $Nickname" -Level INFO
    Render-Header "Delete Project"
    
    try {
        # Get existing projects
        $projects = @(Get-EntityData -FilePath $ProjectsFilePath)
        $project = $projects | Where-Object { $_.Nickname -eq $Nickname } | Select-Object -First 1
        
        if (-not $project) {
            Write-ColorText "Error: Project '$Nickname' not found." -ForegroundColor $script:colors.Error
            Read-Host "Press Enter to continue..."
            return $false
        }
        
        # Display project details
        Write-ColorText "Project to delete: $($project.Nickname) - $($project.FullProjectName)" -ForegroundColor $script:colors.Accent2
        Write-ColorText "WARNING: This will permanently delete this project and its related items!" -ForegroundColor $script:colors.Error
        Write-ColorText "This action cannot be undone." -ForegroundColor $script:colors.Error
        
        # Confirm deletion
        $confirm = Read-UserInput -Prompt "Type the project nickname to confirm deletion"
        
        if ($confirm -ne $Nickname) {
            Write-ColorText "Deletion cancelled (confirmation did not match)." -ForegroundColor $script:colors.Warning
            Read-Host "Press Enter to continue..."
            return $false
        }
        
        # Remove the project
        $newProjects = $projects | Where-Object { $_.Nickname -ne $Nickname }
        
        if ($newProjects.Count -eq $projects.Count) {
            Write-ColorText "Project not found in database." -ForegroundColor $script:colors.Error
            Read-Host "Press Enter to continue..."
            return $false
        }
        
        # Save projects
        if (Save-EntityData -Data $newProjects -FilePath $ProjectsFilePath -RequiredHeaders $PROJECTS_HEADERS) {
            # Remove related todos
            $todos = @(Get-EntityData -FilePath $TodosFilePath)
            $newTodos = $todos | Where-Object { $_.Nickname -ne $Nickname }
            
            if ($newTodos.Count -ne $todos.Count) {
                Save-EntityData -Data $newTodos -FilePath $TodosFilePath -RequiredHeaders $TODO_HEADERS | Out-Null
            }
            
            Write-ColorText "Project '$Nickname' and related items have been deleted." -ForegroundColor $script:colors.Success
            Write-AppLog "Deleted project: $Nickname" -Level INFO
            
            Read-Host "Press Enter to continue..."
            return $true
        } else {
            Write-ColorText "Failed to delete project." -ForegroundColor $script:colors.Error
            Read-Host "Press Enter to continue..."
            return $false
        }
    } catch {
        Handle-Error -ErrorRecord $_ -Context "Deleting project"
        return $false
    }
}

<#
.SYNOPSIS
    Gets a project by nickname.
.DESCRIPTION
    Retrieves a project by its nickname.
.PARAMETER Nickname
    The nickname of the project to retrieve.
#>
function Invoke-GetAction {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Nickname
    )
    
    Write-Verbose "Getting project: $Nickname"
    
    try {
        # Get projects
        $projects = @(Get-EntityData -FilePath $ProjectsFilePath -RequiredHeaders $PROJECTS_HEADERS)
        $project = $projects | Where-Object { $_.Nickname -eq $Nickname } | Select-Object -First 1
        
        if (-not $project) {
            Write-Verbose "Project '$Nickname' not found."
            return $null
        }
        
        return $project
    } catch {
        Handle-Error -ErrorRecord $_ -Context "Getting project '$Nickname'" -Continue
        return $null
    }
}

<#
.SYNOPSIS
    Changes a project's status.
.DESCRIPTION
    Updates a project's status and related fields.
.PARAMETER Nickname
    The nickname of the project to update.
.PARAMETER Status
    The new status (Active, On Hold, Closed).
#>
function Invoke-ChangeStatusAction {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Nickname,
        
        [Parameter(Mandatory=$true)]
        [ValidateSet("Active", "On Hold", "Closed")]
        [string]$Status
    )
    
    Write-AppLog "Changing project status: $Nickname to $Status" -Level INFO
    Render-Header "Change Project Status"
    
    try {
        # Get existing projects
        $projects = @(Get-EntityData -FilePath $ProjectsFilePath)
        $project = $projects | Where-Object { $_.Nickname -eq $Nickname } | Select-Object -First 1
        
        if (-not $project) {
            Write-ColorText "Error: Project '$Nickname' not found." -ForegroundColor $script:colors.Error
            Read-Host "Press Enter to continue..."
            return $false
        }
        
        # Display project details
        Write-ColorText "Project: $($project.Nickname) - $($project.FullProjectName)" -ForegroundColor $script:colors.Accent2
        
        $currentStatus = if ([string]::IsNullOrWhiteSpace($project.Status)) { 
            if ([string]::IsNullOrWhiteSpace($project.ClosedDate)) {
                "Active"
            } else {
                "Closed"
            }
        } else {
            $project.Status
        }
        
        Write-ColorText "Current Status: $currentStatus" -ForegroundColor $script:colors.Accent2
        
        # Update status
        $project.Status = $Status
        
        # Update ClosedDate if status is Closed
        if ($Status -eq "Closed") {
            if ([string]::IsNullOrWhiteSpace($project.ClosedDate)) {
                $project.ClosedDate = (Get-Date).ToString("yyyyMMdd")
                Write-ColorText "Setting project status to CLOSED with completion date: $(Convert-InternalDateToDisplay $project.ClosedDate)" -ForegroundColor $script:colors.Warning
            } else {
                Write-ColorText "Setting project status to CLOSED (using existing completion date: $(Convert-InternalDateToDisplay $project.ClosedDate))" -ForegroundColor $script:colors.Warning
            }
        } else {
            if (-not [string]::IsNullOrWhiteSpace($project.ClosedDate)) {
                $project.ClosedDate = ""
                Write-ColorText "Setting project status to '$Status' and clearing completion date." -ForegroundColor $script:colors.Success
            } else {
                Write-ColorText "Setting project status to '$Status'." -ForegroundColor $script:colors.Success
            }
        }
        
        # Update todos if closing project
        if ($Status -eq "Closed") {
            # Get todos
            $todos = @(Get-EntityData -FilePath $TodosFilePath)
            $projectTodos = $todos | Where-Object { $_.Nickname -eq $Nickname -and $_.Status -ne "Completed" }
            
            if ($projectTodos.Count -gt 0) {
                Write-ColorText "Marking $($projectTodos.Count) open todo items as Completed." -ForegroundColor $script:colors.Warning
                
                foreach ($todo in $projectTodos) {
                    $todo.Status = "Completed"
                    $todo.CompletedDate = (Get-Date).ToString("yyyyMMdd")
                }
                
                # Save todos
                Save-EntityData -Data $todos -FilePath $TodosFilePath -RequiredHeaders $TODO_HEADERS | Out-Null
            }
        }
        
        # Save projects
        if (Save-EntityData -Data $projects -FilePath $ProjectsFilePath -RequiredHeaders $PROJECTS_HEADERS) {
            Write-ColorText "Project status updated successfully!" -ForegroundColor $script:colors.Success
            Write-AppLog "Changed project status: $Nickname to $Status" -Level INFO
            
            Read-Host "Press Enter to continue..."
            return $true
        } else {
            Write-ColorText "Failed to update project status." -ForegroundColor $script:colors.Error
            Read-Host "Press Enter to continue..."
            return $false
        }
    } catch {
        Handle-Error -ErrorRecord $_ -Context "Changing project status"
        return $false
    }
}

<#
.SYNOPSIS
    Updates cumulative hours for a project.
.DESCRIPTION
    Updates the cumulative hours for a project based on time entries.
.PARAMETER Nickname
    The nickname of the project to update.
#>
function Invoke-UpdateHoursAction {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Nickname
    )
    
    Write-Verbose "Updating hours for project: $Nickname"
    
    try {
        $result = Update-CumulativeHours -Nickname $Nickname -Config $script:AppConfig
        
        if ($result) {
            Write-Verbose "Successfully updated hours for project: $Nickname"
            return $true
        } else {
            Write-Verbose "Failed to update hours for project: $Nickname"
            return $false
        }
    } catch {
        Handle-Error -ErrorRecord $_ -Context "Updating project hours" -Continue
        return $false
    }
}

# Action Switch Block
try {
    Write-AppLog "Executing Action: $Action for Projects module" -Level DEBUG
    
    switch ($Action) {
        "List" {
            $result = Invoke-ListAction -IncludeAll:$IncludeAll
            exit 0
        }
        
        "New" {
            $result = Invoke-NewAction -ProjectData $ProjectData
            
            if ($null -ne $result) {
                exit 0
            } else {
                exit 1
            }
        }
        
        "Update" {
            $result = Invoke-UpdateAction -Nickname $Nickname -ProjectData $ProjectData
            
            if ($null -ne $result) {
                exit 0
            } else {
                exit 1
            }
        }
        
        "Delete" {
            $result = Invoke-DeleteAction -Nickname $Nickname
            
            if ($result) {
                exit 0
            } else {
                exit 1
            }
        }
        
        "Get" {
            $result = Invoke-GetAction -Nickname $Nickname
            
            if ($null -ne $result) {
                Write-Output $result | ConvertTo-Json -Depth 5
                exit 0
            } else {
                exit 1
            }
        }
        
        "ChangeStatus" {
            $result = Invoke-ChangeStatusAction -Nickname $Nickname -Status $Status
            
            if ($result) {
                exit 0
            } else {
                exit 1
            }
        }
        
        "UpdateHours" {
            $result = Invoke-UpdateHoursAction -Nickname $Nickname
            
            if ($result) {
                exit 0
            } else {
                exit 1
            }
        }
        
        default {
            throw "Invalid action specified: $Action"
        }
    }
    
    Write-AppLog "Action $Action completed successfully." -Level DEBUG
} catch {
    Handle-Error -ErrorRecord $_ -Context "Executing action $Action"
    exit 1
}
