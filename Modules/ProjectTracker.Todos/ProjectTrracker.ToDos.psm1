# ProjectTracker.Todos.psm1
# Todo Management module for Project Tracker

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
            $useProject = Read-UserInput -Prompt "Associate with a project? (y/n)" -DefaultValue "n"
            
            if ($useProject -eq "y") {
                # Get available projects
                $projects = @(Get-EntityData -FilePath $config.ProjectsFullPath | Where-Object { $_.Status -ne "Closed" })
                
                if ($projects.Count -eq 0) {
                    $colors = (Get-CurrentTheme).Colors
                    Write-ColorText "No active projects found." -ForegroundColor $colors.Warning
                    Read-Host "Press Enter to continue..."
                    return $false
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
                            return $selectedProject.Nickname 
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
                
                $projectNickname = Show-DynamicMenu -Title "Select Project" -MenuItems $projectMenuItems
                
                if ($null -eq $projectNickname) {
                    if (-not $IsSilent) {
                        $colors = (Get-CurrentTheme).Colors
                        Write-ColorText "Todo creation cancelled." -ForegroundColor $colors.Warning
                        Read-Host "Press Enter to continue..."
                    }
                    return $false
                }
            }
            
            # Get task description
            $taskDescription = Read-UserInput -Prompt "Enter task description"
            
            if ([string]::IsNullOrWhiteSpace($taskDescription)) {
                if (-not $IsSilent) {
                    $colors = (Get-CurrentTheme).Colors
                    Write-ColorText "Task description cannot be empty." -ForegroundColor $colors.Error
                    Read-Host "Press Enter to continue..."
                }
                return $false
            }
            
            # Get importance
            $importanceMenu = @()
            $importanceMenu += @{ Type = "header"; Text = "Select Importance" }
            $importanceMenu += @{ Type = "option"; Key = "1"; Text = "High"; Function = { return "High" } }
            $importanceMenu += @{ Type = "option"; Key = "2"; Text = "Normal"; Function = { return "Normal" }; IsHighlighted = $true }
            $importanceMenu += @{ Type = "option"; Key = "3"; Text = "Low"; Function = { return "Low" } }
            $importanceMenu += @{ Type = "separator" }
            $importanceMenu += @{ Type = "option"; Key = "0"; Text = "Cancel"; Function = { return $null }; IsExit = $true }
            
            $importance = Show-DynamicMenu -Title "Select Importance" -MenuItems $importanceMenu
            
            if ($null -eq $importance) {
                if (-not $IsSilent) {
                    $colors = (Get-CurrentTheme).Colors
                    Write-ColorText "Todo creation cancelled." -ForegroundColor $colors.Warning
                    Read-Host "Press Enter to continue..."
                }
                return $false
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
                Write-ColorText "Enter new value or press Enter to keep current. Enter '0' to cancel." -ForegroundColor $colors.Accent2
            }
            
            # Update task description
            $newDescription = Read-UserInput -Prompt "Task Description" -DefaultValue $todoItem.TaskDescription
            if ($newDescription -eq "0") { return $false }
            if (-not [string]::IsNullOrWhiteSpace($newDescription) -and $newDescription -ne $todoItem.TaskDescription) {
                $todoItem.TaskDescription = $newDescription
            }
            
            # Update project association
            $updateProject = Read-UserInput -Prompt "Update project association? (y/n)" -DefaultValue "n"
            if ($updateProject -eq "0") { return $false }
            
            if ($updateProject -eq "y") {
                $useProject = Read-UserInput -Prompt "Associate with a project? (y/n)" -DefaultValue $(if ([string]::IsNullOrWhiteSpace($todoItem.Nickname)) { "n" } else { "y" })
                if ($useProject -eq "0") { return $false }
                
                if ($useProject -eq "y") {
                    # Get available projects
                    $projects = @(Get-EntityData -FilePath $config.ProjectsFullPath | Where-Object { $_.Status -ne "Closed" })
                    
                    if ($projects.Count -eq 0) {
                        Write-ColorText "No active projects found." -ForegroundColor $colors.Warning
                        Read-Host "Press Enter to continue..."
                        return $false
                    }
                    
                    # Display project selection menu
                    $projectMenuItems = @()
                    $projectMenuItems += @{ Type = "header"; Text = "Select Project" }
                    
                    $index = 1
                    foreach ($project in $projects | Sort-Object Nickname) {
                        $isHighlighted = $project.Nickname -eq $todoItem.Nickname
                        
                        $projectMenuItems += @{
                            Type = "option"
                            Key = "$index"
                            Text = "$($project.Nickname) - $($project.FullProjectName)"
                            Function = { 
                                param($selectedProject)
                                return $selectedProject.Nickname 
                            }
                            Args = @($project)
                            IsHighlighted = $isHighlighted
                        }
                        $index++
                    }
                    
                    $projectMenuItems += @{ Type = "separator" }
                    $projectMenuItems += @{
                        Type = "option"
                        Key = "0"
                        Text = "Cancel"
                        Function = { return "CANCEL" }
                        IsExit = $true
                    }
                    
                    $projectNickname = Show-DynamicMenu -Title "Select Project" -MenuItems $projectMenuItems
                    
                    if ($projectNickname -eq "CANCEL") {
                        if (-not $IsSilent) {
                            Write-ColorText "Update cancelled." -ForegroundColor $colors.Warning
                            Read-Host "Press Enter to continue..."
                        }
                        return $false
                    }
                    
                    $todoItem.Nickname = $projectNickname
                } else {
                    $todoItem.Nickname = ""
                }
            }
            
            # Update importance
            $updateImportance = Read-UserInput -Prompt "Update importance? (y/n)" -DefaultValue "n"
            if ($updateImportance -eq "0") { return $false }
            
            if ($updateImportance -eq "y") {
                $importanceMenu = @()
                $importanceMenu += @{ Type = "header"; Text = "Select Importance" }
                $importanceMenu += @{ Type = "option"; Key = "1"; Text = "High"; Function = { return "High" }; IsHighlighted = $todoItem.Importance -eq "High" }
                $importanceMenu += @{ Type = "option"; Key = "2"; Text = "Normal"; Function = { return "Normal" }; IsHighlighted = $todoItem.Importance -eq "Normal" }
                $importanceMenu += @{ Type = "option"; Key = "3"; Text = "Low"; Function = { return "Low" }; IsHighlighted = $todoItem.Importance -eq "Low" }
                $importanceMenu += @{ Type = "separator" }
                $importanceMenu += @{ Type = "option"; Key = "0"; Text = "Cancel"; Function = { return "CANCEL" }; IsExit = $true }
                
                $importance = Show-DynamicMenu -Title "Select Importance" -MenuItems $importanceMenu
                
                if ($importance -eq "CANCEL") {
                    if (-not $IsSilent) {
                        Write-ColorText "Update cancelled." -ForegroundColor $colors.Warning
                        Read-Host "Press Enter to continue..."
                    }
                    return $false
                }
                
                $todoItem.Importance = $importance
            }
            
            # Update due date
            $updateDueDate = Read-UserInput -Prompt "Update due date? (y/n)" -DefaultValue "n"
            if ($updateDueDate -eq "0") { return $false }
            
            if ($updateDueDate -eq "y") {
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
            $updateStatus = Read-UserInput -Prompt "Update status? (y/n)" -DefaultValue "n"
            if ($updateStatus -eq "0") { return $false }
            
            if ($updateStatus -eq "y") {
                $statusMenu = @()
                $statusMenu += @{ Type = "header"; Text = "Select Status" }
                $statusMenu += @{ Type = "option"; Key = "1"; Text = "Pending"; Function = { return "Pending" }; IsHighlighted = $todoItem.Status -eq "Pending" }
                $statusMenu += @{ Type = "option"; Key = "2"; Text = "In Progress"; Function = { return "In Progress" }; IsHighlighted = $todoItem.Status -eq "In Progress" }
                $statusMenu += @{ Type = "option"; Key = "3"; Text = "Completed"; Function = { return "Completed" }; IsHighlighted = $todoItem.Status -eq "Completed" }
                $statusMenu += @{ Type = "option"; Key = "4"; Text = "Deferred"; Function = { return "Deferred" }; IsHighlighted = $todoItem.Status -eq "Deferred" }
                $statusMenu += @{ Type = "separator" }
                $statusMenu += @{ Type = "option"; Key = "0"; Text = "Cancel"; Function = { return "CANCEL" }; IsExit = $true }
                
                $status = Show-DynamicMenu -Title "Select Status" -MenuItems $statusMenu
                
                if ($status -eq "CANCEL") {
                    if (-not $IsSilent) {
                        Write-ColorText "Update cancelled." -ForegroundColor $colors.Warning
                        Read-Host "Press Enter to continue..."
                    }
                    return $false
                }
                
                $todoItem.Status = $status
                
                # If status changed to Completed, update CompletedDate
                if ($status -eq "Completed" -and [string]::IsNullOrWhiteSpace($todoItem.CompletedDate)) {
                    $todoItem.CompletedDate = (Get-Date).ToString("yyyyMMdd")
                } elseif ($status -ne "Completed") {
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

# Complete todo item
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

# Remove todo item
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
            
            $confirm = Read-UserInput -Prompt "Type 'yes' to confirm"
            
            if ($confirm -ne "yes") {
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

# Show Todo Management Menu
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
            
            # Prompt for todo ID
            $todoID = Read-UserInput -Prompt "Enter Todo ID to update (or 0 to cancel)"
            
            if ($todoID -eq "0") {
                $colors = (Get-CurrentTheme).Colors
                Write-ColorText "Update cancelled." -ForegroundColor $colors.Warning
                Read-Host "Press Enter to continue..."
                return $null
            }
            
            # Update the todo
            Update-TrackerTodoItem -ID $todoID
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
            
            # Prompt for todo ID
            $todoID = Read-UserInput -Prompt "Enter Todo ID to mark as completed (or 0 to cancel)"
            
            if ($todoID -eq "0") {
                $colors = (Get-CurrentTheme).Colors
                Write-ColorText "Operation cancelled." -ForegroundColor $colors.Warning
                Read-Host "Press Enter to continue..."
                return $null
            }
            
            # Complete the todo
            Complete-TrackerTodoItem -ID $todoID
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
            
            # Prompt for todo ID
            $todoID = Read-UserInput -Prompt "Enter Todo ID to delete (or 0 to cancel)"
            
            if ($todoID -eq "0") {
                $colors = (Get-CurrentTheme).Colors
                Write-ColorText "Deletion cancelled." -ForegroundColor $colors.Warning
                Read-Host "Press Enter to continue..."
                return $null
            }
            
            # Delete the todo
            Remove-TrackerTodoItem -ID $todoID
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
                        return $selectedProject.Nickname 
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
            
            $projectNickname = Show-DynamicMenu -Title "Select Project" -MenuItems $projectMenuItems
            
            if ($null -eq $projectNickname) {
                return $null
            }
            
            # Show todos for the selected project
            Show-FilteredTodoList -Nickname $projectNickname
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
        Function = { return $true }
        IsExit = $false  # Changed to false to prevent exiting application
        Type = "option"
    }
    
    Show-DynamicMenu -Title "Todo Management" -MenuItems $todoMenuItems
}

# Export functions
#Export-ModuleMember -Function Show-TodoList, Show-FilteredTodoList, New-TrackerTodoItem, 
#                     Update-TrackerTodoItem, Complete-TrackerTodoItem, Remove-TrackerTodoItem, 
#                     Get-TrackerTodoItem, Show-TodoMenu
#
# Fix for ProjectTracker.Todos.psm1
# Add this line at the end of ProjectTracker.Todos.psm1 if it's not already there
# It looks like this might already be properly exported, but including it for completeness
Export-ModuleMember -Function Show-TodoList, Show-FilteredTodoList, New-TrackerTodoItem, Update-TrackerTodoItem, Complete-TrackerTodoItem, Remove-TrackerTodoItem, Get-TrackerTodoItem, Show-TodoMenu