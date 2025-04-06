@{
    RootModule = 'ProjectTracker.TimeTracking.psm1'
    ModuleVersion = '1.0.0'
    GUID = '64b27f9a-e5c8-4bc1-a691-a324e7dc2e49'  # Generated with [System.Guid]::NewGuid()
    Author = 'Project Tracker Team'
    CompanyName = 'Project Tracker'
    Copyright = '(c) 2024 Project Tracker Team. All rights reserved.'
    Description = 'Time tracking functionality for Project Tracker'
    PowerShellVersion = '5.1'

    # Define modules needed by this module
    RequiredModules = @(
        @{ModuleName = 'ProjectTracker.Core'; ModuleVersion = '1.0.0'},
        @{ModuleName = 'ProjectTracker.Projects'; ModuleVersion = '1.0.0'}
    )

    # Functions to export from this module
    FunctionsToExport = @(
        'Show-TimeEntryList',
        'New-TimeEntry',
        'Update-TimeEntry',
        'Remove-TimeEntry',
        'Get-TimeEntry',
        'Show-TimeReport',
        'Show-TimeMenu'
    )

    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @()
    PrivateData = @{ PSData = @{} }
}