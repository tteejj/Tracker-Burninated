# modules/todos.ps1
# Todo Item Management Module for Project Tracker
# Handles creating, updating, listing, and managing todo items

param(
    [Parameter(Mandatory=$true)]
    [ValidateSet("List", "New", "Update", "Complete", "Delete", "Get", "Filter")]
    [string]$Action,
    
    [Parameter(Mandatory=$true)]
    [string]$DataPath, # Base data path
    
    [Parameter(Mandatory=$false)]
    [hashtable]$Theme = $null, # Optional theme object
    
    [Parameter(Mandatory=$false)]
    [hashtable]$Config = $null, # Optional config object
    
    [Parameter(ParameterSetName='Get')]
    [Parameter(ParameterSetName='Update')]
    [Parameter(ParameterSetName='Complete')]
    [Parameter(ParameterSetName='Delete')]
    [string]$ID,
    
    [Parameter(ParameterSetName='New')]
    [Parameter(ParameterSetName='Update')]
    [hashtable]$TodoData,
    
    [Parameter(ParameterSetName='List')]
    [Parameter(ParameterSetName='Filter')]
    [switch]$IncludeCompleted, # Include completed todos
    
    [Parameter(ParameterSetName='List')]
    [Parameter(ParameterSetName='Filter')]
    [Parameter(ParameterSetName='New')]
    [string]$Nickname, # Filter by project nickname or assign to project
    
    [Parameter(ParameterSetName='Filter')]
    [string]$Status, # Filter by status
    
    [Parameter(ParameterSetName='Filter')]
    [ValidateSet("High", "Normal", "Low", "")]
    [string]$Importance = "", # Filter by importance
    
    [Parameter(ParameterSetName='Filter')]
    [string]$DueDateFrom, # Filter by due date range (YYYYMMDD)
    
    [Parameter(ParameterSetName='Filter')]
    [string]$DueDateTo,
    
    [Parameter(ParameterSetName='Filter')]
    [string]$SearchText # Search in task description
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

# Constants and todo configuration
$TODO_HEADERS = @(
    "ID", "Nickname", "TaskDescription", "Importance", "DueDate", 
    "Status", "CreatedDate", "CompletedDate"
)

$REQUIRED_TODO_FIELDS = @(
    "ID", "TaskDescription", "Importance", "DueDate", "Status"
)

# Project headers needed for referencing projects
$PROJECT_HEADERS = @(
    "Nickname", "FullProjectName", "Status"
)

# Construct full data file paths using $DataPath and config filenames
$TodosFilePath = Join-Path $DataPath $script:AppConfig.TodosFile
$ProjectsFilePath = Join-Path $DataPath $script:AppConfig.ProjectsFile

# Define Module Functions

<#
.SYNOPSIS
    Lists todo items with optional filtering.
.DESCRIPTION
    Retrieves and displays a list of todo items, with optional filtering.
    Can filter by completion status, project, and other criteria.
.PARAMETER IncludeCompleted
    If true, includes completed todo items in the listing.
.PARAMETER Nickname
    If specified, filters todos by project nickname.
#>
function Invoke-ListAction {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)]
        [bool]$IncludeCompleted = $false,
        
        [Parameter(Mandatory=$false)]
        [string]$Nickname = ""
    )
    
    Write-AppLog "Listing todos (IncludeCompleted: $IncludeCompleted, Nickname: $Nickname)" -Level INFO
    
    try {
        # Get todos
        $todos = @(Get-EntityData -FilePath $TodosFilePath -RequiredHeaders $TODO_HEADERS)
        
        # Apply filters
        if (-not $IncludeCompleted) {
            $todos = $todos | Where-Object { $_.Status -ne "Completed" }
        }
        
        if (-not [string]::IsNullOrWhiteSpace($Nickname)) {
            $todos = $todos | Where-Object { $_.Nickname -eq $Nickname }
        }
        
        # Get projects for display
        $projects = @(Get-EntityData -FilePath $ProjectsFilePath -RequiredHeaders $PROJECT_HEADERS)
        $projectMap = @{}
        foreach ($project in $projects) {
            $projectMap[$project.Nickname] = $project.FullProjectName
        }
        
        # Display todos
        $viewTitle = "Todo List"
        if (-not [string]::IsNullOrWhiteSpace($Nickname)) {
            $projectName = $projectMap[$Nickname] ?? $Nickname
            $viewTitle = "Todo List for $projectName"
        }
        
        Render-Header -Title $viewTitle
        
        if ($todos.Count -eq 0) {
            Write-ColorText "No todo items found." -ForegroundColor $script:colors.Warning
            Read-Host "Press Enter to continue..."
            return $todos
        }
        
        # Sort todos by status, importance, and due date
        $sortedTodos = $todos | Sort-Object {
            # Primary sort by status (pending first)
            switch ($_.Status) {
                "Pending" { 0 }
                "In Progress" { 1 }
                "On Hold" { 2 }
                "Completed" { 3 }
                default { 4 }
            }
        }, {
            # Secondary sort by importance
            Convert-PriorityToInt $_.Importance
        }, {
            # Tertiary sort by due date
            $_.DueDate
        }
        
        # Define display columns
        $columnsToShow = @("TaskDescription", "Importance", "DueDate", "Status")
        
        # Add Nickname column if not filtering by project
        if ([string]::IsNullOrWhiteSpace($Nickname)) {
            $columnsToShow = @("Nickname") + $columnsToShow
        }
        
        # Define column headers
        $tableHeaders = @{
            TaskDescription = "Task"
            DueDate = "Due Date"
        }
        
        # Define column formatters
        $today = (Get-Date).Date
        
        $tableFormatters = @{
            Nickname = { 
                param($val) 
                if ([string]::IsNullOrWhiteSpace($val)) { 
                    return "[General]" 
                } else {
                    return $val
                }
            }
            DueDate = { param($val) Convert-InternalDateToDisplay $val }
            Importance = { 
                param($val) 
                switch($val) {
                    "High" { return Write-ColorText $val -ForegroundColor "Red" -NoNewline; $val }
                    "Normal" { return Write-ColorText $val -ForegroundColor "Yellow" -NoNewline; $val }
                    "Low" { return Write-ColorText $val -ForegroundColor "Gray" -NoNewline; $val }
                    default { return $val }
                }
            }
        }
        
        # Define row colorizer
        $rowColorizer = {
            param($item, $rowIndex)
            
            switch ($item.Status) {
                "Completed" { return $script:colors.Completed }
                "On Hold" { return $script:colors.Warning }
                default {
                    try {
                        $dueDate = $item.DueDate
                        if($dueDate -match '^\d{8}$') {
                            $dt = [datetime]::ParseExact($dueDate, "yyyyMMdd", $null).Date
                            if ($dt -lt $today) {
                                return $script:colors.Overdue
                            }
                            if (($dt - $today).Days -le 3) {
                                return $script:colors.DueSoon
                            }
                        }
                    } catch {}
                    
                    # Color by importance if not due soon
                    switch ($item.Importance) {
                        "High" { return $script:colors.Error }
                        "Normal" { return $script:colors.Normal }
                        "Low" { return $script:colors.Completed }
                        default { return $script:colors.Normal }
                    }
                }
            }
        }
        
        # Display the table
        Show-Table -Data $sortedTodos -Columns $columnsToShow -Headers $tableHeaders -Formatters $tableFormatters -RowColorizer $rowColorizer
        
        # Log success
        Write-AppLog "Successfully listed $($todos.Count) todo items" -Level INFO
        
        # Show action hints
        Write-Host ""
        Write-Host "Quick Actions:" -ForegroundColor $script:colors.Accent1
        Write-ColorText " - Add a new todo: Use the 'New Todo' option in the menu" -ForegroundColor $script:colors.Normal
        Write-ColorText " - Mark a todo as complete: Use the 'Complete Todo' option in the menu" -ForegroundColor $script:colors.Normal
        
        # Wait for user input
        Read-Host "Press Enter to continue..."
        
        # Return todos array for potential use by other functions
        return $todos
    } catch {
        Handle-Error -ErrorRecord $_ -Context "Listing todo items"
        return @()
    }
}

<#
.SYNOPSIS
    Filters todo items based on various criteria.
.DESCRIPTION
    Retrieves and displays a filtered list of todo items.
    Can filter by multiple criteria such as status, importance, due date, and search text.
.PARAMETER IncludeCompleted
    If true, includes completed todo items in the listing.
.PARAMETER Nickname
    If specified, filters todos by project nickname.
.PARAMETER Status
    If specified, filters todos by status.
.PARAMETER Importance
    If specified, filters todos by importance.
.PARAMETER DueDateFrom
    If specified, filters todos by due date range (start).
.PARAMETER DueDateTo
    If specified, filters todos by due date range (end).
.PARAMETER SearchText
    If specified, filters todos by text in the task description.
#>
function Invoke-FilterAction {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)]
        [bool]$IncludeCompleted = $false,
        
        [Parameter(Mandatory=$false)]
        [string]$Nickname = "",
        
        [Parameter(Mandatory=$false)]
        [string]$Status = "",
        
        [Parameter(Mandatory=$false)]
        [string]$Importance = "",
        
        [Parameter(Mandatory=$false)]
        [string]$DueDateFrom = "",
        
        [Parameter(Mandatory=$false)]
        [string]$DueDateTo = "",
        
        [Parameter(Mandatory=$false)]
        [string]$SearchText = ""
    )
    
    Write-AppLog "Filtering todos with specified criteria" -Level INFO
    
    try {
        # Get todos
        $todos = @(Get-EntityData -FilePath $TodosFilePath -RequiredHeaders $TODO_HEADERS)
        
        # Apply filters
        if (-not $IncludeCompleted) {
            $todos = $todos | Where-Object { $_.Status -ne "Completed" }
        }
        
        if (-not [string]::IsNullOrWhiteSpace($Nickname)) {
            $todos = $todos | Where-Object { $_.Nickname -eq $Nickname }
        }
        
        if (-not [string]::IsNullOrWhiteSpace($Status)) {
            $todos = $todos | Where-Object { $_.Status -eq $Status }
        }
        
        if (-not [string]::IsNullOrWhiteSpace($Importance)) {
            $todos = $todos | Where-Object { $_.Importance -eq $Importance }
        }
        
        # Apply due date range filter
        if (-not [string]::IsNullOrWhiteSpace($DueDateFrom)) {
            $todos = $todos | Where-Object { $_.DueDate -ge $DueDateFrom }
        }
        
        if (-not [string]::IsNullOrWhiteSpace($DueDateTo)) {
            $todos = $todos | Where-Object { $_.DueDate -le $DueDateTo }
        }
        
        # Apply search text filter
        if (-not [string]::IsNullOrWhiteSpace($SearchText)) {
            $todos = $todos | Where-Object { $_.TaskDescription -like "*$SearchText*" }
        }
        
        # Get projects for display
        $projects = @(Get-EntityData -FilePath $ProjectsFilePath -RequiredHeaders $PROJECT_HEADERS)
        $projectMap = @{}
        foreach ($project in $projects) {
            $projectMap[$project.Nickname] = $project.FullProjectName
        }
        
        # Display todos
        $viewTitle = "Filtered Todo List"
        Render-Header -Title $viewTitle
        
        # Display filter criteria
        Write-Host "Filter Criteria:" -ForegroundColor $script:colors.Accent1
        if (-not $IncludeCompleted) { Write-ColorText " - Excluding completed items" -ForegroundColor $script:colors.Normal }
        if (-not [string]::IsNullOrWhiteSpace($Nickname)) { 
            $projectName = $projectMap[$Nickname] ?? $Nickname
            Write-ColorText " - Project: $projectName" -ForegroundColor $script:colors.Normal 
        }
        if (-not [string]::IsNullOrWhiteSpace($Status)) { Write-ColorText " - Status: $Status" -ForegroundColor $script:colors.Normal }
        if (-not [string]::IsNullOrWhiteSpace($Importance)) { Write-ColorText " - Importance: $Importance" -ForegroundColor $script:colors.Normal }
        if (-not [string]::IsNullOrWhiteSpace($DueDateFrom)) { Write-ColorText " - Due Date From: $(Convert-InternalDateToDisplay $DueDateFrom)" -ForegroundColor $script:colors.Normal }
        if (-not [string]::IsNullOrWhiteSpace($DueDateTo)) { Write-ColorText " - Due Date To: $(Convert-InternalDateToDisplay $DueDateTo)" -ForegroundColor $script:colors.Normal }
        if (-not [string]::IsNullOrWhiteSpace($SearchText)) { Write-ColorText " - Search Text: $SearchText" -ForegroundColor $script:colors.Normal }
        Write-Host ""
        
        if ($todos.Count -eq 0) {
            Write-ColorText "No matching todo items found." -ForegroundColor $script:colors.Warning
            Read-Host "Press Enter to continue..."
            return $todos
        }
        
        # Sort todos by status, importance, and due date
        $sortedTodos = $todos | Sort-Object {
            # Primary sort by status (pending first)
            switch ($_.Status) {
                "Pending" { 0 }
                "In Progress" { 1 }
                "On Hold" { 2 }
                "Completed" { 3 }
                default { 4 }
            }
        }, {
            # Secondary sort by importance
            Convert-PriorityToInt $_.Importance
        }, {
            # Tertiary sort by due date
            $_.DueDate
        }
        
        # Define display columns - always include Nickname for filtered view
        $columnsToShow = @("Nickname", "TaskDescription", "Importance", "DueDate", "Status")
        
        # Define column headers
        $tableHeaders = @{
            TaskDescription = "Task"
            DueDate = "Due Date"
        }
        
        # Define column formatters
        $today = (Get-Date).Date
        
        $tableFormatters = @{
            Nickname = { 
                param($val) 
                if ([string]::IsNullOrWhiteSpace($val)) { 
                    return "[General]" 
                } else {
                    return $val
                }
            }
            DueDate = { param($val) Convert-InternalDateToDisplay $val }
            Importance = { 
                param($val) 
                switch($val) {
                    "High" { return Write-ColorText $val -ForegroundColor "Red" -NoNewline; $val }
                    "Normal" { return Write-ColorText $val -ForegroundColor "Yellow" -NoNewline; $val }
                    "Low" { return Write-ColorText $val -ForegroundColor "Gray" -NoNewline; $val }
                    default { return $val }
                }
            }
        }
        
        # Define row colorizer
        $rowColorizer = {
            param($item, $rowIndex)
            
            switch ($item.Status) {
                "Completed" { return $script:colors.Completed }
                "On Hold" { return $script:colors.Warning }
                default {
                    try {
                        $dueDate = $item.DueDate
                        if($dueDate -match '^\d{8}$') {
                            $dt = [datetime]::ParseExact($dueDate, "yyyyMMdd", $null).Date
                            if ($dt -lt $today) {
                                return $script:colors.Overdue
                            }
                            if (($dt - $today).Days -le 3) {
                                return $script:colors.DueSoon
                            }
                        }
                    } catch {}
                    
                    # Color by importance if not due soon
                    switch ($item.Importance) {
                        "High" { return $script:colors.Error }
                        "Normal" { return $script:colors.Normal }
                        "Low" { return $script:colors.Completed }
                        default { return $script:colors.Normal }
                    }
                }
            }
        }
        
        # Display the table
        Show-Table -Data $sortedTodos -Columns $columnsToShow -Headers $tableHeaders -Formatters $tableFormatters -RowColorizer $rowColorizer
        
        # Log success
        Write-AppLog "Successfully filtered and displayed $($todos.Count) todo items" -Level INFO
        
        # Wait for user input
        Read-Host "Press Enter to continue..."
        
        # Return todos array for potential use by other functions
        return $todos
    } catch {
        Handle-Error -ErrorRecord $_ -Context "Filtering todo items"
        return @()
    }
}

<#
.SYNOPSIS
    Creates a new todo item.
.DESCRIPTION
    Creates a new todo item with the specified properties.
    Takes input from the user for each field if not provided in $TodoData.
.PARAMETER TodoData
    Optional hashtable containing todo data fields.
.PARAMETER Nickname
    Optional project nickname to associate with the todo item.
#>
function Invoke-NewAction {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)]
        [hashtable]$TodoData = $null,
        
        [Parameter(Mandatory=$false)]
        [string]$Nickname = ""
    )
    
    Write-AppLog "Creating new todo item" -Level INFO
    Render-Header "Create New Todo"
    
    try {
        # Initialize new todo object
        $newTodo = if ($TodoData) { 
            [PSCustomObject]$TodoData 
        } else { 
            [PSCustomObject]@{} 
        }
        
        # Generate a new ID if not provided
        if (-not $newTodo.PSObject.Properties.Name.Contains("ID")) {
            $newTodo | Add-Member -NotePropertyName "ID" -NotePropertyValue ([guid]::NewGuid().ToString()) -Force
        }
        
        # Set Nickname if provided
        if (-not [string]::IsNullOrWhiteSpace($Nickname) -and
            (-not $newTodo.PSObject.Properties.Name.Contains("Nickname") -or 
             [string]::IsNullOrWhiteSpace($newTodo.Nickname))) {
            
            $newTodo | Add-Member -NotePropertyName "Nickname" -NotePropertyValue $Nickname -Force
        }
        
        # If Nickname not set, let user select a project
        if (-not $newTodo.PSObject.Properties.Name.Contains("Nickname") -or 
            [string]::IsNullOrWhiteSpace($newTodo.Nickname)) {
            
            # Get projects
            $projects = @(Get-EntityData -FilePath $ProjectsFilePath -RequiredHeaders $PROJECT_HEADERS)
            $activeProjects = $projects | Where-Object { $_.Status -ne "Closed" }
            
            if ($activeProjects.Count -gt 0) {
                # Create menu of projects
                $menuItems = @()
                $menuItems += @{ Type = "header"; Text = "Select Project"; }
                
                # Add option for no project (general todo)
                $menuItems += @{
                    Type = "option";
                    Key = "G";
                    Text = "General Todo (No Project)";
                    Function = { return "" };
                }
                
                # Add project options
                $counter = 1
                foreach ($project in $activeProjects) {
                    $menuItems += @{
                        Type = "option";
                        Key = "$counter";
                        Text = "$($project.Nickname) - $($project.FullProjectName)";
                        Function = { return $project.Nickname };
                    }
                    $counter++
                }
                
                $menuItems += @{ Type = "separator"; }
                $menuItems += @{
                    Type = "option";
                    Key = "0";
                    Text = "Cancel";
                    Function = { return $null };
                    IsExit = $true;
                }
                
                # Show menu
                $selectedNickname = Show-DynamicMenu -Title "Select Project for Todo" -MenuItems $menuItems
                
                if ($null -eq $selectedNickname) {
                    Write-ColorText "Todo creation cancelled." -ForegroundColor $script:colors.Warning
                    return $null
                }
                
                $newTodo | Add-Member -NotePropertyName "Nickname" -NotePropertyValue $selectedNickname -Force
            } else {
                # No projects available
                $createGeneral = Read-UserInput -Prompt "No active projects found. Create a general todo item? (Y/N)"
                
                if ($createGeneral -notmatch '^[yY]') {
                    Write-ColorText "Todo creation cancelled." -ForegroundColor $script:colors.Warning
                    return $null
                }
                
                $newTodo | Add-Member -NotePropertyName "Nickname" -NotePropertyValue "" -Force
            }
        }
        
        # Prompt for task description if not provided
        if (-not $newTodo.PSObject.Properties.Name.Contains("TaskDescription") -or 
            [string]::IsNullOrWhiteSpace($newTodo.TaskDescription)) {
            
            $taskDescValidator = {
                param($input)
                
                if ([string]::IsNullOrWhiteSpace($input)) {
                    Write-ColorText "Task description cannot be empty." -ForegroundColor $script:colors.Error
                    return $false
                }
                
                return $true
            }
            
            $taskDesc = Read-UserInput -Prompt "Enter Task Description" -Validator $taskDescValidator -ErrorMessage "Invalid task description."
            $newTodo | Add-Member -NotePropertyName "TaskDescription" -NotePropertyValue $taskDesc -Force
        }
        
        # Prompt for importance if not provided
        if (-not $newTodo.PSObject.Properties.Name.Contains("Importance") -or 
            [string]::IsNullOrWhiteSpace($newTodo.Importance)) {
            
            Write-Host "Select Importance Level:" -ForegroundColor $script:colors.Accent1
            Write-ColorText "[1] High" -ForegroundColor "Red"
            Write-ColorText "[2] Normal" -ForegroundColor "Yellow"
            Write-ColorText "[3] Low" -ForegroundColor "Gray"
            
            $importanceValidator = {
                param($input)
                
                if ([string]::IsNullOrWhiteSpace($input) -or $input -notmatch '^[1-3]$') {
                    Write-ColorText "Please enter a valid option (1-3)." -ForegroundColor $script:colors.Error
                    return $false
                }
                
                return $true
            }
            
            $importanceChoice = Read-UserInput -Prompt "Select Importance (1-3)" -Validator $importanceValidator -ErrorMessage "Invalid selection."
            
            $importance = switch($importanceChoice) {
                "1" { "High" }
                "2" { "Normal" }
                "3" { "Low" }
                default { "Normal" }
            }
            
            $newTodo | Add-Member -NotePropertyName "Importance" -NotePropertyValue $importance -Force
        }
        
        # Prompt for due date if not provided
        if (-not $newTodo.PSObject.Properties.Name.Contains("DueDate") -or 
            [string]::IsNullOrWhiteSpace($newTodo.DueDate)) {
            
            $dueDate = Get-DateInput -PromptText "Enter Due Date (MM/DD/YYYY)" -AllowEmptyForToday
            $newTodo | Add-Member -NotePropertyName "DueDate" -NotePropertyValue $dueDate -Force
        }
        
        # Set default values for remaining fields
        if (-not $newTodo.PSObject.Properties.Name.Contains("Status")) {
            $newTodo | Add-Member -NotePropertyName "Status" -NotePropertyValue "Pending" -Force
        }
        
        if (-not $newTodo.PSObject.Properties.Name.Contains("CreatedDate")) {
            $newTodo | Add-Member -NotePropertyName "CreatedDate" -NotePropertyValue (Get-Date).ToString("yyyyMMdd") -Force
        }
        
        if (-not $newTodo.PSObject.Properties.Name.Contains("CompletedDate")) {
            $newTodo | Add-Member -NotePropertyName "CompletedDate" -NotePropertyValue "" -Force
        }
        
        # Get existing todos
        $todos = @(Get-EntityData -FilePath $TodosFilePath -RequiredHeaders $TODO_HEADERS)
        
        # Add the new todo
        $updatedTodos = $todos + $newTodo
        
        # Save todos
        if (Save-EntityData -Data $updatedTodos -FilePath $TodosFilePath -RequiredHeaders $TODO_HEADERS) {
            Write-ColorText "Todo item created successfully!" -ForegroundColor $script:colors.Success
            
            # Show the newly created todo
            Write-Host "`nTodo Details:" -ForegroundColor $script:colors.Accent1
            Write-ColorText "Task: $($newTodo.TaskDescription)" -ForegroundColor $script:colors.Normal
            Write-ColorText "Project: $(if ([string]::IsNullOrWhiteSpace($newTodo.Nickname)) { "General (No Project)" } else { $newTodo.Nickname })" -ForegroundColor $script:colors.Normal
            Write-ColorText "Importance: $($newTodo.Importance)" -ForegroundColor $(
                switch($newTodo.Importance) {
                    "High" { "Red" }
                    "Normal" { "Yellow" }
                    "Low" { "Gray" }
                    default { $script:colors.Normal }
                }
            )
            Write-ColorText "Due Date: $(Convert-InternalDateToDisplay $newTodo.DueDate)" -ForegroundColor $script:colors.Normal
            
            # Log success
            Write-AppLog "Created new todo item: $($newTodo.TaskDescription)" -Level INFO
            
            Read-Host "Press Enter to continue..."
            return $newTodo
        } else {
            Write-ColorText "Failed to save new todo item." -ForegroundColor $script:colors.Error
            Read-Host "Press Enter to continue..."
            return $null
        }
    } catch {
        Handle-Error -ErrorRecord $_ -Context "Creating new todo item"
        return $null
    }
}

<#
.SYNOPSIS
    Updates a todo item.
.DESCRIPTION
    Updates an existing todo item with new values.
    Takes input from the user for each field if not provided in $TodoData.
.PARAMETER ID
    The ID of the todo item to update.
.PARAMETER TodoData
    Optional hashtable containing updated todo data fields.
#>
function Invoke-UpdateAction {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$ID,
        
        [Parameter(Mandatory=$false)]
        [hashtable]$TodoData = $null
    )
    
    Write-AppLog "Updating todo item: $ID" -Level INFO
    Render-Header "Update Todo Item"
    
    try {
        # Get existing todos
        $todos = @(Get-EntityData -FilePath $TodosFilePath -RequiredHeaders $TODO_HEADERS)
        $originalTodo = $todos | Where-Object { $_.ID -eq $ID } | Select-Object -First 1
        
        if (-not $originalTodo) {
            Write-ColorText "Error: Todo item with ID '$ID' not found." -ForegroundColor $script:colors.Error
            Read-Host "Press Enter to continue..."
            return $null
        }
        
        # Create a copy of the original todo to update
        $updatedTodo = $originalTodo.PSObject.Copy()
        
        # If todo data is provided, update fields from it
        if ($TodoData -and $TodoData.Count -gt 0) {
            foreach ($key in $TodoData.Keys) {
                if ($key -eq "ID") {
                    # Skip ID as it's the identifier
                    continue
                }
                
                # Update property if it exists
                if ($updatedTodo.PSObject.Properties.Name -contains $key) {
                    $updatedTodo.$key = $TodoData[$key]
                } else {
                    # Add the property if it doesn't exist
                    $updatedTodo | Add-Member -NotePropertyName $key -NotePropertyValue $TodoData[$key] -Force
                }
            }
        } else {
            # Interactive update - prompt for each field
            Write-ColorText "`nUpdating Todo Item:" -ForegroundColor $script:colors.Accent2
            Write-ColorText "Current Task: $($updatedTodo.TaskDescription)" -ForegroundColor $script:colors.Normal
            Write-ColorText "Current Project: $(if ([string]::IsNullOrWhiteSpace($updatedTodo.Nickname)) { "General (No Project)" } else { $updatedTodo.Nickname })" -ForegroundColor $script:colors.Normal
            Write-ColorText "Enter new value or press Enter to keep current. Enter '0' to cancel." -ForegroundColor $script:colors.Accent2
            
            # Function to prompt for field update
            function Read-UpdateField {
                param($FieldName, [ref]$TodoObject, [switch]$IsDate)
                
                $currentValue = $TodoObject.Value.$FieldName
                $displayCurrent = if ($IsDate) { Convert-InternalDateToDisplay $currentValue } else { $currentValue }
                $input = Read-UserInput -Prompt "$FieldName (current: $displayCurrent)"
                
                if ($input -eq '0') {
                    return $false # Cancel
                }
                
                if (-not [string]::IsNullOrWhiteSpace($input) -and $input -ne $currentValue) {
                    if ($IsDate) {
                        $internalDate = Parse-DateInput -InputDate $input
                        if ($internalDate -and $internalDate -ne "CANCEL") {
                            $TodoObject.Value.$FieldName = $internalDate # Store internal format
                        } elseif ($internalDate -ne "CANCEL") {
                            Write-ColorText "Invalid date format. Keeping original." -ForegroundColor $script:colors.Warning
                        } else {
                            return $false # Cancelled during date parse
                        }
                    } else {
                        $TodoObject.Value.$FieldName = $input
                    }
                }
                
                return $true # Continue
            }
            
            # Prompt for task description
            if (-not (Read-UpdateField "TaskDescription" ([ref]$updatedTodo))) {
                return $null
            }
            
            # Prompt for project
            $currentNickname = if ([string]::IsNullOrWhiteSpace($updatedTodo.Nickname)) { "General (No Project)" } else { $updatedTodo.Nickname }
            Write-ColorText "Current Project: $currentNickname" -ForegroundColor $script:colors.Normal
            $changeProject = Read-UserInput -Prompt "Change project? (Y/N)"
            
            if ($changeProject -match '^[yY]') {
                # Get projects
                $projects = @(Get-EntityData -FilePath $ProjectsFilePath -RequiredHeaders $PROJECT_HEADERS)
                $activeProjects = $projects | Where-Object { $_.Status -ne "Closed" }
                
                if ($activeProjects.Count -gt 0) {
                    # Create menu of projects
                    $menuItems = @()
                    $menuItems += @{ Type = "header"; Text = "Select Project"; }
                    
                    # Add option for no project (general todo)
                    $menuItems += @{
                        Type = "option";
                        Key = "G";
                        Text = "General Todo (No Project)";
                        Function = { return "" };
                    }
                    
                    # Add project options
                    $counter = 1
                    foreach ($project in $activeProjects) {
                        $menuItems += @{
                            Type = "option";
                            Key = "$counter";
                            Text = "$($project.Nickname) - $($project.FullProjectName)";
                            Function = { return $project.Nickname };
                        }
                        $counter++
                    }
                    
                    $menuItems += @{ Type = "separator"; }
                    $menuItems += @{
                        Type = "option";
                        Key = "0";
                        Text = "Cancel";
                        Function = { return $null };
                        IsExit = $true;
                    }
                    
                    # Show menu
                    $selectedNickname = Show-DynamicMenu -Title "Select Project for Todo" -MenuItems $menuItems
                    
                    if ($null -eq $selectedNickname) {
                        Write-ColorText "Project change cancelled. Keeping original." -ForegroundColor $script:colors.Warning
                    } else {
                        $updatedTodo.Nickname = $selectedNickname
                    }
                } else {
                    Write-ColorText "No active projects found." -ForegroundColor $script:colors.Warning
                }
            }
            
            # Prompt for importance
            Write-Host "Current Importance: $($updatedTodo.Importance)" -ForegroundColor $script:colors.Normal
            Write-Host "Select New Importance Level:" -ForegroundColor $script:colors.Accent1
            Write-ColorText "[1] High" -ForegroundColor "Red"
            Write-ColorText "[2] Normal" -ForegroundColor "Yellow"
            Write-ColorText "[3] Low" -ForegroundColor "Gray"
            Write-ColorText "[0] Keep Current" -ForegroundColor $script:colors.Accent2
            
            $importanceChoice = Read-UserInput -Prompt "Select Importance (0-3)"
            
            if ($importanceChoice -match '^[1-3]$') {
                $importance = switch($importanceChoice) {
                    "1" { "High" }
                    "2" { "Normal" }
                    "3" { "Low" }
                    default { $updatedTodo.Importance }
                }
                
                $updatedTodo.Importance = $importance
            }
            
            # Prompt for due date
            if (-not (Read-UpdateField "DueDate" ([ref]$updatedTodo) -IsDate)) {
                return $null
            }
            
            # Prompt for status
            Write-Host "Current Status: $($updatedTodo.Status)" -ForegroundColor $script:colors.Normal
            Write-Host "Select New Status:" -ForegroundColor $script:colors.Accent1
            Write-ColorText "[1] Pending" -ForegroundColor $script:colors.Normal
            Write-ColorText "[2] In Progress" -ForegroundColor $script:colors.Accent2
            Write-ColorText "[3] On Hold" -ForegroundColor $script:colors.Warning
            Write-ColorText "[4] Completed" -ForegroundColor $script:colors.Completed
            Write-ColorText "[0] Keep Current" -ForegroundColor $script:colors.Accent2
            
            $statusChoice = Read-UserInput -Prompt "Select Status (0-4)"
            
            if ($statusChoice -match '^[1-4]$') {
                $status = switch($statusChoice) {
                    "1" { "Pending" }
                    "2" { "In Progress" }
                    "3" { "On Hold" }
                    "4" { "Completed" }
                    default { $updatedTodo.Status }
                }
                
                $updatedTodo.Status = $status
                
                # Update completed date if status is Completed
                if ($status -eq "Completed" -and [string]::IsNullOrWhiteSpace($updatedTodo.CompletedDate)) {
                    $updatedTodo.CompletedDate = (Get-Date).ToString("yyyyMMdd")
                } elseif ($status -ne "Completed") {
                    $updatedTodo.CompletedDate = ""
                }
            }
        }
        
        # Update the todo in the array
        $updatedTodos = @()
        foreach ($todo in $todos) {
            if ($todo.ID -eq $ID) {
                $updatedTodos += $updatedTodo
            } else {
                $updatedTodos += $todo
            }
        }
        
        # Save todos
        if (Save-EntityData -Data $updatedTodos -FilePath $TodosFilePath -RequiredHeaders $TODO_HEADERS) {
            Write-ColorText "Todo item updated successfully!" -ForegroundColor $script:colors.Success
            
            # Log success
            Write-AppLog "Updated todo item: $($updatedTodo.TaskDescription)" -Level INFO
            
            Read-Host "Press Enter to continue..."
            return $updatedTodo
        } else {
            Write-ColorText "Failed to save updated todo item." -ForegroundColor $script:colors.Error
            Read-Host "Press Enter to continue..."
            return $null
        }
    } catch {
        Handle-Error -ErrorRecord $_ -Context "Updating todo item"
        return $null
    }
}

<#
.SYNOPSIS
    Marks a todo item as completed.
.DESCRIPTION
    Updates a todo item's status to "Completed" and sets the completion date.
.PARAMETER ID
    The ID of the todo item to complete.
#>
function Invoke-CompleteAction {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$ID
    )
    
    Write-AppLog "Marking todo item as completed: $ID" -Level INFO
    Render-Header "Complete Todo Item"
    
    try {
        # Get existing todos
        $todos = @(Get-EntityData -FilePath $TodosFilePath -RequiredHeaders $TODO_HEADERS)
        $todo = $todos | Where-Object { $_.ID -eq $ID } | Select-Object -First 1
        
        if (-not $todo) {
            Write-ColorText "Error: Todo item with ID '$ID' not found." -ForegroundColor $script:colors.Error
            Read-Host "Press Enter to continue..."
            return $false
        }
        
        # Display todo details
        Write-ColorText "Task: $($todo.TaskDescription)" -ForegroundColor $script:colors.Normal
        Write-ColorText "Project: $(if ([string]::IsNullOrWhiteSpace($todo.Nickname)) { "General (No Project)" } else { $todo.Nickname })" -ForegroundColor $script:colors.Normal
        Write-ColorText "Importance: $($todo.Importance)" -ForegroundColor $script:colors.Normal
        Write-ColorText "Due Date: $(Convert-InternalDateToDisplay $todo.DueDate)" -ForegroundColor $script:colors.Normal
        Write-ColorText "Current Status: $($todo.Status)" -ForegroundColor $script:colors.Normal
        
        # Confirm completion
        $confirm = Read-UserInput -Prompt "Mark this todo item as completed? (Y/N)"
        
        if ($confirm -notmatch '^[yY]') {
            Write-ColorText "Operation cancelled." -ForegroundColor $script:colors.Warning
            Read-Host "Press Enter to continue..."
            return $false
        }
        
        # Update status and completion date
        $todo.Status = "Completed"
        $todo.CompletedDate = (Get-Date).ToString("yyyyMMdd")
        
        # Save todos
        if (Save-EntityData -Data $todos -FilePath $TodosFilePath -RequiredHeaders $TODO_HEADERS) {
            Write-ColorText "Todo item marked as completed!" -ForegroundColor $script:colors.Success
            Write-ColorText "Completion Date: $(Convert-InternalDateToDisplay $todo.CompletedDate)" -ForegroundColor $script:colors.Normal
            
            # Log success
            Write-AppLog "Marked todo item as completed: $($todo.TaskDescription)" -Level INFO
            
            Read-Host "Press Enter to continue..."
            return $true
        } else {
            Write-ColorText "Failed to save todo item status." -ForegroundColor $script:colors.Error
            Read-Host "Press Enter to continue..."
            return $false
        }
    } catch {
        Handle-Error -ErrorRecord $_ -Context "Completing todo item"
        return $false
    }
}

<#
.SYNOPSIS
    Deletes a todo item.
.DESCRIPTION
    Deletes a todo item from the data file.
.PARAMETER ID
    The ID of the todo item to delete.
#>
function Invoke-DeleteAction {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$ID
    )
    
    Write-AppLog "Deleting todo item: $ID" -Level INFO
    Render-Header "Delete Todo Item"
    
    try {
        # Get existing todos
        $todos = @(Get-EntityData -FilePath $TodosFilePath -RequiredHeaders $TODO_HEADERS)
        $todo = $todos | Where-Object { $_.ID -eq $ID } | Select-Object -First 1
        
        if (-not $todo) {
            Write-ColorText "Error: Todo item with ID '$ID' not found." -ForegroundColor $script:colors.Error
            Read-Host "Press Enter to continue..."
            return $false
        }
        
        # Display todo details
        Write-ColorText "Task: $($todo.TaskDescription)" -ForegroundColor $script:colors.Normal
        Write-ColorText "Project: $(if ([string]::IsNullOrWhiteSpace($todo.Nickname)) { "General (No Project)" } else { $todo.Nickname })" -ForegroundColor $script:colors.Normal
        Write-ColorText "Importance: $($todo.Importance)" -ForegroundColor $script:colors.Normal
        Write-ColorText "Due Date: $(Convert-InternalDateToDisplay $todo.DueDate)" -ForegroundColor $script:colors.Normal
        Write-ColorText "Status: $($todo.Status)" -ForegroundColor $script:colors.Normal
        
        # Confirm deletion
        Write-ColorText "WARNING: This will permanently delete this todo item!" -ForegroundColor $script:colors.Error
        $confirm = Read-UserInput -Prompt "Are you sure you want to delete this todo item? (Type 'yes' to confirm)"
        
        if ($confirm -ne "yes") {
            Write-ColorText "Deletion cancelled." -ForegroundColor $script:colors.Warning
            Read-Host "Press Enter to continue..."
            return $false
        }
        
        # Remove the todo
        $newTodos = $todos | Where-Object { $_.ID -ne $ID }
        
        # Save todos
        if (Save-EntityData -Data $newTodos -FilePath $TodosFilePath -RequiredHeaders $TODO_HEADERS) {
            Write-ColorText "Todo item deleted successfully!" -ForegroundColor $script:colors.Success
            
            # Log success
            Write-AppLog "Deleted todo item: $($todo.TaskDescription)" -Level INFO
            
            Read-Host "Press Enter to continue..."
            return $true
        } else {
            Write-ColorText "Failed to delete todo item." -ForegroundColor $script:colors.Error
            Read-Host "Press Enter to continue..."
            return $false
        }
    } catch {
        Handle-Error -ErrorRecord $_ -Context "Deleting todo item"
        return $false
    }
}

<#
.SYNOPSIS
    Gets a todo item by ID.
.DESCRIPTION
    Retrieves a todo item by its ID.
.PARAMETER ID
    The ID of the todo item to retrieve.
#>
function Invoke-GetAction {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$ID
    )
    
    Write-Verbose "Getting todo item: $ID"
    
    try {
        # Get todos
        $todos = @(Get-EntityData -FilePath $TodosFilePath -RequiredHeaders $TODO_HEADERS)
        $todo = $todos | Where-Object { $_.ID -eq $ID } | Select-Object -First 1
        
        if (-not $todo) {
            Write-Verbose "Todo item with ID '$ID' not found."
            return $null
        }
        
        return $todo
    } catch {
        Handle-Error -ErrorRecord $_ -Context "Getting todo item '$ID'" -Continue
        return $null
    }
}

# Action Switch Block
try {
    Write-AppLog "Executing Action: $Action for Todos module" -Level DEBUG
    
    switch ($Action) {
        "List" {
            $result = Invoke-ListAction -IncludeCompleted:$IncludeCompleted -Nickname $Nickname
            exit 0
        }
        
        "Filter" {
            $result = Invoke-FilterAction -IncludeCompleted:$IncludeCompleted -Nickname $Nickname -Status $Status -Importance $Importance -DueDateFrom $DueDateFrom -DueDateTo $DueDateTo -SearchText $SearchText
            exit 0
        }
        
        "New" {
            $result = Invoke-NewAction -TodoData $TodoData -Nickname $Nickname
            
            if ($null -ne $result) {
                exit 0
            } else {
                exit 1
            }
        }
        
        "Update" {
            $result = Invoke-UpdateAction -ID $ID -TodoData $TodoData
            
            if ($null -ne $result) {
                exit 0
            } else {
                exit 1
            }
        }
        
        "Complete" {
            $result = Invoke-CompleteAction -ID $ID
            
            if ($result) {
                exit 0
            } else {
                exit 1
            }
        }
        
        "Delete" {
            $result = Invoke-DeleteAction -ID $ID
            
            if ($result) {
                exit 0
            } else {
                exit 1
            }
        }
        
        "Get" {
            $result = Invoke-GetAction -ID $ID
            
            if ($null -ne $result) {
                Write-Output $result | ConvertTo-Json -Depth 5
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
