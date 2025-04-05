@{
    RootModule = 'ProjectTracker.Todos.psm1'
    ModuleVersion = '1.0.0'
    GUID = '24f5a765-21d1-45c7-a682-54b0fd6e5618'  # Generated with New-Guid
    Author = 'Your Name'
    CompanyName = 'Unknown'
    Copyright = '(c) 2024 Your Name. All rights reserved.'
    Description = 'Handles creating, updating, listing, and managing todos for Project Tracker.'
    PowerShellVersion = '5.1'

    # Define modules needed by this module - IMPORTANT
    RequiredModules = @(
        @{ModuleName = 'ProjectTracker.Core'; ModuleVersion = '1.0.0'} # Depends on Core v1.0.0
    )

    # Functions to export from this module
    FunctionsToExport = @(
        'Show-TodoList',
        'Show-FilteredTodoList', 
        'New-TrackerTodoItem',
        'Update-TrackerTodoItem',
        'Complete-TrackerTodoItem',
        'Remove-TrackerTodoItem',
        'Get-TrackerTodoItem',
        'Show-TodoMenu'
    )

    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @()
    PrivateData = @{ PSData = @{} }
}