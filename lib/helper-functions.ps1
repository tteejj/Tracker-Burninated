# lib/helper-functions.ps1
# General Utility Functions for Project Tracker
# Provides utility functions used throughout the application

<#
.SYNOPSIS
    Reads user input with validation and default values.
.DESCRIPTION
    Prompts the user for input, with optional validation, default values, and secure input.
.PARAMETER Prompt
    The text to display as a prompt.
.PARAMETER Validator
    A script block that validates the input. Should return $true for valid input.
.PARAMETER ErrorMessage
    The error message to display when validation fails.
.PARAMETER DefaultValue
    The default value to use if the user enters nothing.
.PARAMETER HideInput
    If specified, hides the input (for passwords).
.PARAMETER AllowEmpty
    If specified, allows empty input even if a default value is provided.
.EXAMPLE
    $name = Read-UserInput -Prompt "Enter your name" -DefaultValue "User"
.EXAMPLE
    $age = Read-UserInput -Prompt "Enter your age" -Validator { param($input) $input -match '^\d+$' } -ErrorMessage "Age must be a number"
.OUTPUTS
    System.String - The user input or default value
#>
function Read-UserInput {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Prompt,
        
        [Parameter(Mandatory=$false)]
        [scriptblock]$Validator = { param($input) $true },
        
        [Parameter(Mandatory=$false)]
        [string]$ErrorMessage = "Invalid input. Please try again.",
        
        [Parameter(Mandatory=$false)]
        [object]$DefaultValue = $null,
        
        [Parameter(Mandatory=$false)]
        [switch]$HideInput,
        
        [Parameter(Mandatory=$false)]
        [switch]$AllowEmpty
    )
    
    # Check if we have the colorized output function
    $hasColorOutput = Get-Command "Write-ColorText" -ErrorAction SilentlyContinue
    
    # Format prompt with default value if provided
    $displayPrompt = $Prompt
    if ($null -ne $DefaultValue -and -not [string]::IsNullOrEmpty($DefaultValue.ToString())) {
        $displayPrompt += " [Default: $DefaultValue]"
    }
    $displayPrompt += ": "
    
    # Loop until valid input is received
    while ($true) {
        # Display prompt
        if ($hasColorOutput) {
            Write-ColorText $displayPrompt -ForegroundColor "Cyan" -NoNewline
        } else {
            Write-Host $displayPrompt -ForegroundColor Cyan -NoNewline
        }
        
        # Get input (secure or normal)
        $input = if ($HideInput) {
            $secureString = Read-Host -AsSecureString
            $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureString)
            [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
        } else {
            Read-Host
        }
        
        # Handle empty input
        if ([string]::IsNullOrEmpty($input)) {
            if ($AllowEmpty) {
                return ""
            } elseif ($null -ne $DefaultValue) {
                return $DefaultValue
            } elseif (-not $AllowEmpty) {
                if ($hasColorOutput) {
                    Write-ColorText "Input cannot be empty." -ForegroundColor "Red"
                } else {
                    Write-Host "Input cannot be empty." -ForegroundColor Red
                }
                continue
            }
        }
        
        # Validate input
        try {
            $isValid = & $Validator $input
            if ($isValid -eq $true) {
                return $input
            } else {
                if ($hasColorOutput) {
                    Write-ColorText $ErrorMessage -ForegroundColor "Red"
                } else {
                    Write-Host $ErrorMessage -ForegroundColor Red
                }
            }
        } catch {
            if ($hasColorOutput) {
                Write-ColorText "Error in validator: $($_.Exception.Message)" -ForegroundColor "Red"
            } else {
                Write-Host "Error in validator: $($_.Exception.Message)" -ForegroundColor Red
            }
        }
    }
}

<#
.SYNOPSIS
    Confirms an action with the user.
.DESCRIPTION
    Asks the user to confirm an action with yes/no input.
.PARAMETER ActionDescription
    Description of the action to confirm.
.PARAMETER ConfirmText
    The text that indicates confirmation. Default is "Yes".
.PARAMETER RejectText
    The text that indicates rejection. Default is "No".
.EXAMPLE
    if (Confirm-Action -ActionDescription "Delete this file") {
        # Deletion code here
    }
.OUTPUTS
    System.Boolean - True if the user confirmed, False otherwise
#>
function Confirm-Action {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$ActionDescription,
        
        [Parameter(Mandatory=$false)]
        [string]$ConfirmText = "Yes",
        
        [Parameter(Mandatory=$false)]
        [string]$RejectText = "No"
    )
    
    $hasColorOutput = Get-Command "Write-ColorText" -ErrorAction SilentlyContinue
    
    $prompt = "$ActionDescription ($ConfirmText/$RejectText)? "
    
    if ($hasColorOutput) {
        Write-ColorText $prompt -ForegroundColor "Yellow" -NoNewline
    } else {
        Write-Host $prompt -ForegroundColor Yellow -NoNewline
    }
    
    $response = Read-Host
    
    return $response -ieq $ConfirmText # Case-insensitive match
}

<#
.SYNOPSIS
    Creates a list of menu items for Show-DynamicMenu.
.DESCRIPTION
    Initializes a new array of menu items for use with Show-DynamicMenu.
.EXAMPLE
    $menuItems = New-MenuItems
    $menuItems += @{ Type = "header"; Text = "Main Menu" }
    $menuItems += @{ Type = "option"; Key = "1"; Text = "View Projects"; Function = { Show-Projects } }
.OUTPUTS
    System.Collections.ArrayList - An array for menu items
#>
function New-MenuItems {
    [CmdletBinding()]
    param()
    
    return New-Object System.Collections.ArrayList
}

<#
.SYNOPSIS
    Shows a simple confirmation dialog.
.DESCRIPTION
    Displays a confirmation dialog with the specified message and returns the user's response.
.PARAMETER Message
    The message to display.
.PARAMETER Title
    The title of the dialog.
.PARAMETER DefaultYes
    If specified, defaults to "Yes" when the user presses Enter.
.EXAMPLE
    if (Show-Confirmation -Message "Are you sure you want to delete this file?" -Title "Confirm Delete") {
        # Deletion code here
    }
.OUTPUTS
    System.Boolean - True if the user confirmed, False otherwise
#>
function Show-Confirmation {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Message,
        
        [Parameter(Mandatory=$false)]
        [string]$Title = "Confirm",
        
        [Parameter(Mandatory=$false)]
        [switch]$DefaultYes
    )
    
    # Use info box if available
    $hasInfoBox = Get-Command "Show-InfoBox" -ErrorAction SilentlyContinue
    
    if ($hasInfoBox) {
        # Display message with the theme engine
        Show-InfoBox -Title $Title -Message "$Message`n`nEnter Y for Yes, N for No." -Type Warning
    } else {
        # Fall back to simple console output
        Write-Host "`n-- $Title --" -ForegroundColor Yellow
        Write-Host $Message -ForegroundColor White
        Write-Host "------------" -ForegroundColor Yellow
    }
    
    # Get default option display
    $defaultOption = if ($DefaultYes) { "(Y/n)" } else { "(y/N)" }
    
    # Ask for confirmation
    Write-Host "Confirm $defaultOption? " -ForegroundColor Cyan -NoNewline
    $response = Read-Host
    
    # Handle empty response
    if ([string]::IsNullOrWhiteSpace($response)) {
        return $DefaultYes
    }
    
    # Return based on response
    return $response -match '^[yY]'
}

<#
.SYNOPSIS
    Gets the value of an environment variable with a default.
.DESCRIPTION
    Returns the value of the specified environment variable, or a default if not set.
.PARAMETER Name
    The name of the environment variable.
.PARAMETER DefaultValue
    The default value to return if the variable is not set.
.EXAMPLE
    $logLevel = Get-EnvironmentVariable -Name "APP_LOG_LEVEL" -DefaultValue "INFO"
.OUTPUTS
    System.String - The environment variable value or default
#>
function Get-EnvironmentVariable {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Name,
        
        [Parameter(Mandatory=$false)]
        [string]$DefaultValue = ""
    )
    
    $value = [Environment]::GetEnvironmentVariable($Name)
    
    if ([string]::IsNullOrEmpty($value)) {
        return $DefaultValue
    }
    
    return $value
}

<#
.SYNOPSIS
    Joins paths safely, handling errors.
.DESCRIPTION
    Joins path components safely, handling edge cases and errors.
.PARAMETER Path
    The base path.
.PARAMETER ChildPath
    The child path to append.
.EXAMPLE
    $fullPath = Join-PathSafely -Path $baseDir -ChildPath "data/file.txt"
.OUTPUTS
    System.String - The combined path
#>
function Join-PathSafely {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Path,
        
        [Parameter(Mandatory=$true)]
        [string]$ChildPath
    )
    
    # Handle edge cases
    if ([string]::IsNullOrEmpty($Path)) {
        return $ChildPath
    }
    
    if ([string]::IsNullOrEmpty($ChildPath)) {
        return $Path
    }
    
    try {
        # Use .NET Path class for reliable path joining
        return [System.IO.Path]::Combine($Path, $ChildPath)
    } catch {
        Write-Warning "Error joining paths: $Path and $ChildPath - $($_.Exception.Message)"
        # Fall back to manual joining
        if ($Path.EndsWith([System.IO.Path]::DirectorySeparatorChar) -or 
            $Path.EndsWith([System.IO.Path]::AltDirectorySeparatorChar)) {
            return "$Path$ChildPath"
        } else {
            return "$Path$([System.IO.Path]::DirectorySeparatorChar)$ChildPath"
        }
    }
}

<#
.SYNOPSIS
    Ensures a directory exists.
.DESCRIPTION
    Checks if a directory exists and creates it if it does not.
.PARAMETER Path
    The path to the directory.
.PARAMETER Force
    If specified, creates all parent directories if they don't exist.
.EXAMPLE
    Ensure-DirectoryExists -Path "C:\Temp\Data" -Force
.OUTPUTS
    System.Boolean - True if the directory exists or was created, False otherwise
#>
function Ensure-DirectoryExists {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Path,
        
        [Parameter(Mandatory=$false)]
        [switch]$Force
    )
    
    if (-not (Test-Path -Path $Path -PathType Container)) {
        try {
            New-Item -Path $Path -ItemType Directory -Force:$Force | Out-Null
            Write-Verbose "Created directory: $Path"
            return $true
        } catch {
            Write-Warning "Failed to create directory '$Path': $($_.Exception.Message)"
            return $false
        }
    }
    
    return $true
}

<#
.SYNOPSIS
    Gets a unique filename in a directory.
.DESCRIPTION
    Generates a unique filename in the specified directory by appending a number if needed.
.PARAMETER Directory
    The directory to check for existing files.
.PARAMETER FileName
    The base filename to use.
.PARAMETER Extension
    The file extension (without the dot).
.EXAMPLE
    $uniqueName = Get-UniqueFileName -Directory "C:\Temp" -FileName "Report" -Extension "txt"
.OUTPUTS
    System.String - The unique filename (without path)
#>
function Get-UniqueFileName {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Directory,
        
        [Parameter(Mandatory=$true)]
        [string]$FileName,
        
        [Parameter(Mandatory=$true)]
        [string]$Extension
    )
    
    # Ensure extension doesn't start with a dot
    if ($Extension.StartsWith(".")) {
        $Extension = $Extension.Substring(1)
    }
    
    # Check if the initial filename exists
    $baseFileName = "$FileName.$Extension"
    $fullPath = Join-PathSafely -Path $Directory -ChildPath $baseFileName
    
    if (-not (Test-Path -Path $fullPath)) {
        return $baseFileName
    }
    
    # Find a unique name by appending numbers
    $counter = 1
    do {
        $newFileName = "$FileName($counter).$Extension"
        $fullPath = Join-PathSafely -Path $Directory -ChildPath $newFileName
        $counter++
    } while (Test-Path -Path $fullPath)
    
    return $newFileName
}

<#
.SYNOPSIS
    Converts a string to a valid filename.
.DESCRIPTION
    Replaces invalid characters in a string to make it a valid filename.
.PARAMETER InputString
    The string to convert.
.PARAMETER ReplacementChar
    The character to use for replacement. Default is '_'.
.EXAMPLE
    $fileName = ConvertTo-ValidFileName -InputString "Project: 2023/04"
.OUTPUTS
    System.String - The sanitized filename
#>
function ConvertTo-ValidFileName {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$InputString,
        
        [Parameter(Mandatory=$false)]
        [char]$ReplacementChar = '_'
    )
    
    # Get invalid characters from .NET
    $invalidChars = [System.IO.Path]::GetInvalidFileNameChars()
    
    # Replace each invalid character
    $result = $InputString
    foreach ($char in $invalidChars) {
        if ($result.Contains($char)) {
            $result = $result.Replace($char, $ReplacementChar)
        }
    }
    
    return $result
}

<#
.SYNOPSIS
    Gets a temp file path.
.DESCRIPTION
    Creates a temporary file and returns its path.
.PARAMETER Prefix
    Optional prefix for the filename.
.PARAMETER Extension
    The file extension (without the dot).
.PARAMETER CreateFile
    If specified, creates an empty file at the path.
.EXAMPLE
    $tempFile = Get-TempFilePath -Prefix "export" -Extension "csv" -CreateFile
.OUTPUTS
    System.String - The path to the temporary file
#>
function Get-TempFilePath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)]
        [string]$Prefix = "",
        
        [Parameter(Mandatory=$false)]
        [string]$Extension = "tmp",
        
        [Parameter(Mandatory=$false)]
        [switch]$CreateFile
    )
    
    # Ensure extension doesn't start with a dot
    if ($Extension.StartsWith(".")) {
        $Extension = $Extension.Substring(1)
    }
    
    # Generate a unique filename in the temp directory
    $tempDir = [System.IO.Path]::GetTempPath()
    $fileName = if ([string]::IsNullOrEmpty($Prefix)) {
        [System.Guid]::NewGuid().ToString("N")
    } else {
        "$Prefix-$([System.Guid]::NewGuid().ToString("N"))"
    }
    
    $filePath = Join-PathSafely -Path $tempDir -ChildPath "$fileName.$Extension"
    
    # Create the file if requested
    if ($CreateFile) {
        try {
            [System.IO.File]::Create($filePath).Close()
        } catch {
            Write-Warning "Failed to create temp file: $($_.Exception.Message)"
        }
    }
    
    return $filePath
}

<#
.SYNOPSIS
    Converts a priority string to a numeric value for sorting.
.DESCRIPTION
    Converts priority strings (High, Normal, Low) to integers for consistent sorting.
.PARAMETER Priority
    The priority string to convert.
.EXAMPLE
    $sortedTodos = $todos | Sort-Object { Convert-PriorityToInt $_.Importance }
.OUTPUTS
    System.Int32 - The numeric priority value (lower is higher priority)
#>
function Convert-PriorityToInt {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)]
        $Priority
    )
    
    # Handle null or empty input first
    if ([string]::IsNullOrWhiteSpace($Priority)) {
        return 4 # Assign lowest priority (sorts last) if null/empty
    }
    
    # Convert to lower case for case-insensitive comparison
    $priorityLower = $Priority.ToString().ToLower()
    
    # Return numeric value based on priority
    switch ($priorityLower) {
        "high"   { return 1 }
        "normal" { return 2 }
        "medium" { return 2 } # Alias for normal
        "low"    { return 3 }
        default  { return 4 } # Unknown priority values sort last
    }
}

<#
.SYNOPSIS
    Creates a new GUID.
.DESCRIPTION
    Generates a new GUID in the specified format.
.PARAMETER Format
    The format of the GUID. Can be Full, Digits, or Compact.
.EXAMPLE
    $id = New-Guid -Format Compact
.OUTPUTS
    System.String - The GUID string
#>
function New-ID {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)]
        [ValidateSet("Full", "Digits", "Compact")]
        [string]$Format = "Full"
    )
    
    $guid = [System.Guid]::NewGuid()
    
    switch ($Format) {
        "Full" {
            return $guid.ToString("D") # "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
        }
        "Digits" {
            return $guid.ToString("N") # "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx"
        }
        "Compact" {
            # Use base64 encoding for a shorter representation
            $bytes = $guid.ToByteArray()
            return [Convert]::ToBase64String($bytes).TrimEnd('=').Replace('/', '_').Replace('+', '-')
        }
        default {
            return $guid.ToString()
        }
    }
}

<#
.SYNOPSIS
    Generates a random password.
.DESCRIPTION
    Creates a random password with configurable complexity.
.PARAMETER Length
    The length of the password.
.PARAMETER IncludeSpecialChars
    If specified, includes special characters.
.PARAMETER IncludeNumbers
    If specified, includes numeric characters.
.PARAMETER IncludeUppercase
    If specified, includes uppercase letters.
.PARAMETER IncludeLowercase
    If specified, includes lowercase letters.
.EXAMPLE
    $password = New-RandomPassword -Length 12 -IncludeSpecialChars -IncludeNumbers
.OUTPUTS
    System.String - The generated password
#>
function New-RandomPassword {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)]
        [int]$Length = 12,
        
        [Parameter(Mandatory=$false)]
        [switch]$IncludeSpecialChars,
        
        [Parameter(Mandatory=$false)]
        [switch]$IncludeNumbers = $true,
        
        [Parameter(Mandatory=$false)]
        [switch]$IncludeUppercase = $true,
        
        [Parameter(Mandatory=$false)]
        [switch]$IncludeLowercase = $true
    )
    
    # Define character sets
    $lowercase = "abcdefghijklmnopqrstuvwxyz"
    $uppercase = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    $numbers = "0123456789"
    $special = "!@#$%^&*()_-+={}[]|:;<>,.?/~"
    
    # Combine selected character sets
    $charSet = ""
    if ($IncludeLowercase) { $charSet += $lowercase }
    if ($IncludeUppercase) { $charSet += $uppercase }
    if ($IncludeNumbers) { $charSet += $numbers }
    if ($IncludeSpecialChars) { $charSet += $special }
    
    # Ensure at least one character set is selected
    if ([string]::IsNullOrEmpty($charSet)) {
        $charSet = $lowercase
    }
    
    # Generate password
    $random = New-Object System.Random
    $password = ""
    
    for ($i = 0; $i -lt $Length; $i++) {
        $password += $charSet[$random.Next(0, $charSet.Length)]
    }
    
    return $password
}

<#
.SYNOPSIS
    Converts bytes to a human-readable size.
.DESCRIPTION
    Converts a byte count to a human-readable size (KB, MB, GB, etc.).
.PARAMETER Bytes
    The number of bytes.
.PARAMETER Precision
    The number of decimal places to include.
.EXAMPLE
    $size = Convert-BytesToHumanReadable -Bytes 1536000
.OUTPUTS
    System.String - The formatted size
#>
function Convert-BytesToHumanReadable {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [long]$Bytes,
        
        [Parameter(Mandatory=$false)]
        [int]$Precision = 2
    )
    
    $sizes = @("B", "KB", "MB", "GB", "TB", "PB")
    $order = 0
    
    while ($Bytes -ge 1024 -and $order -lt $sizes.Count - 1) {
        $Bytes /= 1024
        $order++
    }
    
    return "{0:N$Precision} {1}" -f $Bytes, $sizes[$order]
}

<#
.SYNOPSIS
    Gets the position of the substring in a string, ignoring case.
.DESCRIPTION
    Returns the position of the substring in a string, with case-insensitive comparison.
.PARAMETER String
    The string to search in.
.PARAMETER SubString
    The substring to find.
.PARAMETER StartIndex
    The starting position of the search.
.EXAMPLE
    $pos = Find-SubstringPosition -String "Hello World" -SubString "world"
.OUTPUTS
    System.Int32 - The position of the substring, or -1 if not found
#>
function Find-SubstringPosition {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$String,
        
        [Parameter(Mandatory=$true)]
        [string]$SubString,
        
        [Parameter(Mandatory=$false)]
        [int]$StartIndex = 0
    )
    
    if ([string]::IsNullOrEmpty($String) -or [string]::IsNullOrEmpty($SubString)) {
        return -1
    }
    
    return $String.ToLower().IndexOf($SubString.ToLower(), $StartIndex)
}

<#
.SYNOPSIS
    Slugifies a string for use in URLs or filenames.
.DESCRIPTION
    Converts a string to a URL-friendly slug.
.PARAMETER Text
    The text to slugify.
.PARAMETER Separator
    The separator character to use. Default is '-'.
.EXAMPLE
    $slug = Convert-ToSlug -Text "Hello World! This is a test."
.OUTPUTS
    System.String - The slugified string
#>
function Convert-ToSlug {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Text,
        
        [Parameter(Mandatory=$false)]
        [string]$Separator = "-"
    )
    
    # Convert to lowercase
    $result = $Text.ToLower()
    
    # Remove accents/diacritics
    $normalizedString = $result.Normalize([System.Text.NormalizationForm]::FormD)
    $stringBuilder = New-Object System.Text.StringBuilder
    
    foreach ($char in $normalizedString.ToCharArray()) {
        $unicodeCategory = [System.Globalization.CharUnicodeInfo]::GetUnicodeCategory($char)
        if ($unicodeCategory -ne [System.Globalization.UnicodeCategory]::NonSpacingMark) {
            [void]$stringBuilder.Append($char)
        }
    }
    
    $result = $stringBuilder.ToString().Normalize([System.Text.NormalizationForm]::FormC)
    
    # Replace spaces with the separator
    $result = $result -replace '\s+', $Separator
    
    # Remove invalid characters
    $result = $result -replace '[^a-z0-9\-_]', ''
    
    # Remove multiple consecutive separators
    $result = $result -replace "$Separator{2,}", $Separator
    
    # Remove separator from beginning and end
    $result = $result.Trim($Separator)
    
    return $result
}

# Export functions
Export-ModuleMember -Function Read-UserInput, Confirm-Action, New-MenuItems, Show-Confirmation,
                     Get-EnvironmentVariable, Join-PathSafely, Ensure-DirectoryExists,
                     Get-UniqueFileName, ConvertTo-ValidFileName, Get-TempFilePath,
                     Convert-PriorityToInt, New-ID, New-RandomPassword,
                     Convert-BytesToHumanReadable, Find-SubstringPosition, Convert-ToSlug
