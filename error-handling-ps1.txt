# lib/error-handling.ps1
# Standardized Error Handling for Project Tracker
# Provides consistent error handling, logging, and user feedback

<#
.SYNOPSIS
    Handles errors consistently throughout the application.
.DESCRIPTION
    Centralizes error handling by providing logging, user feedback, and
    optionally terminating execution. Integrates with the logging system
    when available.
.PARAMETER ErrorRecord
    The PowerShell error record object.
.PARAMETER Context
    A string describing the operation that generated the error.
.PARAMETER Continue
    If specified, execution will continue after handling the error.
    Otherwise, the function will terminate execution.
.PARAMETER Silent
    If specified, no console output will be generated.
.EXAMPLE
    try {
        # Some operation that may fail
    } catch {
        Handle-Error -ErrorRecord $_ -Context "Reading data file" -Continue
    }
.EXAMPLE
    try {
        # Critical operation
    } catch {
        Handle-Error -ErrorRecord $_ -Context "Database initialization"
        # Will not reach this point as the function will terminate execution
    }
#>
function Handle-Error {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [System.Management.Automation.ErrorRecord]$ErrorRecord,
        
        [Parameter(Mandatory=$false)]
        [string]$Context = "Operation",
        
        [Parameter(Mandatory=$false)]
        [switch]$Continue,
        
        [Parameter(Mandatory=$false)]
        [switch]$Silent
    )
    
    # Extract error information
    $exception = $ErrorRecord.Exception
    $message = $exception.Message
    $scriptStackTrace = $ErrorRecord.ScriptStackTrace
    $errorCategory = $ErrorRecord.CategoryInfo.Category
    $errorId = $ErrorRecord.FullyQualifiedErrorId
    $position = $ErrorRecord.InvocationInfo.PositionMessage
    
    # Build detailed error message
    $detailedMessage = @"
Error in $Context
Message: $message
Category: $errorCategory
Error ID: $errorId
Position: $position
Stack Trace:
$scriptStackTrace
"@
    
    # Log error if Write-AppLog is available
    if (Get-Command "Write-AppLog" -ErrorAction SilentlyContinue) {
        try {
            Write-AppLog -Message "ERROR in $Context - $message" -Level ERROR
            Write-AppLog -Message $detailedMessage -Level DEBUG
        } catch {
            # Fallback if logging fails
            Write-Warning "Failed to log error: $($_.Exception.Message)"
        }
    }
    
    # Display error to console unless silent
    if (-not $Silent) {
        # Use themed output if available
        if (Get-Command "Show-InfoBox" -ErrorAction SilentlyContinue) {
            try {
                Show-InfoBox -Title "Error in $Context" -Message $message -Type Error
            } catch {
                # Fallback if themed output fails
                Write-Host "ERROR in $Context - $message" -ForegroundColor Red
            }
        } else {
            # Standard console output
            Write-Host "ERROR in $Context - $message" -ForegroundColor Red
            
            # Show detailed information in debug scenarios
            if ($VerbosePreference -eq 'Continue' -or $DebugPreference -eq 'Continue') {
                Write-Host $detailedMessage -ForegroundColor DarkGray
            }
        }
    }
    
    # Terminate execution unless Continue is specified
    if (-not $Continue) {
        # Use throw to preserve the original error
        throw $ErrorRecord
    }
}

<#
.SYNOPSIS
    Runs a script block with try/catch and standard error handling.
.DESCRIPTION
    Executes the provided script block in a try/catch block,
    handling any errors using Handle-Error. Simplifies error handling
    for common operations.
.PARAMETER ScriptBlock
    The script block to execute.
.PARAMETER ErrorContext
    A string describing the operation for error context.
.PARAMETER Continue
    If specified, execution will continue after handling any error.
.PARAMETER Silent
    If specified, no console output will be generated for errors.
.PARAMETER DefaultValue
    The value to return if an error occurs and Continue is specified.
.EXAMPLE
    $result = Invoke-WithErrorHandling -ScriptBlock { Get-Content -Path $filePath } -ErrorContext "Reading data file" -Continue -DefaultValue @()
.OUTPUTS
    Returns the output of the script block or the DefaultValue if an error occurs.
#>
function Invoke-WithErrorHandling {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [scriptblock]$ScriptBlock,
        
        [Parameter(Mandatory=$false)]
        [string]$ErrorContext = "Operation",
        
        [Parameter(Mandatory=$false)]
        [switch]$Continue,
        
        [Parameter(Mandatory=$false)]
        [switch]$Silent,
        
        [Parameter(Mandatory=$false)]
        [object]$DefaultValue = $null
    )
    
    try {
        # Execute the script block
        return & $ScriptBlock
    } catch {
        # Handle the error
        Handle-Error -ErrorRecord $_ -Context $ErrorContext -Continue:$Continue -Silent:$Silent
        
        # If Continue is specified, return the default value
        if ($Continue) {
            return $DefaultValue
        }
        
        # This point is only reached if Continue is specified and Handle-Error doesn't terminate
    }
}

# Export the functions for use in other modules
Export-ModuleMember -Function Handle-Error, Invoke-WithErrorHandling
