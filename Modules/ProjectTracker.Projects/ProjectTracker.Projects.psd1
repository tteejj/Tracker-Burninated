@{
    RootModule = 'ProjectTracker.Projects.psm1'
    ModuleVersion = '1.0.0'
    GUID = '3ed0741d-cbbd-4924-8612-93e686b4e44f' # Generated with [System.Guid]::NewGuid()
    Author = 'Project Tracker Team'
    CompanyName = 'Project Tracker'
    Copyright = '(c) 2024 Project Tracker Team. All rights reserved.'
    Description = 'Project management functionality for Project Tracker'
    PowerShellVersion = '5.1'

    # Define modules needed by this module
    RequiredModules = @(
        @{ModuleName = 'ProjectTracker.Core'; ModuleVersion = '1.0.0'}
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