# project-diagnostic.ps1
# Tests project creation to identify issues with the Projects module

# Set verbosity
$VerbosePreference = 'Continue'
$ErrorActionPreference = 'Continue'

# Get script directory
$scriptDir = $PSScriptRoot

Write-Host "===== Project Creation Diagnostic Test =====" -ForegroundColor Cyan

# 1. Import modules
Write-Host "STEP 1: Importing modules..." -ForegroundColor Yellow
try {
    # Import Core module
    Import-Module -Name "$scriptDir\Modules\ProjectTracker.Core\ProjectTracker.Core.psd1" -Force -ErrorAction Stop
    Write-Host "✓ Core module imported successfully" -ForegroundColor Green
    
    # Import Projects module
    Import-Module -Name "$scriptDir\Modules\ProjectTracker.Projects\ProjectTracker.Projects.psd1" -Force -ErrorAction Stop
    Write-Host "✓ Projects module imported successfully" -ForegroundColor Green
} catch {
    Write-Host "✗ Failed to import modules: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack trace: $($_.ScriptStackTrace)" -ForegroundColor DarkGray
    exit 1
}

# 2. Initialize environment
Write-Host "`nSTEP 2: Initializing environment..." -ForegroundColor Yellow
try {
    Initialize-DataEnvironment
    Initialize-ThemeEngine
    Write-Host "✓ Environment initialized successfully" -ForegroundColor Green
} catch {
    Write-Host "✗ Failed to initialize environment: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack trace: $($_.ScriptStackTrace)" -ForegroundColor DarkGray
}

# 3. Test project list function
Write-Host "`nSTEP 3: Testing Show-ProjectList function..." -ForegroundColor Yellow
try {
    Write-Host "Calling Show-ProjectList with tracing..." -ForegroundColor Yellow
    
    # Create trace function to track function calls
    function Trace-Function {
        param($Name, $Parameters)
        Write-Host "  -> Called: $Name $Parameters" -ForegroundColor DarkGray
    }
    
    # Add basic tracing around existing functions
    $originalRendererHeader = Get-Command Render-Header
    
    # Replace with traced version
    function Render-Header {
        param($Title, $Subtitle = "")
        Trace-Function "Render-Header" "Title=$Title, Subtitle=$Subtitle"
        & $originalRendererHeader $Title $Subtitle
    }
    
    # Debug theme-related components first
    Write-Host "Current theme info:" -ForegroundColor DarkGray
    $currentTheme = Get-CurrentTheme
    Write-Host "  Name: $($currentTheme.Name)" -ForegroundColor DarkGray
    
    if ($null -eq $currentTheme.Colors) {
        Write-Host "  ✗ Theme.Colors is NULL" -ForegroundColor Red
    } else {
        Write-Host "  ✓ Theme.Colors contains $($currentTheme.Colors.Count) entries" -ForegroundColor Green
    }
    
    # Call Show-ProjectList with debug output
    Write-Host "Listing projects..." -ForegroundColor Yellow
    $projects = Show-ProjectList -IncludeAll
    
    if ($null -eq $projects) {
        Write-Host "  Note: Show-ProjectList returned null" -ForegroundColor Yellow
    } else {
        Write-Host "  Found $($projects.Count) projects" -ForegroundColor Green
    }
} catch {
    Write-Host "✗ Show-ProjectList failed: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack trace: $($_.ScriptStackTrace)" -ForegroundColor DarkGray
}

# 4. Test project creation
Write-Host "`nSTEP 4: Testing project creation with fixed data..." -ForegroundColor Yellow
try {
    # Create test project data
    $projectData = @{
        Nickname = "TEST" + (Get-Random -Minimum 1000 -Maximum 9999)
        FullProjectName = "Test Project " + (Get-Date).ToString("yyyyMMdd-HHmmss")
        DateAssigned = (Get-Date).ToString("yyyyMMdd")
        DueDate = (Get-Date).AddDays(30).ToString("yyyyMMdd")
        BFDate = (Get-Date).AddDays(7).ToString("yyyyMMdd")
        ID1 = "TST"
        ID2 = "123"
        Note = "Test project created by diagnostic script"
        ProjFolder = ""
        Status = "Active"
        ClosedDate = ""
        CumulativeHrs = "0.0"
    }
    
    Write-Host "Created test project data:" -ForegroundColor DarkGray
    $projectData | ConvertTo-Json | Write-Host -ForegroundColor DarkGray
    
    # Test creation
    Write-Host "Creating project..." -ForegroundColor Yellow
    
    # Trace execution to find where it fails
    try {
        # Get needed paths beforehand to ensure they exist
        $config = Get-AppConfig
        $projectsFilePath = $config.ProjectsFullPath
        $todosFilePath = $config.TodosFullPath
        
        Write-Host "  Using projects file: $projectsFilePath" -ForegroundColor DarkGray
        Write-Host "  Using todos file: $todosFilePath" -ForegroundColor DarkGray
        
        if (Test-Path $projectsFilePath) {
            Write-Host "  ✓ Projects file exists" -ForegroundColor Green
        } else {
            Write-Host "  ✗ Projects file does not exist!" -ForegroundColor Red
        }
        
        if (Test-Path $todosFilePath) {
            Write-Host "  ✓ Todos file exists" -ForegroundColor Green
        } else {
            Write-Host "  ✗ Todos file does not exist!" -ForegroundColor Red
        }
        
        # Get existing data to see structure
        $existingProjects = @(Get-EntityData -FilePath $projectsFilePath)
        Write-Host "  Found $($existingProjects.Count) existing projects" -ForegroundColor DarkGray
        
        if ($existingProjects.Count -gt 0) {
            Write-Host "  First project properties:" -ForegroundColor DarkGray
            $existingProjects[0].PSObject.Properties.Name | ForEach-Object {
                Write-Host "    - $_" -ForegroundColor DarkGray
            }
        }
        
        # Step through New-TrackerProject by calling helper functions directly
        Write-Host "Manually creating project..." -ForegroundColor Yellow
        
        # Create PSObject from hashtable
        $newProj = [PSCustomObject]$projectData
        
        # Get existing projects
        $projects = @(Get-EntityData -FilePath $projectsFilePath)
        
        # Add the new project
        $updatedProjects = $projects + $newProj
        
        # Save projects
        Write-Host "Saving project data..." -ForegroundColor Yellow
        $saveResult = Save-EntityData -Data $updatedProjects -FilePath $projectsFilePath
        Write-Host "  Save result: $saveResult" -ForegroundColor $(if ($saveResult) { "Green" } else { "Red" })
        
        if ($saveResult) {
            # Try to create a simple todo
            $todoDescription = "Initial setup/follow up for $($newProj.Nickname)"
            
            # Create todo PSObject
            $newTodo = [PSCustomObject]@{
                ID = New-ID
                Nickname = $newProj.Nickname
                TaskDescription = $todoDescription
                Importance = "Normal"
                DueDate = $newProj.BFDate
                Status = "Pending"
                CreatedDate = (Get-Date).ToString("yyyyMMdd")
                CompletedDate = ""
            }
            
            # Get existing todos
            $todos = @(Get-EntityData -FilePath $todosFilePath)
            
            # Add the new todo
            $updatedTodos = $todos + $newTodo
            
            # Save todos
            $todoSaveResult = Save-EntityData -Data $updatedTodos -FilePath $todosFilePath
            Write-Host "  Todo save result: $todoSaveResult" -ForegroundColor $(if ($todoSaveResult) { "Green" } else { "Red" })
            
            Write-Host "✓ Manually created project and todo successfully" -ForegroundColor Green
        }
        
        # Now try the actual function
        Write-Host "Calling New-TrackerProject..." -ForegroundColor Yellow
        $newProject = New-TrackerProject -ProjectData $projectData
        
        if ($null -eq $newProject) {
            Write-Host "✗ New-TrackerProject returned null" -ForegroundColor Red
        } else {
            Write-Host "✓ Project created successfully: $($newProject.Nickname)" -ForegroundColor Green
        }
    } catch {
        Write-Host "✗ Project creation failed: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "Stack trace: $($_.ScriptStackTrace)" -ForegroundColor DarkGray
    }
} catch {
    Write-Host "✗ Project creation setup failed: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack trace: $($_.ScriptStackTrace)" -ForegroundColor DarkGray
}

# 5. Test project retrieval
Write-Host "`nSTEP 5: Testing Get-TrackerProject..." -ForegroundColor Yellow
try {
    # Create a project nickname to test
    $testNickname = $projectData.Nickname
    
    Write-Host "Getting project with nickname: $testNickname" -ForegroundColor DarkGray
    $project = Get-TrackerProject -Nickname $testNickname
    
    if ($null -eq $project) {
        Write-Host "✗ Get-TrackerProject returned null" -ForegroundColor Red
    } else {
        Write-Host "✓ Get-TrackerProject returned project: $($project.FullProjectName)" -ForegroundColor Green
    }
} catch {
    Write-Host "✗ Get-TrackerProject failed: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack trace: $($_.ScriptStackTrace)" -ForegroundColor DarkGray
}

# 6. List all projects again
Write-Host "`nSTEP 6: Testing Show-ProjectList again..." -ForegroundColor Yellow
try {
    Write-Host "Listing all projects..." -ForegroundColor Yellow
    $projects = Show-ProjectList -IncludeAll
    
    Write-Host "Project count: $($projects.Count)" -ForegroundColor DarkGray
} catch {
    Write-Host "✗ Show-ProjectList failed: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack trace: $($_.ScriptStackTrace)" -ForegroundColor DarkGray
}

Write-Host "`n===== Project Creation Diagnostic Complete =====" -ForegroundColor Cyan