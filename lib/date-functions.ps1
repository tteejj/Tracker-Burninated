# lib/date-functions.ps1
# Date Handling Utilities for Project Tracker
# Provides consistent date parsing, formatting, and manipulation

<#
.SYNOPSIS
    Parses a date string in various formats to the internal storage format.
.DESCRIPTION
    Attempts to parse a date string in various common formats, returning
    a standardized string in the internal storage format (YYYYMMDD by default).
    Handles multiple input formats with consistent error handling.
.PARAMETER InputDate
    The date string to parse.
.PARAMETER AllowEmptyForToday
    If specified, returns today's date when input is empty.
.PARAMETER DefaultFormat
    The format to use for the output date string. Default is 'yyyyMMdd'.
.PARAMETER DisplayFormat
    The expected format for input dates when displayed to users.
.EXAMPLE
    $internalDate = Parse-DateInput -InputDate "4/15/2023" -AllowEmptyForToday
.OUTPUTS
    System.String - The parsed date in internal format, or "CANCEL" if user cancelled
#>
function Parse-DateInput {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)]
        [string]$InputDate,
        
        [Parameter(Mandatory=$false)]
        [switch]$AllowEmptyForToday,
        
        [Parameter(Mandatory=$false)]
        [string]$DefaultFormat = "yyyyMMdd", # Default internal storage format
        
        [Parameter(Mandatory=$false)]
        [string]$DisplayFormat = $null # Will be populated from config if null
    )
    
    # Get display format from config if not provided
    if ($null -eq $DisplayFormat) {
        if (Get-Command "Get-AppConfig" -ErrorAction SilentlyContinue) {
            try {
                $config = Get-AppConfig
                $DisplayFormat = $config.DisplayDateFormat
            } catch {
                # Default if config not available
                $DisplayFormat = "MM/dd/yyyy"
            }
        } else {
            # Default if config not available
            $DisplayFormat = "MM/dd/yyyy"
        }
    }
    
    # Handle empty input
    if ([string]::IsNullOrWhiteSpace($InputDate)) {
        if ($AllowEmptyForToday) {
            return (Get-Date).ToString($DefaultFormat)
        } else {
            Write-Verbose "Date input cannot be empty."
            return $null
        }
    }
    
    # Handle cancel input
    if ($InputDate -in @("0", "exit", "cancel", "q", "quit")) {
        return "CANCEL"
    }
    
    # Try parsing with various common formats
    $parsedDate = $null
    $formatsToTry = @(
        $DefaultFormat,        # Try internal format first
        $DisplayFormat,        # Then display format
        "M/d/yyyy",            # US short date (month/day/year)
        "MM/dd/yyyy",          # US with leading zeros
        "yyyy-MM-dd",          # ISO format
        "dd/MM/yyyy",          # European format
        "d-MMM-yyyy",          # Day-MonthName-Year
        "yyyyMMdd"             # Compact format
    )
    
    # Try each format until one succeeds
    foreach ($format in $formatsToTry) {
        try {
            $parsedDate = [datetime]::ParseExact($InputDate, $format, [System.Globalization.CultureInfo]::InvariantCulture)
            break # Stop on first successful parse
        } catch {
            $parsedDate = $null
        }
    }
    
    # If all specific formats failed, try general parsing
    if ($null -eq $parsedDate) {
        try {
            $parsedDate = [datetime]::Parse($InputDate, [System.Globalization.CultureInfo]::InvariantCulture)
        } catch {
            # Try current culture as last resort
            try {
                $parsedDate = [datetime]::Parse($InputDate)
            } catch {
                Write-Verbose "Failed to parse date: $InputDate"
                return $null
            }
        }
    }
    
    # Return parsed date in internal format
    if ($parsedDate -is [datetime]) {
        return $parsedDate.ToString($DefaultFormat)
    }
    
    # Should not reach here if parsing succeeded
    return $null
}

<#
.SYNOPSIS
    Converts a date from display format to internal format.
.DESCRIPTION
    Converts a date string from the display format to the internal storage format.
.PARAMETER DisplayDate
    The date string in display format.
.PARAMETER InternalFormat
    The format to use for the output date string. Default is 'yyyyMMdd'.
.PARAMETER DisplayFormat
    The format of the input date string. If not specified, uses the format from configuration.
.EXAMPLE
    $internalDate = Convert-DisplayDateToInternal -DisplayDate "4/15/2023"
.OUTPUTS
    System.String - The date in internal format, or null if conversion failed
#>
function Convert-DisplayDateToInternal {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$DisplayDate,
        
        [Parameter(Mandatory=$false)]
        [string]$InternalFormat = "yyyyMMdd",
        
        [Parameter(Mandatory=$false)]
        [string]$DisplayFormat = $null
    )
    
    # Get display format from config if not provided
    if ($null -eq $DisplayFormat) {
        if (Get-Command "Get-AppConfig" -ErrorAction SilentlyContinue) {
            try {
                $config = Get-AppConfig
                $DisplayFormat = $config.DisplayDateFormat
            } catch {
                # Default if config not available
                $DisplayFormat = "MM/dd/yyyy"
            }
        } else {
            # Default if config not available
            $DisplayFormat = "MM/dd/yyyy"
        }
    }
    
    # Check for empty input
    if ([string]::IsNullOrWhiteSpace($DisplayDate)) {
        return $null
    }
    
    # Try exact parsing with display format
    try {
        $parsedDate = [datetime]::ParseExact($DisplayDate, $DisplayFormat, [System.Globalization.CultureInfo]::InvariantCulture)
        return $parsedDate.ToString($InternalFormat)
    } catch {
        # Fall back to general parsing if exact parse fails
        return Parse-DateInput -InputDate $DisplayDate -DefaultFormat $InternalFormat
    }
}

<#
.SYNOPSIS
    Converts a date from internal format to display format.
.DESCRIPTION
    Converts a date string from the internal storage format to the display format.
.PARAMETER InternalDate
    The date string in internal format (YYYYMMDD).
.PARAMETER DisplayFormat
    The format to use for the output date string. If not specified, uses the format from configuration.
.PARAMETER InternalFormat
    The format of the input date string. Default is 'yyyyMMdd'.
.EXAMPLE
    $displayDate = Convert-InternalDateToDisplay -InternalDate "20230415"
.OUTPUTS
    System.String - The date in display format, or empty string if conversion failed
#>
function Convert-InternalDateToDisplay {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$InternalDate,
        
        [Parameter(Mandatory=$false)]
        [string]$DisplayFormat = $null,
        
        [Parameter(Mandatory=$false)]
        [string]$InternalFormat = "yyyyMMdd"
    )
    
    # Get display format from config if not provided
    if ($null -eq $DisplayFormat) {
        if (Get-Command "Get-AppConfig" -ErrorAction SilentlyContinue) {
            try {
                $config = Get-AppConfig
                $DisplayFormat = $config.DisplayDateFormat
            } catch {
                # Default if config not available
                $DisplayFormat = "MM/dd/yyyy"
            }
        } else {
            # Default if config not available
            $DisplayFormat = "MM/dd/yyyy"
        }
    }
    
    # Check for empty input
    if ([string]::IsNullOrWhiteSpace($InternalDate)) {
        return ""
    }
    
    # Try exact parsing with internal format
    try {
        $parsedDate = [datetime]::ParseExact($InternalDate, $InternalFormat, [System.Globalization.CultureInfo]::InvariantCulture)
        return $parsedDate.ToString($DisplayFormat)
    } catch {
        try {
            # Fallback to general parsing
            $parsedDate = [datetime]::Parse($InternalDate)
            return $parsedDate.ToString($DisplayFormat)
        } catch {
            Write-Verbose "Could not convert date '$InternalDate' to display format."
            return $InternalDate # Return original if conversion fails
        }
    }
}

<#
.SYNOPSIS
    Gets a relative description of a date compared to today.
.DESCRIPTION
    Returns a human-readable relative description of a date (e.g., "Today", "Tomorrow", "3 days ago").
.PARAMETER Date
    The date to describe.
.PARAMETER ReferenceDate
    The reference date to compare against. Default is today.
.EXAMPLE
    $description = Get-RelativeDateDescription -Date $dueDate
.OUTPUTS
    System.String - The relative date description
#>
function Get-RelativeDateDescription {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [datetime]$Date,
        
        [Parameter(Mandatory=$false)]
        [datetime]$ReferenceDate = (Get-Date).Date # Compare against date part only
    )
    
    # Calculate difference in days
    $diff = ($Date.Date - $ReferenceDate).Days
    
    # Return appropriate description
    if ($diff -eq 0) { return "Today" }
    if ($diff -eq 1) { return "Tomorrow" }
    if ($diff -eq -1) { return "Yesterday" }
    if ($diff -gt 1 -and $diff -le 7) { return "In $diff days" }
    if ($diff -lt -1 -and $diff -ge -7) { return "$([Math]::Abs($diff)) days ago" }
    
    # Get display format from config if available
    $displayFormat = "MM/dd/yyyy" # Default
    if (Get-Command "Get-AppConfig" -ErrorAction SilentlyContinue) {
        try {
            $config = Get-AppConfig
            $displayFormat = $config.DisplayDateFormat
        } catch { 
            # Use default if config not available
        }
    }
    
    # Return formatted date for anything further out
    return $Date.ToString($displayFormat)
}

<#
.SYNOPSIS
    Gets a date input from the user with validation.
.DESCRIPTION
    Prompts the user for a date input with configurable options and validation.
.PARAMETER PromptText
    The text to display as a prompt.
.PARAMETER DefaultValue
    The default value to use if the user enters nothing.
.PARAMETER AllowEmptyForToday
    If specified, uses today's date when input is empty.
.PARAMETER AllowCancel
    If specified, allows the user to cancel by entering "0" or "cancel".
.EXAMPLE
    $dueDate = Get-DateInput -PromptText "Enter due date" -AllowEmptyForToday
.OUTPUTS
    System.String - The date in internal format, or null if the user cancelled
#>
function Get-DateInput {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$PromptText,
        
        [Parameter(Mandatory=$false)]
        [string]$DefaultValue = "",
        
        [Parameter(Mandatory=$false)]
        [switch]$AllowEmptyForToday,
        
        [Parameter(Mandatory=$false)]
        [switch]$AllowCancel
    )
    
    # Get colorized prompt if theme engine is available
    $promptFunction = Get-Command "Write-ColorText" -ErrorAction SilentlyContinue
    if ($null -eq $promptFunction) {
        # Fallback to standard Write-Host if theme engine not available
        $promptFunction = Get-Command "Write-Host" -ErrorAction SilentlyContinue
    }
    
    # Loop until valid date or cancel
    while ($true) {
        # Display prompt
        if ($null -ne $promptFunction) {
            if ($DefaultValue -and -not $AllowEmptyForToday) {
                & $promptFunction "$PromptText [Default: $(Convert-InternalDateToDisplay $DefaultValue)]: " -ForegroundColor Cyan -NoNewline
            } else {
                & $promptFunction "$PromptText$(if ($AllowEmptyForToday) { ' (Enter=Today)' }): " -ForegroundColor Cyan -NoNewline
            }
        }
        
        # Get input
        $input = Read-Host
        
        # Handle empty input
        if ([string]::IsNullOrWhiteSpace($input)) {
            if ($AllowEmptyForToday) {
                return (Get-Date).ToString("yyyyMMdd")
            } elseif (-not [string]::IsNullOrEmpty($DefaultValue)) {
                return $DefaultValue
            } else {
                Write-Host "Date cannot be empty." -ForegroundColor Red
                continue
            }
        }
        
        # Handle cancel option
        if ($AllowCancel -and $input -in @("0", "exit", "cancel", "q", "quit")) {
            return $null
        }
        
        # Parse date
        $parsedDate = Parse-DateInput -InputDate $input
        if ($parsedDate -eq "CANCEL" -and $AllowCancel) {
            return $null
        } elseif ($parsedDate) {
            return $parsedDate
        } else {
            # Show error message on invalid input
            $displayFormat = (Get-AppConfig).DisplayDateFormat
            Write-Host "Invalid date format. Please use $displayFormat, or similar format." -ForegroundColor Red
            
            # Loop continues for another attempt
        }
    }
}

<#
.SYNOPSIS
    Gets the first day of the week containing the specified date.
.DESCRIPTION
    Returns the date of the first day of the week containing the specified date,
    based on the configured start day of the week.
.PARAMETER Date
    The reference date.
.PARAMETER StartDay
    The day of the week to consider as the start. Default from config or Monday.
.EXAMPLE
    $weekStart = Get-FirstDayOfWeek -Date (Get-Date)
.OUTPUTS
    System.DateTime - The date of the first day of the week
#>
function Get-FirstDayOfWeek {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [datetime]$Date,
        
        [Parameter(Mandatory=$false)]
        [System.DayOfWeek]$StartDay = $null
    )
    
    # Get start day from config if not provided
    if ($null -eq $StartDay) {
        if (Get-Command "Get-AppConfig" -ErrorAction SilentlyContinue) {
            try {
                $config = Get-AppConfig
                $StartDay = $config.CalendarStartDay
            } catch {
                # Default if config not available
                $StartDay = [System.DayOfWeek]::Monday
            }
        } else {
            # Default if config not available
            $StartDay = [System.DayOfWeek]::Monday
        }
    }
    
    # Calculate days to subtract to get to start of week
    $diff = [int]$Date.DayOfWeek - [int]$StartDay
    if ($diff -lt 0) { $diff += 7 } # Wrap around for negative difference
    
    # Return the date of the first day of the week
    return $Date.AddDays(-$diff)
}

<#
.SYNOPSIS
    Gets the ISO week number for a date.
.DESCRIPTION
    Calculates the ISO 8601 week number (1-53) for the specified date.
.PARAMETER Date
    The date to get the week number for.
.EXAMPLE
    $weekNumber = Get-WeekNumber -Date (Get-Date)
.OUTPUTS
    System.Int32 - The ISO week number
#>
function Get-WeekNumber {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [datetime]$Date
    )
    
    # Use the .NET calendar to calculate the week number
    $cal = [System.Globalization.CultureInfo]::InvariantCulture.Calendar
    
    # Get week of year using ISO rules (FirstFourDayWeek)
    return $cal.GetWeekOfYear(
        $Date,
        [System.Globalization.CalendarWeekRule]::FirstFourDayWeek,
        [System.DayOfWeek]::Monday
    )
}

<#
.SYNOPSIS
    Gets the full month name for a month number.
.DESCRIPTION
    Returns the full name of the month for the specified month number (1-12).
.PARAMETER Month
    The month number (1-12).
.EXAMPLE
    $monthName = Get-MonthName -Month 9
.OUTPUTS
    System.String - The full month name
#>
function Get-MonthName {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateRange(1, 12)]
        [int]$Month
    )
    
    # Get the month name from the current culture
    return (Get-Culture).DateTimeFormat.GetMonthName($Month)
}

<#
.SYNOPSIS
    Gets the relative week description compared to the current week.
.DESCRIPTION
    Returns a description of a week relative to the current week (e.g., "This Week", "Next Week").
.PARAMETER WeekStartDate
    The start date of the week to describe.
.EXAMPLE
    $weekDescription = Get-RelativeWeekDescription -WeekStartDate $startDate
.OUTPUTS
    System.String - The relative week description
#>
function Get-RelativeWeekDescription {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [datetime]$WeekStartDate
    )
    
    # Get current week start date
    $currentWeekStart = Get-FirstDayOfWeek -Date (Get-Date)
    
    # Calculate week difference
    $weekDiff = [int](($WeekStartDate - $currentWeekStart).TotalDays / 7)
    
    # Return appropriate description
    if ($weekDiff == 0) { return "This Week" }
    if ($weekDiff == 1) { return "Next Week" }
    if ($weekDiff == -1) { return "Last Week" }
    if ($weekDiff -gt 1) { return "$weekDiff weeks ahead" }
    if ($weekDiff -lt -1) { return "$([Math]::Abs($weekDiff)) weeks ago" }
    
    # Shouldn't get here, but just in case
    return "Week of $($WeekStartDate.ToString('MMM d'))"
}

<#
.SYNOPSIS
    Gets the date range for a specified month.
.DESCRIPTION
    Returns the start and end dates for the specified month.
.PARAMETER Year
    The year.
.PARAMETER Month
    The month (1-12).
.EXAMPLE
    $range = Get-MonthDateRange -Year 2023 -Month 4
.OUTPUTS
    PSObject - Object with StartDate and EndDate properties
#>
function Get-MonthDateRange {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [int]$Year,
        
        [Parameter(Mandatory=$true)]
        [ValidateRange(1, 12)]
        [int]$Month
    )
    
    # Calculate start and end dates
    $startDate = Get-Date -Year $Year -Month $Month -Day 1
    $endDate = $startDate.AddMonths(1).AddDays(-1)
    
    # Return as custom object
    return [PSCustomObject]@{
        StartDate = $startDate
        EndDate = $endDate
    }
}

# Export functions
Export-ModuleMember -Function Parse-DateInput, Convert-DisplayDateToInternal, Convert-InternalDateToDisplay,
                     Get-RelativeDateDescription, Get-DateInput, Get-FirstDayOfWeek,
                     Get-WeekNumber, Get-MonthName, Get-RelativeWeekDescription, Get-MonthDateRange
