# lib/data-functions.ps1
# Data Access Layer for Project Tracker
# Provides consistent data storage, retrieval, and validation for all entity types

<#
.SYNOPSIS
    Ensures a directory exists, creating it if necessary.
.DESCRIPTION
    Checks if the specified directory exists and creates it if it doesn't.
    Returns $true if the directory exists or was created successfully, $false otherwise.
.PARAMETER Path
    The directory path to check or create.
.EXAMPLE
    if (Ensure-DirectoryExists -Path "C:\Data\Projects") {
        # Directory exists or was created
    }
.OUTPUTS
    System.Boolean - True if directory exists or was created, False otherwise
#>
function Ensure-DirectoryExists {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Path
    )
    
    if (-not (Test-Path $Path -PathType Container)) {
        try {
            New-Item -ItemType Directory -Path $Path -Force | Out-Null
            Write-Verbose "Created directory: $Path"
            return $true
        } catch {
            if (Get-Command "Handle-Error" -ErrorAction SilentlyContinue) {
                Handle-Error -ErrorRecord $_ -Context "Creating directory '$Path'" -Continue
            } else {
                Write-Warning "ERROR creating directory '$Path': $($_.Exception.Message)"
            }
            return $false
        }
    }
    return $true
}

<#
.SYNOPSIS
    Retrieves entity data from a CSV file with validation and error handling.
.DESCRIPTION
    Loads data from a CSV file, ensures required headers are present,
    adds missing properties with default values, and handles various error conditions.
    Returns an array of objects representing the data.
.PARAMETER FilePath
    The path to the CSV file.
.PARAMETER RequiredHeaders
    Array of header names that must be present in the file.
.PARAMETER DefaultValues
    Hashtable of default values for headers that might be missing.
.PARAMETER CreateIfNotExists
    If specified, creates the file with required headers if it doesn't exist.
.EXAMPLE
    $projects = Get-EntityData -FilePath $config.ProjectsFullPath -RequiredHeaders $projectHeaders -CreateIfNotExists
.OUTPUTS
    System.Array - Array of objects representing the data, or empty array if the file doesn't exist or has errors
#>
function Get-EntityData {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$FilePath,
        
        [Parameter(Mandatory=$false)]
        [string[]]$RequiredHeaders,
        
        [Parameter(Mandatory=$false)]
        [hashtable]$DefaultValues = @{},
        
        [Parameter(Mandatory=$false)]
        [switch]$CreateIfNotExists
    )
    
    # Check if file exists
    if (-not (Test-Path $FilePath)) {
        Write-Verbose "File not found: '$FilePath'."
        
        if ($CreateIfNotExists -and $RequiredHeaders -and $RequiredHeaders.Count -gt 0) {
            # Create directory if it doesn't exist
            $directory = Split-Path -Parent $FilePath
            if (-not (Ensure-DirectoryExists -Path $directory)) {
                return @() # Couldn't create directory
            }
            
            try {
                # Create the file with headers
                $RequiredHeaders -join "," | Out-File $FilePath -Encoding utf8
                Write-Verbose "Created file with headers: '$FilePath'."
                
                # Log the creation if logging is available
                if (Get-Command "Write-AppLog" -ErrorAction SilentlyContinue) {
                    Write-AppLog "Created data file with headers: $FilePath" -Level INFO
                }
                
                return @() # Return empty array as no data exists yet
            } catch {
                if (Get-Command "Handle-Error" -ErrorAction SilentlyContinue) {
                    Handle-Error -ErrorRecord $_ -Context "Creating data file '$FilePath'" -Continue
                } else {
                    Write-Warning "ERROR: Failed to create data file '$FilePath': $($_.Exception.Message)"
                }
                return @()
            }
        }
        
        return @() # Return empty array if file doesn't exist
    }
    
    try {
        # Always wrap Import-Csv result in @() to ensure it's an array
        $data = @(Import-Csv -Path $FilePath -Encoding UTF8)
        
        # Check and add missing headers/properties if needed
        if ($RequiredHeaders -and $RequiredHeaders.Count -gt 0 -and $data.Count -gt 0) {
            $currentHeaders = $data[0].PSObject.Properties.Name
            $missingHeaders = $RequiredHeaders | Where-Object { $currentHeaders -notcontains $_ }
            
            if ($missingHeaders.Count -gt 0) {
                Write-Verbose "File is missing columns: $($missingHeaders -join ', '). Adding them."
                
                foreach ($item in $data) {
                    foreach ($header in $missingHeaders) {
                        $defaultValue = if ($DefaultValues.ContainsKey($header)) { $DefaultValues[$header] } else { "" }
                        Add-Member -InputObject $item -MemberType NoteProperty -Name $header -Value $defaultValue -Force
                    }
                }
                
                # Log the modification if logging is available
                if (Get-Command "Write-AppLog" -ErrorAction SilentlyContinue) {
                    Write-AppLog "Added missing columns to file: $FilePath" -Level INFO
                }
            }
        }
        
        return $data
    } catch {
        if (Get-Command "Handle-Error" -ErrorAction SilentlyContinue) {
            Handle-Error -ErrorRecord $_ -Context "Loading data from '$FilePath'" -Continue
        } else {
            Write-Warning "ERROR: Failed to load data from '$FilePath': $($_.Exception.Message)"
        }
        return @() # Return empty array on error
    }
}

<#
.SYNOPSIS
    Saves entity data to a CSV file with error handling and backups.
.DESCRIPTION
    Saves an array of objects to a CSV file, creating a backup first,
    ensuring the directory exists, and handling various error conditions.
    Returns $true if the save was successful, $false otherwise.
.PARAMETER Data
    The array of objects to save.
.PARAMETER FilePath
    The path to the CSV file.
.PARAMETER RequiredHeaders
    Optional array of header names to include in the output (filters out other properties).
.PARAMETER NoBackup
    If specified, skips creating a backup of the existing file.
.EXAMPLE
    $success = Save-EntityData -Data $projects -FilePath $config.ProjectsFullPath -RequiredHeaders $projectHeaders
.OUTPUTS
    System.Boolean - True if the save was successful, False otherwise
#>
function Save-EntityData {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [array]$Data,
        
        [Parameter(Mandatory=$true)]
        [string]$FilePath,
        
        [Parameter(Mandatory=$false)]
        [string[]]$RequiredHeaders,
        
        [Parameter(Mandatory=$false)]
        [switch]$NoBackup
    )
    
    $backupPath = "$FilePath.bak"
    try {
        # Create backup of existing file unless NoBackup is specified
        if (-not $NoBackup -and (Test-Path $FilePath)) {
            Copy-Item -Path $FilePath -Destination $backupPath -Force -ErrorAction Stop
            Write-Verbose "Created backup of '$FilePath' at '$backupPath'."
        }
        
        # Ensure directory exists
        $directory = Split-Path -Parent $FilePath
        if (-not (Ensure-DirectoryExists -Path $directory)) {
            return $false # Couldn't create directory
        }
        
        # Save data with the specified headers (if provided)
        if ($RequiredHeaders -and $RequiredHeaders.Count -gt 0) {
            $Data | Select-Object -Property $RequiredHeaders | Export-Csv -Path $FilePath -NoTypeInformation -Encoding UTF8
        } else {
            $Data | Export-Csv -Path $FilePath -NoTypeInformation -Encoding UTF8
        }
        
        # Log the save if logging is available
        if (Get-Command "Write-AppLog" -ErrorAction SilentlyContinue) {
            Write-AppLog "Saved data to file: $FilePath (Items: $($Data.Count))" -Level INFO
        }
        
        return $true
    } catch {
        if (Get-Command "Handle-Error" -ErrorAction SilentlyContinue) {
            Handle-Error -ErrorRecord $_ -Context "Saving data to '$FilePath'" -Continue
        } else {
            Write-Warning "ERROR saving data to '$FilePath': $($_.Exception.Message)"
        }
        
        # Try to restore from backup if available
        if (-not $NoBackup -and (Test-Path $backupPath)) {
            try {
                Copy-Item -Path $backupPath -Destination $FilePath -Force
                Write-Verbose "Restored file from backup."
                
                if (Get-Command "Write-AppLog" -ErrorAction SilentlyContinue) {
                    Write-AppLog "Restored file from backup after save error: $FilePath" -Level WARNING
                }
            } catch {
                if (Get-Command "Handle-Error" -ErrorAction SilentlyContinue) {
                    Handle-Error -ErrorRecord $_ -Context "Restoring backup for '$FilePath'" -Continue
                } else {
                    Write-Warning "ERROR restoring backup for '$FilePath': $($_.Exception.Message)"
                }
            }
        }
        
        return $false
    }
}

<#
.SYNOPSIS
    Updates the cumulative hours for a project.
.DESCRIPTION
    Calculates and updates the cumulative hours for a project based on time entries.
    Reads time entries, sums the hours, and updates the project's CumulativeHrs field.
.PARAMETER Nickname
    The project nickname to update.
.PARAMETER Config
    Optional configuration object.
.EXAMPLE
    Update-CumulativeHours -Nickname "WEBSITE"
.OUTPUTS
    System.Boolean - True if the update was successful, False otherwise
#>
function Update-CumulativeHours {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Nickname,
        
        [Parameter(Mandatory=$false)]
        [hashtable]$Config = $null
    )
    
    if ([string]::IsNullOrWhiteSpace($Nickname)) {
        Write-Verbose "Update-CumulativeHours: Empty nickname."
        return $false
    }
    
    # Get configuration if not provided
    if ($null -eq $Config) {
        if (Get-Command "Get-AppConfig" -ErrorAction SilentlyContinue) {
            try {
                $Config = Get-AppConfig
            } catch {
                if (Get-Command "Handle-Error" -ErrorAction SilentlyContinue) {
                    Handle-Error -ErrorRecord $_ -Context "Getting configuration in Update-CumulativeHours" -Continue
                } else {
                    Write-Warning "ERROR: Failed to get configuration: $($_.Exception.Message)"
                }
                return $false
            }
        } else {
            Write-Warning "ERROR: Configuration not available."
            return $false
        }
    }
    
    # Get projects
    try {
        $projects = @(Get-EntityData -FilePath $Config.ProjectsFullPath -RequiredHeaders $Config.ProjectsHeaders)
        $project = $projects | Where-Object { $_.Nickname -eq $Nickname } | Select-Object -First 1
        
        if (-not $project) {
            Write-Verbose "Update-CumulativeHours: Project '$Nickname' not found."
            return $false
        }
        
        # Get time entries
        $timeEntries = @(Get-EntityData -FilePath $Config.TimeLogFullPath | Where-Object { $_.Nickname -eq $Nickname })
        
        $totalHours = 0.0
        foreach ($entry in $timeEntries) {
            $dailyTotal = 0.0
            $weekDays = @("MonHours", "TueHours", "WedHours", "ThuHours", "FriHours", "SatHours", "SunHours")
            
            foreach ($day in $weekDays) {
                if ($entry.PSObject.Properties.Name -contains $day -and -not [string]::IsNullOrWhiteSpace($entry.$day)) {
                    $hours = 0.0
                    if ([double]::TryParse($entry.$day, [ref]$hours)) {
                        $dailyTotal += $hours
                    }
                }
            }
            
            # If daily breakdown is empty but total exists, use the total
            if ($entry.PSObject.Properties.Name -contains 'TotalHours' -and
                -not [string]::IsNullOrWhiteSpace($entry.TotalHours) -and
                $dailyTotal -eq 0.0) {
                $hours = 0.0
                if ([double]::TryParse($entry.TotalHours, [ref]$hours)) {
                    $totalHours += $hours
                }
            } else {
                $totalHours += $dailyTotal
            }
        }
        
        # Update the project's cumulative hours
        $project.CumulativeHrs = $totalHours.ToString("F2")
        
        # Save projects
        if (Save-EntityData -Data $projects -FilePath $Config.ProjectsFullPath -RequiredHeaders $Config.ProjectsHeaders) {
            Write-Verbose "Updated cumulative hours for project '$Nickname': $($project.CumulativeHrs) hours"
            
            if (Get-Command "Write-AppLog" -ErrorAction SilentlyContinue) {
                Write-AppLog "Updated cumulative hours for project '$Nickname': $($project.CumulativeHrs) hours" -Level INFO
            }
            
            return $true
        } else {
            return $false
        }
    } catch {
        if (Get-Command "Handle-Error" -ErrorAction SilentlyContinue) {
            Handle-Error -ErrorRecord $_ -Context "Updating cumulative hours for project '$Nickname'" -Continue
        } else {
            Write-Warning "ERROR: Failed to update cumulative hours: $($_.Exception.Message)"
        }
        return $false
    }
}

<#
.SYNOPSIS
    Initializes the data environment.
.DESCRIPTION
    Creates necessary directories and ensures required data files exist.
    Called at application startup to ensure a valid data environment.
.PARAMETER Config
    Optional configuration object.
.EXAMPLE
    Initialize-DataEnvironment
.OUTPUTS
    System.Boolean - True if initialization was successful, False otherwise
#>
function Initialize-DataEnvironment {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)]
        [hashtable]$Config = $null
    )
    
    Write-Verbose "Initializing data environment..."
    
    # Get configuration if not provided
    if ($null -eq $Config) {
        if (Get-Command "Get-AppConfig" -ErrorAction SilentlyContinue) {
            try {
                $Config = Get-AppConfig
            } catch {
                if (Get-Command "Handle-Error" -ErrorAction SilentlyContinue) {
                    Handle-Error -ErrorRecord $_ -Context "Getting configuration in Initialize-DataEnvironment" -Continue
                } else {
                    Write-Warning "ERROR: Failed to get configuration: $($_.Exception.Message)"
                }
                return $false
            }
        } else {
            Write-Warning "ERROR: Configuration not available."
            return $false
        }
    }
    
    # Create data directory
    if (-not (Ensure-DirectoryExists -Path $Config.BaseDataDir)) {
        return $false
    }
    
    # Define required headers for each entity type
    $projectsHeaders = @(
        "FullProjectName", "Nickname", "ID1", "ID2", "DateAssigned",
        "DueDate", "BFDate", "CumulativeHrs", "Note", "ProjFolder",
        "ClosedDate", "Status"
    )
    
    $todoHeaders = @(
        "ID", "Nickname", "TaskDescription", "Importance", "DueDate", 
        "Status", "CreatedDate", "CompletedDate"
    )
    
    $timeHeaders = @(
        "EntryID", "Date", "WeekStartDate", "Nickname", "ID1", "ID2",
        "Description", "MonHours", "TueHours", "WedHours", "ThuHours", 
        "FriHours", "SatHours", "SunHours", "TotalHours"
    )
    
    $notesHeaders = @(
        "NoteID", "Nickname", "DateCreated", "Title", "Content", "Tags"
    )
    
    # Ensure data files exist with required headers
    try {
        # Projects
        Get-EntityData -FilePath $Config.ProjectsFullPath -RequiredHeaders $projectsHeaders -CreateIfNotExists | Out-Null
        
        # Todos
        Get-EntityData -FilePath $Config.TodosFullPath -RequiredHeaders $todoHeaders -CreateIfNotExists | Out-Null
        
        # Time Entries
        Get-EntityData -FilePath $Config.TimeLogFullPath -RequiredHeaders $timeHeaders -CreateIfNotExists | Out-Null
        
        # Notes (if configured)
        if ($Config.ContainsKey("NotesFullPath")) {
            Get-EntityData -FilePath $Config.NotesFullPath -RequiredHeaders $notesHeaders -CreateIfNotExists | Out-Null
        }
        
        if (Get-Command "Write-AppLog" -ErrorAction SilentlyContinue) {
            Write-AppLog "Data environment initialization complete" -Level INFO
        }
        
        return $true
    } catch {
        if (Get-Command "Handle-Error" -ErrorAction SilentlyContinue) {
            Handle-Error -ErrorRecord $_ -Context "Initializing data environment" -Continue
        } else {
            Write-Warning "ERROR: Failed to initialize data environment: $($_.Exception.Message)"
        }
        return $false
    }
}

<#
.SYNOPSIS
    Gets an entity by ID.
.DESCRIPTION
    Retrieves a specific entity from a data file based on its ID.
    Useful for finding a specific project, todo, or time entry.
.PARAMETER FilePath
    The path to the CSV file.
.PARAMETER IdField
    The name of the ID field.
.PARAMETER IdValue
    The ID value to search for.
.EXAMPLE
    $todo = Get-EntityById -FilePath $config.TodosFullPath -IdField "ID" -IdValue "123e4567-e89b-12d3-a456-426614174000"
.OUTPUTS
    System.Object - The entity if found, $null otherwise
#>
function Get-EntityById {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$FilePath,
        
        [Parameter(Mandatory=$true)]
        [string]$IdField,
        
        [Parameter(Mandatory=$true)]
        [string]$IdValue
    )
    
    try {
        $entities = @(Get-EntityData -FilePath $FilePath)
        return $entities | Where-Object { $_.$IdField -eq $IdValue } | Select-Object -First 1
    } catch {
        if (Get-Command "Handle-Error" -ErrorAction SilentlyContinue) {
            Handle-Error -ErrorRecord $_ -Context "Getting entity by ID" -Continue
        } else {
            Write-Warning "ERROR: Failed to get entity by ID: $($_.Exception.Message)"
        }
        return $null
    }
}

<#
.SYNOPSIS
    Updates an entity by ID.
.DESCRIPTION
    Updates a specific entity in a data file based on its ID.
    Replaces the existing entity with the updated one.
.PARAMETER FilePath
    The path to the CSV file.
.PARAMETER IdField
    The name of the ID field.
.PARAMETER Entity
    The updated entity object.
.PARAMETER RequiredHeaders
    Optional array of header names to include in the output.
.EXAMPLE
    $success = Update-EntityById -FilePath $config.TodosFullPath -IdField "ID" -Entity $updatedTodo -RequiredHeaders $todoHeaders
.OUTPUTS
    System.Boolean - True if the update was successful, False otherwise
#>
function Update-EntityById {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$FilePath,
        
        [Parameter(Mandatory=$true)]
        [string]$IdField,
        
        [Parameter(Mandatory=$true)]
        [PSObject]$Entity,
        
        [Parameter(Mandatory=$false)]
        [string[]]$RequiredHeaders
    )
    
    try {
        # Get all entities
        $entities = @(Get-EntityData -FilePath $FilePath)
        
        # Ensure entity has the ID field
        if (-not $Entity.PSObject.Properties.Name.Contains($IdField)) {
            Write-Warning "Entity does not have the required ID field: $IdField"
            return $false
        }
        
        $idValue = $Entity.$IdField
        
        # Check if entity exists
        $exists = $entities | Where-Object { $_.$IdField -eq $idValue } | Select-Object -First 1
        if (-not $exists) {
            Write-Warning "Entity with $IdField = $idValue not found"
            return $false
        }
        
        # Create updated entities array
        $updatedEntities = @()
        foreach ($item in $entities) {
            if ($item.$IdField -eq $idValue) {
                $updatedEntities += $Entity # Add the updated entity
            } else {
                $updatedEntities += $item # Add unchanged entity
            }
        }
        
        # Save updated entities
        return Save-EntityData -Data $updatedEntities -FilePath $FilePath -RequiredHeaders $RequiredHeaders
    } catch {
        if (Get-Command "Handle-Error" -ErrorAction SilentlyContinue) {
            Handle-Error -ErrorRecord $_ -Context "Updating entity by ID" -Continue
        } else {
            Write-Warning "ERROR: Failed to update entity by ID: $($_.Exception.Message)"
        }
        return $false
    }
}

<#
.SYNOPSIS
    Removes an entity by ID.
.DESCRIPTION
    Removes a specific entity from a data file based on its ID.
.PARAMETER FilePath
    The path to the CSV file.
.PARAMETER IdField
    The name of the ID field.
.PARAMETER IdValue
    The ID value to remove.
.PARAMETER RequiredHeaders
    Optional array of header names to include in the output.
.EXAMPLE
    $success = Remove-EntityById -FilePath $config.TodosFullPath -IdField "ID" -IdValue "123e4567-e89b-12d3-a456-426614174000" -RequiredHeaders $todoHeaders
.OUTPUTS
    System.Boolean - True if the removal was successful, False otherwise
#>
function Remove-EntityById {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$FilePath,
        
        [Parameter(Mandatory=$true)]
        [string]$IdField,
        
        [Parameter(Mandatory=$true)]
        [string]$IdValue,
        
        [Parameter(Mandatory=$false)]
        [string[]]$RequiredHeaders
    )
    
    try {
        # Get all entities
        $entities = @(Get-EntityData -FilePath $FilePath)
        
        # Check if entity exists
        $exists = $entities | Where-Object { $_.$IdField -eq $IdValue } | Select-Object -First 1
        if (-not $exists) {
            Write-Warning "Entity with $IdField = $IdValue not found"
            return $false
        }
        
        # Remove the entity
        $updatedEntities = $entities | Where-Object { $_.$IdField -ne $IdValue }
        
        # Save updated entities
        $result = Save-EntityData -Data $updatedEntities -FilePath $FilePath -RequiredHeaders $RequiredHeaders
        
        if ($result -and (Get-Command "Write-AppLog" -ErrorAction SilentlyContinue)) {
            Write-AppLog "Removed entity with $IdField = $IdValue from $FilePath" -Level INFO
        }
        
        return $result
    } catch {
        if (Get-Command "Handle-Error" -ErrorAction SilentlyContinue) {
            Handle-Error -ErrorRecord $_ -Context "Removing entity by ID" -Continue
        } else {
            Write-Warning "ERROR: Failed to remove entity by ID: $($_.Exception.Message)"
        }
        return $false
    }
}

<#
.SYNOPSIS
    Creates a new entity with optional validation.
.DESCRIPTION
    Creates a new entity and adds it to a data file.
    Optionally validates the entity against required fields.
.PARAMETER FilePath
    The path to the CSV file.
.PARAMETER Entity
    The entity object to create.
.PARAMETER RequiredHeaders
    Optional array of header names to include in the output.
.PARAMETER RequiredFields
    Optional array of field names that must have values.
.EXAMPLE
    $success = Create-Entity -FilePath $config.TodosFullPath -Entity $newTodo -RequiredHeaders $todoHeaders -RequiredFields @("Nickname", "TaskDescription", "DueDate")
.OUTPUTS
    System.Boolean - True if the creation was successful, False otherwise
#>
function Create-Entity {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$FilePath,
        
        [Parameter(Mandatory=$true)]
        [PSObject]$Entity,
        
        [Parameter(Mandatory=$false)]
        [string[]]$RequiredHeaders,
        
        [Parameter(Mandatory=$false)]
        [string[]]$RequiredFields
    )
    
    try {
        # Validate required fields if specified
        if ($RequiredFields -and $RequiredFields.Count -gt 0) {
            foreach ($field in $RequiredFields) {
                if (-not $Entity.PSObject.Properties.Name.Contains($field) -or 
                    [string]::IsNullOrWhiteSpace($Entity.$field)) {
                    Write-Warning "Entity is missing required field: $field"
                    return $false
                }
            }
        }
        
        # Get existing entities
        $entities = @(Get-EntityData -FilePath $FilePath)
        
        # Add the new entity
        $updatedEntities = $entities + $Entity
        
        # Save updated entities
        $result = Save-EntityData -Data $updatedEntities -FilePath $FilePath -RequiredHeaders $RequiredHeaders
        
        if ($result -and (Get-Command "Write-AppLog" -ErrorAction SilentlyContinue)) {
            $idField = if ($Entity.PSObject.Properties.Name.Contains("ID")) { "ID" } else { "EntryID" }
            $idValue = if ($Entity.PSObject.Properties.Name.Contains($idField)) { $Entity.$idField } else { "N/A" }
            Write-AppLog "Created new entity with $idField = $idValue in $FilePath" -Level INFO
        }
        
        return $result
    } catch {
        if (Get-Command "Handle-Error" -ErrorAction SilentlyContinue) {
            Handle-Error -ErrorRecord $_ -Context "Creating new entity" -Continue
        } else {
            Write-Warning "ERROR: Failed to create new entity: $($_.Exception.Message)"
        }
        return $false
    }
}

# Export functions
Export-ModuleMember -Function Ensure-DirectoryExists, Get-EntityData, Save-EntityData,
                    Update-CumulativeHours, Initialize-DataEnvironment, Get-EntityById,
                    Update-EntityById, Remove-EntityById, Create-Entity
