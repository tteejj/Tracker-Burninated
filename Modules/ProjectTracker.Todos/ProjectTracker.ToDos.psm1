# ProjectTracker.Todos.psm1
# Todo Management module for Project Tracker

<#
.SYNOPSIS
    Shows the Todo Management Menu with numeric navigation.
.DESCRIPTION
    Displays the todo management menu with all options using numeric keys.
.EXAMPLE
    Show-TodoMenu
#>
function Show-TodoMenu {
    $todoMenuItems = @()
    
    $todoMenuItems += @{
        Key = "header_1"
        Text = "Todo Management"
        Type = "header"
    }
    
    $todoMenuItems += @{
        Key = "1"
        Text = "View Pending Todos"
        Function = {
            Show-TodoList
            return $null
        }
        Type = "option"
    }
    
    $todoMenuItems += @{
        Key = "2"
        Text = "View All Todos"
        Function = {
            Show-TodoList -IncludeCompleted -ShowAll
            return $null
        }
        Type = "option"
    }
    
    $todoMenuItems += @{
        Key = "3"
        Text = "Create New Todo"
        Function = {
            New-TrackerTodoItem
            return $null
        }
        Type = "option"
    }
    
    $todoMenuItems += @{
        Key = "4"
        Text = "Update Todo"
        Function = {
            # First, show the todo list
            $todos = Show-TodoList
            
            # If no todos, return
            if ($todos.Count -eq 0) {
                return $null
            }
            
            # Display numeric list for selection
            Write-Host "Select todo to update by number (0 to cancel):" -ForegroundColor $script:colors.Accent2
            
            for ($i = 0; $i -lt $todos.Count; $i++) {
                $todoNum = $i + 1
                Write-Host "[$todoNum] $($todos[$i].TaskDescription)" -ForegroundColor $script:colors.Normal
            }
            
            $selection = Read-UserInput -Prompt "Enter todo number" -NumericOnly
            
            if ($selection -eq "CANCEL" -or $selection -eq "0") {
                Write-ColorText "Update cancelled." -ForegroundColor $script:colors.Warning
                Read-Host "Press Enter to continue..."
                return $null
            }
            
            # Convert selection to int and check range
            try {
                $index = [int]$selection - 1
                if ($index -lt 0 -or $index -ge $todos.Count) {
                    Write-ColorText "Invalid selection." -ForegroundColor $script:colors.Error
                    Read-Host "Press Enter to continue..."
                    return $null
                }
                
                # Update the selected todo
                Update-TrackerTodoItem -ID $todos[$index].ID
            } catch {
                Write-ColorText "Invalid selection." -ForegroundColor $script:colors.Error
                Read-Host "Press Enter to continue..."
            }
            
            return $null
        }
        Type = "option"
    }
    
    $todoMenuItems += @{
        Key = "5"
        Text = "Complete Todo"
        Function = {
            # First, show the pending todo list
            $todos = Show-TodoList
            
            # If no todos, return
            if ($todos.Count -eq 0) {
                return $null
            }
            
            # Display numeric list for selection
            Write-Host "Select todo to mark as completed by number (0 to cancel):" -ForegroundColor $script:colors.Accent2
            
            for ($i = 0; $i -lt $todos.Count; $i++) {
                $todoNum = $i + 1
                Write-Host "[$todoNum] $($todos[$i].TaskDescription)" -ForegroundColor $script:colors.Normal
            }
            
            $selection = Read-UserInput -Prompt "Enter todo number" -NumericOnly
            
            if ($selection -eq "CANCEL" -or $selection -eq "0") {
                Write-ColorText "Operation cancelled." -ForegroundColor $script:colors.Warning
                Read-Host "Press Enter to continue..."
                return $null
            }
            
            # Convert selection to int and check range
            try {
                $index = [int]$selection - 1
                if ($index -lt 0 -or $index -ge $todos.Count) {
                    Write-ColorText "Invalid selection." -ForegroundColor $script:colors.Error
                    Read-Host "Press Enter to continue..."
                    return $null
                }
                
                # Complete the selected todo
                Complete-TrackerTodoItem -ID $todos[$index].ID
            } catch {
                Write-ColorText "Invalid selection." -ForegroundColor $script:colors.Error
                Read-Host "Press Enter to continue..."
            }
            
            return $null
        }
        Type = "option"
    }
    
    $todoMenuItems += @{
        Key = "6"
        Text = "Delete Todo"
        Function = {
            # First, show all todos
            $todos = Show-TodoList -IncludeCompleted -ShowAll
            
            # If no todos, return
            if ($todos.Count -eq 0) {
                return $null
            }
            
            # Display numeric list for selection
            Write-Host "Select todo to DELETE by number (0 to cancel):" -ForegroundColor $script:colors.Accent2
            
            for ($i = 0; $i -lt $todos.Count; $i++) {
                $todoNum = $i + 1
                Write-Host "[$todoNum] $($todos[$i].TaskDescription)" -ForegroundColor $script:colors.Normal
            }
            
            $selection = Read-UserInput -Prompt "Enter todo number" -NumericOnly
            
            if ($selection -eq "CANCEL" -or $selection -eq "0") {
                Write-ColorText "Deletion cancelled." -ForegroundColor $script:colors.Warning
                Read-Host "Press Enter to continue..."
                return $null
            }
            
            # Convert selection to int and check range
            try {
                $index = [int]$selection - 1
                if ($index -lt 0 -or $index -ge $todos.Count) {
                    Write-ColorText "Invalid selection." -ForegroundColor $script:colors.Error
                    Read-Host "Press Enter to continue..."
                    return $null
                }
                
                # Delete the selected todo
                Remove-TrackerTodoItem -ID $todos[$index].ID
            } catch {
                Write-ColorText "Invalid selection." -ForegroundColor $script:colors.Error
                Read-Host "Press Enter to continue..."
            }
            
            return $null
        }
        Type = "option"
    }
    
    $todoMenuItems += @{
        Key = "7"
        Text = "View Project Todos"
        Function = {
            # Get available projects
            $config = Get-AppConfig
            $projects = @(Get-EntityData -FilePath $config.ProjectsFullPath)
            $colors = (Get-CurrentTheme).Colors
            
            if ($projects.Count -eq 0) {
                Write-ColorText "No projects found." -ForegroundColor $colors.Warning
                Read-Host "Press Enter to continue..."
                return $null
            }
            
            # Display numbered project list for selection
            Write-Host "Select project by number (0 to cancel):" -ForegroundColor $script:colors.Accent2
            
            for ($i = 0; $i -lt $projects.Count; $i++) {
                $projectNum = $i + 1
                Write-Host "[$projectNum] $($projects[$i].Nickname) - $($projects[$i].FullProjectName)" -ForegroundColor $script:colors.Normal
            }
            
            $selection = Read-UserInput -Prompt "Enter project number" -NumericOnly
            
            if ($selection -eq "CANCEL" -or $selection -eq "0") {
                Write-ColorText "Operation cancelled." -ForegroundColor $script:colors.Warning
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
                
                # Show todos for the selected project
                Show-FilteredTodoList -Nickname $projectNickname
            } catch {
                Write-ColorText "Invalid selection." -ForegroundColor $script:colors.Error
                Read-Host "Press Enter to continue..."
            }
            
            return $null
        }
        Type = "option"
    }
    
    $todoMenuItems += @{
        Key = "sep_1"
        Type = "separator"
    }
    
    $todoMenuItems += @{
        Key = "0"
        Text = "Back to Main Menu"
        Function = { 
            # Return true to exit the todo menu
            return $true 
        }
        IsExit = $true  # This exits the todo menu
        Type = "option"
    }
    
    # Make sure to always return null from menu result
    $menuResult = Show-DynamicMenu -Title "Todo Management" -MenuItems $todoMenuItems
    return $null
}




# Todo list retrieval
function Show-TodoList {
    [CmdletBinding()]
    param(
        [switch]$IncludeCompleted,
        [switch]$ShowAll
    )
    
    Render-Header -Title "Todo Items"
    
    try {
        $config = Get-AppConfig
        $todos = @(Get-EntityData -FilePath $config.TodosFullPath)
        
        if (-not $IncludeCompleted) {
            $todos = $todos | Where-Object { $_.Status -ne "Completed" }
        }
        
        if (-not $ShowAll) {
            # Limit to items without a project or with active projects
            $projects = @(Get-EntityData -FilePath $config.ProjectsFullPath)
            $activeProjects = $projects | Where-Object { $_.Status -ne "Closed" } | Select-Object -ExpandProperty Nickname
            
            $todos = $todos | Where-Object { 
                [string]::IsNullOrWhiteSpace($_.Nickname) -or $activeProjects -contains $_.Nickname 
            }
        }
        
        if ($todos.Count -eq 0) {
            $colors = (Get-CurrentTheme).Colors
            Write-ColorText "No todo items found." -ForegroundColor $colors.Warning
            Read-Host "Press Enter to continue..."
            return @()
        }
        
        # Define table display properties
        $columnsToShow = @("ID", "Nickname", "TaskDescription", "Importance", "DueDate", "Status")
        
        $tableHeaders = @{
            TaskDescription = "Task"
            DueDate = "Due Date"
        }
        
        # Ensure ID is displayed properly
        foreach ($todo in $todos) {
            if ($todo.ID.Length -gt 8) {
                # Truncate ID to make it more readable - first 8 chars should be enough
                $todo | Add-Member -NotePropertyName "_DisplayID" -NotePropertyValue $todo.ID.Substring(0, 8) -Force
            } else {
                $todo | Add-Member -NotePropertyName "_DisplayID" -NotePropertyValue $todo.ID -Force
            }
        }
        
        # Replace ID column with the truncated version
        $columnsToShow[0] = "_DisplayID"
        $tableHeaders["_DisplayID"] = "ID"
        
        $formatters = @{
            DueDate = { 
                param($val) 
                if ([string]::IsNullOrWhiteSpace($val)) { return "" }
                
                try {
                    # Only parse date portion, strip any time component
                    $date = [datetime]::ParseExact($val, "yyyyMMdd", $null)
                    return $date.ToString("yyyy-MM-dd")
                } catch {
                    # If parsing fails, try the standard conversion
                    return Convert-InternalDateToDisplay -InternalDate $val
                }
            }
            Importance = { 
                param($val) 
                return $val # Just return the string value, no special formatting needed
            }
        }
        
        # Sort todos by importance then due date
        $sortedTodos = $todos | Sort-Object { 
            # Convert priority to numeric value
            $priorityValue = Convert-PriorityToInt -Priority $_.Importance
            
            # Parse due date if valid
            $dueDate = $null
            if (-not [string]::IsNullOrWhiteSpace($_.DueDate)) {
                try {
                    $dueDate = [datetime]::ParseExact($_.DueDate, "yyyyMMdd", $null)
                } catch {
                    # Invalid date, use today + 1000 days as fallback
                    $dueDate = (Get-Date).AddDays(1000)
                }
            } else {
                # No due date, sort last
                $dueDate = (Get-Date).AddDays(1000)
            }
            
            # Return a composite sorting key
            return "$priorityValue-$($dueDate.ToString('yyyyMMdd'))"
        }
        
        # Define row colorizer
        $rowColorizer = {
            param($item, $rowIndex)
            
            $colors = (Get-CurrentTheme).Colors
            
            if ($item.Status -eq "Completed") {
                return $colors.Completed
            }
            
            # Check due date
            if (-not [string]::IsNullOrWhiteSpace($item.DueDate)) {
                try {
                    $dueDate = [datetime]::ParseExact($item.DueDate, "yyyyMMdd", $null)
                    $today = (Get-Date).Date
                    $daysUntilDue = ($dueDate - $today).Days
                    
                    if ($daysUntilDue -lt 0) {
                        return $colors.Overdue
                    } elseif ($daysUntilDue -le 7) {
                        return $colors.DueSoon
                    }
                } catch {
                    # Invalid date format, use default color
                }
            }
            
            # Use Importance for color if not already colored by due date
            switch ($item.Importance) {
                "High" { return $colors.Warning }
                default { return $colors.Normal }
            }
        }
        
        # Display the table
        Show-Table -Data $sortedTodos -Columns $columnsToShow -Headers $tableHeaders -Formatters $formatters -RowColorizer $rowColorizer
        
        Write-AppLog "Displayed todo list (Total items: $($todos.Count))" -Level INFO
        
        Read-Host "Press Enter to continue..."
        return $sortedTodos
    } catch {
        Handle-Error -ErrorRecord $_ -Context "Listing todo items" -Continue
        Read-Host "Press Enter to continue..."
        return @()
    }
}

# Filtered todo list display
function Show-FilteredTodoList {
    [CmdletBinding()]
    param(
        [string]$Nickname,
        [string]$Status,
        [string]$Importance,
        [switch]$DueSoon,
        [switch]$Overdue
    )
    
    Render-Header -Title "Filtered Todo Items"
    
    try {
        $config = Get-AppConfig
        $todos = @(Get-EntityData -FilePath $config.TodosFullPath)
        
        # Apply filters
        if (-not [string]::IsNullOrWhiteSpace($Nickname)) {
            $todos = $todos | Where-Object { $_.Nickname -eq $Nickname }
        }
        
        if (-not [string]::IsNullOrWhiteSpace($Status)) {
            $todos = $todos | Where-Object { $_.Status -eq $Status }
        }
        
        if (-not [string]::IsNullOrWhiteSpace($Importance)) {
            $todos = $todos | Where-Object { $_.Importance -eq $Importance }
        }
        
        if ($DueSoon -or $Overdue) {
            $today = (Get-Date).Date
            
            $todos = $todos | Where-Object {
                if ([string]::IsNullOrWhiteSpace($_.DueDate)) {
                    return $false
                }
                
                try {
                    $dueDate = [datetime]::ParseExact($_.DueDate, "yyyyMMdd", $null)
                    $daysUntilDue = ($dueDate - $today).Days
                    
                    if ($Overdue -and $daysUntilDue -lt 0) {
                        return $true
                    }
                    
                    if ($DueSoon -and $daysUntilDue -ge 0 -and $daysUntilDue -le 7) {
                        return $true
                    }
                    
                    return $false
                } catch {
                    return $false # Invalid date format
                }
            }
        }
        
        if ($todos.Count -eq 0) {
            $colors = (Get-CurrentTheme).Colors
            Write-ColorText "No todo items match the filter criteria." -ForegroundColor $colors.Warning
            Read-Host "Press Enter to continue..."
            return @()
        }
        
        # Use the same display logic as Show-TodoList
        $columnsToShow = @("ID", "Nickname", "TaskDescription", "Importance", "DueDate", "Status")
        
        $tableHeaders = @{
            TaskDescription = "Task"
            DueDate = "Due Date"
        }
        
        $formatters = @{
            DueDate = { param($val) Convert-InternalDateToDisplay -InternalDate $val }
            Importance = { param($val) 
                $colors = (Get-CurrentTheme).Colors
                switch ($val) {
                    "High" { Write-ColorText $val -ForegroundColor "Red" -NoNewline; $val }
                    "Normal" { Write-ColorText $val -ForegroundColor "Yellow" -NoNewline; $val }
                    "Low" { Write-ColorText $val -ForegroundColor "Gray" -NoNewline; $val }
                    default { return $val }
                }
            }
        }
        
        # Sort todos by importance then due date
        $sortedTodos = $todos | Sort-Object { Convert-PriorityToInt -Priority $_.Importance }, DueDate
        
        # Same row colorizer as Show-TodoList
        $rowColorizer = {
            param($item, $rowIndex)
            
            $colors = (Get-CurrentTheme).Colors
            
            if ($item.Status -eq "Completed") {
                return $colors.Completed
            }
            
            # Check due date
            if (-not [string]::IsNullOrWhiteSpace($item.DueDate)) {
                try {
                    $dueDate = [datetime]::ParseExact($item.DueDate, "yyyyMMdd", $null)
                    $today = (Get-Date).Date
                    $daysUntilDue = ($dueDate - $today).Days
                    
                    if ($daysUntilDue -lt 0) {
                        return $colors.Overdue
                    } elseif ($daysUntilDue -le 7) {
                        return $colors.DueSoon
                    }
                } catch {
                    # Invalid date format, use default color
                }
            }
            
            # Use Importance for color if not already colored by due date
            switch ($item.Importance) {
                "High" { return $colors.Warning }
                default { return $colors.Normal }
            }
        }
        
        # Display the table
        Show-Table -Data $sortedTodos -Columns $columnsToShow -Headers $tableHeaders -Formatters $formatters -RowColorizer $rowColorizer
        
        Write-AppLog "Displayed filtered todo list (Matching items: $($todos.Count))" -Level INFO
        
        Read-Host "Press Enter to continue..."
        return $sortedTodos
    } catch {
        Handle-Error -ErrorRecord $_ -Context "Listing filtered todo items" -Continue
        Read-Host "Press Enter to continue..."
        return @()
    }
}

# Create new todo item
<#
.SYNOPSIS
    Creates a new todo item with numeric navigation.
.DESCRIPTION
    Creates a new todo item with the specified properties using numeric navigation.
.PARAMETER TodoData
    Optional hashtable containing todo data fields.
.PARAMETER IsSilent
    If specified, no user prompts are displayed.
.EXAMPLE
    New-TrackerTodoItem
#>
function New-TrackerTodoItem {
    [CmdletBinding()]
    param(
        [hashtable]$TodoData,
        [switch]$IsSilent
    )
    
    if (-not $IsSilent) {
        Render-Header -Title "Create New Todo Item"
    }
    
    try {
        $config = Get-AppConfig
        $newTodo = @{}
        
        # If todo data is provided, use it. Otherwise, prompt for input.
        if ($TodoData -and $TodoData.Count -gt 0) {
            $newTodo = $TodoData
        } else {
            # Get project nickname if applicable
            $projectNickname = ""
            $useProject = Read-UserInput -Prompt "Associate with a project? (1=Yes, 2=No, 0=Cancel)" -NumericOnly
            
            if ($useProject -eq "CANCEL" -or $useProject -eq "0") {
                if (-not $IsSilent) {
                    $colors = (Get-CurrentTheme).Colors
                    Write-ColorText "Todo creation cancelled." -ForegroundColor $colors.Warning
                    Read-Host "Press Enter to continue..."
                }
                return $false
            }
            
            if ($useProject -eq "1") {
                # Get available projects
                $projects = @(Get-EntityData -FilePath $config.ProjectsFullPath | Where-Object { $_.Status -ne "Closed" })
                
                if ($projects.Count -eq 0) {
                    $colors = (Get-CurrentTheme).Colors
                    Write-ColorText "No active projects found." -ForegroundColor $colors.Warning
                    Read-Host "Press Enter to continue..."
                    return $false
                }
                
                # Display numbered project list for selection
                Write-Host "Select project by number (0 to cancel):" -ForegroundColor $script:colors.Accent2
                
                for ($i = 0; $i -lt $projects.Count; $i++) {
                    $projectNum = $i + 1
                    Write-Host "[$projectNum] $($projects[$i].Nickname) - $($projects[$i].FullProjectName)" -ForegroundColor $script:colors.Normal
                }
                
                $selection = Read-UserInput -Prompt "Enter project number" -NumericOnly
                
                if ($selection -eq "CANCEL" -or $selection -eq "0") {
                    if (-not $IsSilent) {
                        $colors = (Get-CurrentTheme).Colors
                        Write-ColorText "Todo creation cancelled." -ForegroundColor $colors.Warning
                        Read-Host "Press Enter to continue..."
                    }
                    return $false
                }
                
                # Convert selection to int and check range
                try {
                    $index = [int]$selection - 1
                    if ($index -lt 0 -or $index -ge $projects.Count) {
                        Write-ColorText "Invalid selection." -ForegroundColor $script:colors.Error
                        Read-Host "Press Enter to continue..."
                        return $false
                    }
                    
                    $projectNickname = $projects[$index].Nickname
                } catch {
                    Write-ColorText "Invalid selection." -ForegroundColor $script:colors.Error
                    Read-Host "Press Enter to continue..."
                    return $false
                }
            }
            
            # Get task description
            $taskDescription = Read-UserInput -Prompt "Enter task description"
            
            if ($taskDescription -eq "CANCEL") {
                if (-not $IsSilent) {
                    $colors = (Get-CurrentTheme).Colors
                    Write-ColorText "Todo creation cancelled." -ForegroundColor $colors.Warning
                    Read-Host "Press Enter to continue..."
                }
                return $false
            }
            
            if ([string]::IsNullOrWhiteSpace($taskDescription)) {
                if (-not $IsSilent) {
                    $colors = (Get-CurrentTheme).Colors
                    Write-ColorText "Task description cannot be empty." -ForegroundColor $colors.Error
                    Read-Host "Press Enter to continue..."
                }
                return $false
            }
            
            # Use a simpler approach for importance selection
            $colors = (Get-CurrentTheme).Colors
            Write-ColorText "Select Importance:" -ForegroundColor $colors.Accent2
            Write-ColorText "[1] High" -ForegroundColor $colors.Error
            Write-ColorText "[2] Normal" -ForegroundColor $colors.Warning
            Write-ColorText "[3] Low" -ForegroundColor $colors.Normal
            Write-ColorText "[0] Cancel" -ForegroundColor $colors.Accent2
            
            $importanceChoice = Read-UserInput -Prompt "Enter importance" -NumericOnly
            
            if ($importanceChoice -eq "CANCEL" -or $importanceChoice -eq "0") {
                if (-not $IsSilent) {
                    Write-ColorText "Todo creation cancelled." -ForegroundColor $colors.Warning
                    Read-Host "Press Enter to continue..."
                }
                return $false
            }
            
            $importance = "Normal" # Default
            switch ($importanceChoice) {
                "1" { $importance = "High" }
                "2" { $importance = "Normal" }
                "3" { $importance = "Low" }
                default { $importance = "Normal" }
            }
            
            # Get due date
            $dueDate = Get-DateInput -PromptText "Enter due date" -AllowEmptyForToday -AllowCancel
            
            if ($null -eq $dueDate) {
                if (-not $IsSilent) {
                    $colors = (Get-CurrentTheme).Colors
                    Write-ColorText "Todo creation cancelled." -ForegroundColor $colors.Warning
                    Read-Host "Press Enter to continue..."
                }
                return $false
            }
            
            # Construct the new todo item
            $newTodo = @{
                ID = New-ID -Format "Full"
                Nickname = $projectNickname
                TaskDescription = $taskDescription
                Importance = $importance
                DueDate = $dueDate
                Status = "Pending"
                CreatedDate = (Get-Date).ToString("yyyyMMdd")
                CompletedDate = ""
            }
        }
        
        # Ensure required fields have values
        if (-not $newTodo.ContainsKey("ID") -or [string]::IsNullOrWhiteSpace($newTodo.ID)) {
            $newTodo.ID = New-ID -Format "Full"
        }
        
        if (-not $newTodo.ContainsKey("Status") -or [string]::IsNullOrWhiteSpace($newTodo.Status)) {
            $newTodo.Status = "Pending"
        }
        
        if (-not $newTodo.ContainsKey("CreatedDate") -or [string]::IsNullOrWhiteSpace($newTodo.CreatedDate)) {
            $newTodo.CreatedDate = (Get-Date).ToString("yyyyMMdd")
        }
        
        if (-not $newTodo.ContainsKey("CompletedDate")) {
            $newTodo.CompletedDate = ""
        }
        
        # Validate required fields
        if (-not $newTodo.ContainsKey("TaskDescription") -or [string]::IsNullOrWhiteSpace($newTodo.TaskDescription)) {
            if (-not $IsSilent) {
                $colors = (Get-CurrentTheme).Colors
                Write-ColorText "Task description is required." -ForegroundColor $colors.Error
                Read-Host "Press Enter to continue..."
            }
            return $false
        }
        
        if (-not $newTodo.ContainsKey("DueDate") -or [string]::IsNullOrWhiteSpace($newTodo.DueDate)) {
            if (-not $IsSilent) {
                $colors = (Get-CurrentTheme).Colors
                Write-ColorText "Due date is required." -ForegroundColor $colors.Error
                Read-Host "Press Enter to continue..."
            }
            return $false
        }
        
        if (-not $newTodo.ContainsKey("Importance") -or [string]::IsNullOrWhiteSpace($newTodo.Importance)) {
            $newTodo.Importance = "Normal" # Default to Normal if not specified
        }
        
        # Save the new todo
        $todos = @(Get-EntityData -FilePath $config.TodosFullPath)
        $updatedTodos = $todos + [PSCustomObject]$newTodo
        
        if (Save-EntityData -Data $updatedTodos -FilePath $config.TodosFullPath) {
            Write-AppLog "Created new todo item: $($newTodo.TaskDescription)" -Level INFO
            
            if (-not $IsSilent) {
                $colors = (Get-CurrentTheme).Colors
                Write-ColorText "Todo item created successfully!" -ForegroundColor $colors.Success
                Read-Host "Press Enter to continue..."
            }
            
            return $true
        } else {
            if (-not $IsSilent) {
                $colors = (Get-CurrentTheme).Colors
                Write-ColorText "Failed to save todo item." -ForegroundColor $colors.Error
                Read-Host "Press Enter to continue..."
            }
            return $false
        }
    } catch {
        Handle-Error -ErrorRecord $_ -Context "Creating new todo item" -Continue
        
        if (-not $IsSilent) {
            Read-Host "Press Enter to continue..."
        }
        
        return $false
    }
}
# Get todo item by ID
function Get-TrackerTodoItem {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$ID
    )
    
    try {
        $config = Get-AppConfig
        $todos = @(Get-EntityData -FilePath $config.TodosFullPath)
        return $todos | Where-Object { $_.ID -eq $ID } | Select-Object -First 1
    } catch {
        Handle-Error -ErrorRecord $_ -Context "Getting todo item" -Continue
        return $null
    }
}

# Update existing todo item
<#
.SYNOPSIS
    Updates an existing todo item with numeric navigation.
.DESCRIPTION
    Updates an existing todo item using numeric input for all selection and navigation.
.PARAMETER ID
    The ID of the todo item to update.
.PARAMETER UpdatedFields
    Optional hashtable containing updated todo data fields.
.PARAMETER IsSilent
    If specified, no user prompts are displayed.
.EXAMPLE
    Update-TrackerTodoItem -ID "12345"
#>
function Update-TrackerTodoItem {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$ID,
        
        [hashtable]$UpdatedFields,
        
        [switch]$IsSilent
    )
    
    if (-not $IsSilent) {
        Render-Header -Title "Update Todo Item"
    }
    
    try {
        $config = Get-AppConfig
        $todos = @(Get-EntityData -FilePath $config.TodosFullPath)
        $colors = (Get-CurrentTheme).Colors
        
        # Find the todo item
        $todoItem = $todos | Where-Object { $_.ID -eq $ID } | Select-Object -First 1
        
        if (-not $todoItem) {
            if (-not $IsSilent) {
                Write-ColorText "Todo item with ID '$ID' not found." -ForegroundColor $colors.Error
                Read-Host "Press Enter to continue..."
            }
            return $false
        }
        
        # If fields are provided, use them. Otherwise, prompt for input.
        if ($UpdatedFields -and $UpdatedFields.Count -gt 0) {
            # Apply the provided updates
            foreach ($key in $UpdatedFields.Keys) {
                if ($todoItem.PSObject.Properties.Name -contains $key) {
                    $todoItem.$key = $UpdatedFields[$key]
                }
            }
        } else {
            # Interactive update mode
            if (-not $IsSilent) {
                Write-ColorText "Updating Todo: $($todoItem.TaskDescription)" -ForegroundColor $colors.Accent2
                Write-ColorText "Enter new value or press Enter to keep current. Enter 0 to cancel." -ForegroundColor $colors.Accent2
            }
            
            # Update task description
            $newDescription = Read-UserInput -Prompt "Task Description (current: $($todoItem.TaskDescription))"
            if ($newDescription -eq "CANCEL") {
                if (-not $IsSilent) {
                    Write-ColorText "Update cancelled." -ForegroundColor $colors.Warning
                    Read-Host "Press Enter to continue..."
                }
                return $false
            }
            if (-not [string]::IsNullOrWhiteSpace($newDescription) -and $newDescription -ne $todoItem.TaskDescription) {
                $todoItem.TaskDescription = $newDescription
            }
            
            # Update project association
            $updateProject = Read-UserInput -Prompt "Update project association? (1=Yes, 2=No, 0=Cancel)" -NumericOnly
            if ($updateProject -eq "CANCEL" -or $updateProject -eq "0") {
                if (-not $IsSilent) {
                    Write-ColorText "Update cancelled." -ForegroundColor $colors.Warning
                    Read-Host "Press Enter to continue..."
                }
                return $false
            }
            
            if ($updateProject -eq "1") {
                $useProject = Read-UserInput -Prompt "Associate with a project? (1=Yes, 2=No, 0=Cancel)" -NumericOnly
                if ($useProject -eq "CANCEL" -or $useProject -eq "0") {
                    if (-not $IsSilent) {
                        Write-ColorText "Update cancelled." -ForegroundColor $colors.Warning
                        Read-Host "Press Enter to continue..."
                    }
                    return $false
                }
                
                if ($useProject -eq "1") {
                    # Get available projects
                    $projects = @(Get-EntityData -FilePath $config.ProjectsFullPath | Where-Object { $_.Status -ne "Closed" })
                    
                    if ($projects.Count -eq 0) {
                        Write-ColorText "No active projects found." -ForegroundColor $colors.Warning
                        Read-Host "Press Enter to continue..."
                        return $false
                    }
                    
                    # Display numbered project list for selection
                    Write-Host "Select project by number (0 to cancel):" -ForegroundColor $script:colors.Accent2
                    
                    for ($i = 0; $i -lt $projects.Count; $i++) {
                        $projectNum = $i + 1
                        $isCurrentProject = $projects[$i].Nickname -eq $todoItem.Nickname
                        $projectText = "$($projects[$i].Nickname) - $($projects[$i].FullProjectName)"
                        
                        if ($isCurrentProject) {
                            Write-Host "[$projectNum] $projectText (current)" -ForegroundColor $script:colors.Accent2
                        } else {
                            Write-Host "[$projectNum] $projectText" -ForegroundColor $script:colors.Normal
                        }
                    }
                    
                    $selection = Read-UserInput -Prompt "Enter project number" -NumericOnly
                    
                    if ($selection -eq "CANCEL" -or $selection -eq "0") {
                        if (-not $IsSilent) {
                            Write-ColorText "Update cancelled." -ForegroundColor $colors.Warning
                            Read-Host "Press Enter to continue..."
                        }
                        return $false
                    }
                    
                    # Convert selection to int and check range
                    try {
                        $index = [int]$selection - 1
                        if ($index -lt 0 -or $index -ge $projects.Count) {
                            Write-ColorText "Invalid selection." -ForegroundColor $script:colors.Error
                            Read-Host "Press Enter to continue..."
                            return $false
                        }
                        
                        $todoItem.Nickname = $projects[$index].Nickname
                    } catch {
                        Write-ColorText "Invalid selection." -ForegroundColor $script:colors.Error
                        Read-Host "Press Enter to continue..."
                        return $false
                    }
                } else {
                    $todoItem.Nickname = ""
                }
            }
            
            # Update importance
            $updateImportance = Read-UserInput -Prompt "Update importance? (1=Yes, 2=No, 0=Cancel)" -NumericOnly
            if ($updateImportance -eq "CANCEL" -or $updateImportance -eq "0") {
                if (-not $IsSilent) {
                    Write-ColorText "Update cancelled." -ForegroundColor $colors.Warning
                    Read-Host "Press Enter to continue..."
                }
                return $false
            }
            
            if ($updateImportance -eq "1") {
                # Direct importance selection
                Write-ColorText "Select Importance:" -ForegroundColor $colors.Accent2
                Write-ColorText "[1] High" -ForegroundColor $colors.Error 
                Write-ColorText "[2] Normal" -ForegroundColor $colors.Warning
                Write-ColorText "[3] Low" -ForegroundColor $colors.Normal
                Write-ColorText "[0] Cancel" -ForegroundColor $colors.Accent2
                
                $importanceChoice = Read-UserInput -Prompt "Enter importance" -NumericOnly
                
                if ($importanceChoice -eq "CANCEL" -or $importanceChoice -eq "0") {
                    if (-not $IsSilent) {
                        Write-ColorText "Update cancelled." -ForegroundColor $colors.Warning
                        Read-Host "Press Enter to continue..."
                    }
                    return $false
                }
                
                switch ($importanceChoice) {
                    "1" { $todoItem.Importance = "High" }
                    "2" { $todoItem.Importance = "Normal" }
                    "3" { $todoItem.Importance = "Low" }
                    default { 
                        Write-ColorText "Invalid choice, keeping current importance." -ForegroundColor $colors.Warning
                    }
                }
            }
            
            # Update due date
            $updateDueDate = Read-UserInput -Prompt "Update due date? (1=Yes, 2=No, 0=Cancel)" -NumericOnly
            if ($updateDueDate -eq "CANCEL" -or $updateDueDate -eq "0") {
                if (-not $IsSilent) {
                    Write-ColorText "Update cancelled." -ForegroundColor $colors.Warning
                    Read-Host "Press Enter to continue..."
                }
                return $false
            }
            
            if ($updateDueDate -eq "1") {
                $currentDueDate = Convert-InternalDateToDisplay -InternalDate $todoItem.DueDate
                $dueDate = Get-DateInput -PromptText "Enter due date" -DefaultValue $todoItem.DueDate -AllowCancel
                
                if ($null -eq $dueDate) {
                    if (-not $IsSilent) {
                        Write-ColorText "Update cancelled." -ForegroundColor $colors.Warning
                        Read-Host "Press Enter to continue..."
                    }
                    return $false
                }
                
                $todoItem.DueDate = $dueDate
            }
            
            # Update status
            $updateStatus = Read-UserInput -Prompt "Update status? (1=Yes, 2=No, 0=Cancel)" -NumericOnly
            if ($updateStatus -eq "CANCEL" -or $updateStatus -eq "0") {
                if (-not $IsSilent) {
                    Write-ColorText "Update cancelled." -ForegroundColor $colors.Warning
                    Read-Host "Press Enter to continue..."
                }
                return $false
            }
            
            if ($updateStatus -eq "1") {
                # Direct status selection
                Write-ColorText "Select Status:" -ForegroundColor $colors.Accent2
                Write-ColorText "[1] Pending" -ForegroundColor $colors.Normal
                Write-ColorText "[2] In Progress" -ForegroundColor $colors.Accent1
                Write-ColorText "[3] Completed" -ForegroundColor $colors.Success
                Write-ColorText "[4] Deferred" -ForegroundColor $colors.Warning
                Write-ColorText "[0] Cancel" -ForegroundColor $colors.Accent2
                
                $statusChoice = Read-UserInput -Prompt "Enter status" -NumericOnly
                
                if ($statusChoice -eq "CANCEL" -or $statusChoice -eq "0") {
                    if (-not $IsSilent) {
                        Write-ColorText "Update cancelled." -ForegroundColor $colors.Warning
                        Read-Host "Press Enter to continue..."
                    }
                    return $false
                }
                
                $newStatus = $todoItem.Status
                switch ($statusChoice) {
                    "1" { $newStatus = "Pending" }
                    "2" { $newStatus = "In Progress" }
                    "3" { $newStatus = "Completed" }
                    "4" { $newStatus = "Deferred" }
                    default { 
                        Write-ColorText "Invalid choice, keeping current status." -ForegroundColor $colors.Warning
                    }
                }
                
                $todoItem.Status = $newStatus
                
                # If status changed to Completed, update CompletedDate
                if ($newStatus -eq "Completed" -and [string]::IsNullOrWhiteSpace($todoItem.CompletedDate)) {
                    $todoItem.CompletedDate = (Get-Date).ToString("yyyyMMdd")
                } elseif ($newStatus -ne "Completed") {
                    $todoItem.CompletedDate = ""
                }
            }
        }
        
        # Save the updated todos
        $updatedTodos = @()
        foreach ($todo in $todos) {
            if ($todo.ID -eq $ID) {
                $updatedTodos += $todoItem
            } else {
                $updatedTodos += $todo
            }
        }
        
        if (Save-EntityData -Data $updatedTodos -FilePath $config.TodosFullPath) {
            Write-AppLog "Updated todo item: $($todoItem.TaskDescription)" -Level INFO
            
            if (-not $IsSilent) {
                Write-ColorText "Todo item updated successfully!" -ForegroundColor $colors.Success
                Read-Host "Press Enter to continue..."
            }
            
            return $true
        } else {
            if (-not $IsSilent) {
                Write-ColorText "Failed to save updated todo item." -ForegroundColor $colors.Error
                Read-Host "Press Enter to continue..."
            }
            return $false
        }
    } catch {
        Handle-Error -ErrorRecord $_ -Context "Updating todo item" -Continue
        
        if (-not $IsSilent) {
            Read-Host "Press Enter to continue..."
        }
        
        return $false
    }
}

<#
.SYNOPSIS
    Marks a todo item as completed with numeric confirmation.
.DESCRIPTION
    Marks a todo item as completed and updates its completion date.
.PARAMETER ID
    The ID of the todo item to complete.
.PARAMETER IsSilent
    If specified, no user prompts are displayed.
.EXAMPLE
    Complete-TrackerTodoItem -ID "12345"
#>
function Complete-TrackerTodoItem {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$ID,
        
        [switch]$IsSilent
    )
    
    if (-not $IsSilent) {
        Render-Header -Title "Complete Todo Item"
    }
    
    try {
        $config = Get-AppConfig
        $todos = @(Get-EntityData -FilePath $config.TodosFullPath)
        $colors = (Get-CurrentTheme).Colors
        
        # Find the todo item
        $todoItem = $todos | Where-Object { $_.ID -eq $ID } | Select-Object -First 1
        
        if (-not $todoItem) {
            if (-not $IsSilent) {
                Write-ColorText "Todo item with ID '$ID' not found." -ForegroundColor $colors.Error
                Read-Host "Press Enter to continue..."
            }
            return $false
        }
        
        # Skip if already completed
        if ($todoItem.Status -eq "Completed") {
            if (-not $IsSilent) {
                Write-ColorText "Todo item is already marked as completed." -ForegroundColor $colors.Warning
                Read-Host "Press Enter to continue..."
            }
            return $true
        }
        
        # Get confirmation
        if (-not $IsSilent) {
            $confirm = Get-UserConfirmation -Message "Are you sure you want to mark this todo as completed?"
            
            if ($confirm -eq "Cancel") {
                Write-ColorText "Operation cancelled." -ForegroundColor $colors.Warning
                Read-Host "Press Enter to continue..."
                return $false
            }
            
            if ($confirm -eq "No") {
                Write-ColorText "Operation cancelled." -ForegroundColor $colors.Warning
                Read-Host "Press Enter to continue..."
                return $false
            }
        }
        
        # Update status and completion date
        $todoItem.Status = "Completed"
        $todoItem.CompletedDate = (Get-Date).ToString("yyyyMMdd")
        
        # Save the updated todos
        $updatedTodos = @()
        foreach ($todo in $todos) {
            if ($todo.ID -eq $ID) {
                $updatedTodos += $todoItem
            } else {
                $updatedTodos += $todo
            }
        }
        
        if (Save-EntityData -Data $updatedTodos -FilePath $config.TodosFullPath) {
            Write-AppLog "Completed todo item: $($todoItem.TaskDescription)" -Level INFO
            
            if (-not $IsSilent) {
                Write-ColorText "Todo item marked as completed!" -ForegroundColor $colors.Success
                Read-Host "Press Enter to continue..."
            }
            
            return $true
        } else {
            if (-not $IsSilent) {
                Write-ColorText "Failed to save updated todo item." -ForegroundColor $colors.Error
                Read-Host "Press Enter to continue..."
            }
            return $false
        }
    } catch {
        Handle-Error -ErrorRecord $_ -Context "Completing todo item" -Continue
        
        if (-not $IsSilent) {
            Read-Host "Press Enter to continue..."
        }
        
        return $false
    }
}


<#
.SYNOPSIS
    Removes a todo item with numeric confirmation.
.DESCRIPTION
    Deletes a todo item from the todo list with numeric confirmation.
.PARAMETER ID
    The ID of the todo item to remove.
.PARAMETER IsSilent
    If specified, no user prompts are displayed.
.PARAMETER Force
    If specified, no confirmation is required.
.EXAMPLE
    Remove-TrackerTodoItem -ID "12345"
#>
function Remove-TrackerTodoItem {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$ID,
        
        [switch]$IsSilent,
        
        [switch]$Force
    )
    
    if (-not $IsSilent) {
        Render-Header -Title "Remove Todo Item"
    }
    
    try {
        $config = Get-AppConfig
        $todos = @(Get-EntityData -FilePath $config.TodosFullPath)
        $colors = (Get-CurrentTheme).Colors
        
        # Find the todo item
        $todoItem = $todos | Where-Object { $_.ID -eq $ID } | Select-Object -First 1
        
        if (-not $todoItem) {
            if (-not $IsSilent) {
                Write-ColorText "Todo item with ID '$ID' not found." -ForegroundColor $colors.Error
                Read-Host "Press Enter to continue..."
            }
            return $false
        }
        
        # Confirm deletion unless Force is specified
        if (-not $Force -and -not $IsSilent) {
            Write-ColorText "Are you sure you want to delete this todo item?" -ForegroundColor $colors.Warning
            Write-ColorText "Task: $($todoItem.TaskDescription)" -ForegroundColor $colors.Normal
            
            $confirm = Get-UserConfirmation -Message "Are you sure you want to delete this todo item?"
            
            if ($confirm -eq "Cancel") {
                Write-ColorText "Deletion cancelled." -ForegroundColor $colors.Warning
                Read-Host "Press Enter to continue..."
                return $false
            }
            
            if ($confirm -eq "No") {
                Write-ColorText "Deletion cancelled." -ForegroundColor $colors.Warning
                Read-Host "Press Enter to continue..."
                return $false
            }
        }
        
        # Remove the todo item
        $updatedTodos = $todos | Where-Object { $_.ID -ne $ID }
        
        if (Save-EntityData -Data $updatedTodos -FilePath $config.TodosFullPath) {
            Write-AppLog "Removed todo item: $($todoItem.TaskDescription)" -Level INFO
            
            if (-not $IsSilent) {
                Write-ColorText "Todo item removed successfully!" -ForegroundColor $colors.Success
                Read-Host "Press Enter to continue..."
            }
            
            return $true
        } else {
            if (-not $IsSilent) {
                Write-ColorText "Failed to remove todo item." -ForegroundColor $colors.Error
                Read-Host "Press Enter to continue..."
            }
            return $false
        }
    } catch {
        Handle-Error -ErrorRecord $_ -Context "Removing todo item" -Continue
        
        if (-not $IsSilent) {
            Read-Host "Press Enter to continue..."
        }
        
        return $false
    }
}


# Export functions
#Export-ModuleMember -Function Show-TodoList, Show-FilteredTodoList, New-TrackerTodoItem, 
#                     Update-TrackerTodoItem, Complete-TrackerTodoItem, Remove-TrackerTodoItem, 
#                     Get-TrackerTodoItem, Show-TodoMenu
#
# Fix for ProjectTracker.Todos.psm1
# Add this line at the end of ProjectTracker.Todos.psm1 if it's not already there
# It looks like this might already be properly exported, but including it for completeness
Export-ModuleMember -Function Show-TodoList, Show-FilteredTodoList, New-TrackerTodoItem, 
    Update-TrackerTodoItem, Complete-TrackerTodoItem, Remove-TrackerTodoItem, 
    Get-TrackerTodoItem, Show-TodoMenu