@{
    RootModule = 'ProjectTracker.Projects.psm1'
    ModuleVersion = '1.0.0'
    GUID = '33884b71-e834-4daf-b27c-47ebf58a964f' # Generated with [System.Guid]::NewGuid()
    Author = 'Project Tracker Team'
    CompanyName = 'Project Tracker'
    Copyright = '(c) 2024 Project Tracker Team. All rights reserved.'
    Description = 'Project management functionality for Project Tracker'
    PowerShellVersion = '5.1'

    # Define modules needed by this module - FIXED FORMAT
    RequiredModules = @(
        @{ModuleName = 'ProjectTracker.Core'; RequiredVersion = '1.0.0'}
    )

    # Functions to export from this module
    FunctionsToExport = @(
        'Show-ProjectList',
        'New-TrackerProject',
        'Update-TrackerProject',
        'Remove-TrackerProject',
        'Get-TrackerProject',
        'Set-TrackerProjectStatus',
        'Update-TrackerProjectHours',
        'Show-ProjectMenu'
    )

    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @()
    PrivateData = @{ PSData = @{} }
}