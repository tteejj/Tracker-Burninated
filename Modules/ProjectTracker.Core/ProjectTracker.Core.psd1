@{
    RootModule = 'ProjectTracker.Core.psm1'
    ModuleVersion = '1.0.0'
    GUID = '88b45e5c-e9cf-4f8d-ac9d-c3213d6d35ca' # Generated with [System.Guid]::NewGuid()
    Author = 'Project Tracker Team'
    CompanyName = 'Project Tracker'
    Copyright = '(c) 2024 Project Tracker Team. All rights reserved.'
    Description = 'Core functionality for Project Tracker including configuration, error handling, logging, data access, UI and theme engine'
    PowerShellVersion = '5.1'

    # Functions to export from this module
    FunctionsToExport = @(
        # Configuration Functions
        'Get-AppConfig', 'Save-AppConfig', 'Merge-Hashtables',
        
        # Error Handling Functions
        'Handle-Error', 'Invoke-WithErrorHandling',
        
        # Logging Functions
        'Write-AppLog', 'Rotate-LogFile', 'Get-AppLogContent',
        
        # Data Functions
        'Ensure-DirectoryExists', 'Get-EntityData', 'Save-EntityData',
        'Update-CumulativeHours', 'Initialize-DataEnvironment',
        'Get-EntityById', 'Update-EntityById', 'Remove-EntityById', 'Create-Entity',
        
        # Date Functions
        'Parse-DateInput', 'Convert-DisplayDateToInternal', 'Convert-InternalDateToDisplay',
        'Get-RelativeDateDescription', 'Get-DateInput', 'Get-FirstDayOfWeek',
        'Get-WeekNumber', 'Get-MonthName', 'Get-RelativeWeekDescription', 'Get-MonthDateRange',
        
        # Helper Functions
        'Read-UserInput', 'Confirm-Action', 'New-MenuItems', 'Show-Confirmation',
        'Join-PathSafely', 'Convert-PriorityToInt', 'New-ID',
        
        # Theme Engine Functions
        'Copy-HashtableDeep', 'ConvertFrom-JsonToHashtable',
        'Initialize-ThemeEngine', 'Get-Theme', 'Set-CurrentTheme', 'Get-CurrentTheme',
        'Get-AvailableThemes', 'Write-ColorText', 'Show-Table', 'Render-Header',
        'Show-InfoBox', 'Show-ProgressBar', 'Show-DynamicMenu', 'Get-VisibleStringLength',
        'Safe-TruncateString', 'Remove-AnsiCodes'
    )

    CmdletsToExport = @()
    VariablesToExport = @()
    AliasesToExport = @()
    PrivateData = @{
        PSData = @{
            # Tags = @()
            # LicenseUri = ''
            # ProjectUri = ''
            # IconUri = ''
            # ReleaseNotes = ''
        }
    }
}
