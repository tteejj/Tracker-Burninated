# Test-DataFiles.ps1
# Script to verify that data files are properly created during initialization

# Set error action preference to stop so we fail early if there's an issue
$ErrorActionPreference = 'Stop'

# Get the script's directory
$scriptDir = $PSScriptRoot

# Bold text function for output formatting
function Write-BoldText {
    param([string]$Text, [string]$Color = "Green")
    Write-Host $Text -ForegroundColor $Color -BackgroundColor Black
}

# Function to test data file existence and structure
function Test-DataFile {
    param(
        [string]$FilePath, 
        [string]$Description, 
        [string[]]$RequiredHeaders
    )
    
    Write-Host "Testing $Description ($FilePath)..." -NoNewline
    
    if (-not (Test-Path $FilePath)) {
        Write-Host "✗ File does not exist!" -ForegroundColor Red
        return $false
    }
    
    # Test if file is a valid CSV
    try {
        $data = Import-Csv -Path $FilePath -ErrorAction Stop
        
        # Check if headers exist
        $headersPresent = $true
        if ($data.Count -gt 0) {
            $actualHeaders = $data[0].PSObject.Properties.Name
            
            foreach ($requiredHeader in $RequiredHeaders) {
                if ($actualHeaders -notcontains $requiredHeader) {
                    $headersPresent = $false
                    Write-Host "✗ Missing required header '$requiredHeader'" -ForegroundColor Red
                }
            }
        } else {
            # File exists but may be empty - check using Get-Content for headers
            $firstLine = Get-Content -Path $FilePath -TotalCount 1
            
            # Check if headers are present in the first line
            $headersPresent = $true
            foreach ($requiredHeader in $RequiredHeaders) {
                if ($firstLine -notmatch $requiredHeader) {
                    $headersPresent = $false
                    Write-Host "✗ Missing required header '$requiredHeader' in empty file" -ForegroundColor Red
                }
            }
        }
        
        if ($headersPresent) {
            Write-Host "✓ File exists and contains all required headers" -ForegroundColor Green
            return $true
        } else {
            Write-Host "✗ File exists but is missing required headers" -ForegroundColor Red
            return $false
        }
    } catch {
        Write-Host "✗ Failed to read CSV file: $_" -ForegroundColor Red
        return $false
    }
}

# Import required modules
Write-BoldText "Importing required modules"
try {
    Import-Module -Name "$scriptDir\Modules\ProjectTracker.Core\ProjectTracker.Core.psd1" -Force -ErrorAction Stop
    Write-Host "✓ Core module imported successfully" -ForegroundColor Green
} catch {
    Write-Host "✗ Failed to import Core module: $_" -ForegroundColor Red
    exit 1
}

# Initialize data environment 
Write-BoldText "`nInitializing data environment"
try {
    $result = Initialize-DataEnvironment
    if ($result) {
        Write-Host "✓ Data environment initialized successfully" -ForegroundColor Green
    } else {
        Write-Host "✗ Data environment initialization returned false" -ForegroundColor Red
    }
} catch {
    Write-Host "✗ Failed to initialize data environment: $_" -ForegroundColor Red
    exit 1
}

# Get configuration to find file paths
$config = Get-AppConfig

# Check for data directory
Write-BoldText "`nVerifying data directory"
if (Test-Path -Path $config.BaseDataDir -PathType Container) {
    Write-Host "✓ Base data directory exists: $($config.BaseDataDir)" -ForegroundColor Green
} else {
    Write-Host "✗ Base data directory does not exist: $($config.BaseDataDir)" -ForegroundColor Red
}

# Check for themes directory
Write-BoldText "`nVerifying themes directory"
if (Test-Path -Path $config.ThemesDir -PathType Container) {
    Write-Host "✓ Themes directory exists: $($config.ThemesDir)" -ForegroundColor Green
} else {
    Write-Host "✗ Themes directory does not exist: $($config.ThemesDir)" -ForegroundColor Red
}

# Test data files existence and structure
Write-BoldText "`nVerifying data files"

# Projects file
$projectsHeaders = @(
    "FullProjectName", "Nickname", "ID1", "ID2", "DateAssigned",
    "DueDate", "BFDate", "CumulativeHrs", "Note", "ProjFolder",
    "ClosedDate", "Status"
)
Test-DataFile -FilePath $config.ProjectsFullPath -Description "Projects file" -RequiredHeaders $projectsHeaders

# Todos file
$todosHeaders = @(
    "ID", "Nickname", "TaskDescription", "Importance", "DueDate",
    "Status", "CreatedDate", "CompletedDate"
)
Test-DataFile -FilePath $config.TodosFullPath -Description "Todos file" -RequiredHeaders $todosHeaders

# Time entries file
$timeHeaders = @(
    "EntryID", "Date", "WeekStartDate", "Nickname", "ID1", "ID2",
    "Description", "MonHours", "TueHours", "WedHours", "ThuHours",
    "FriHours", "SatHours", "SunHours", "TotalHours"
)
Test-DataFile -FilePath $config.TimeLogFullPath -Description "Time tracking file" -RequiredHeaders $timeHeaders

# Notes file (if defined)
if ($config.NotesFullPath) {
    $notesHeaders = @(
        "NoteID", "Nickname", "DateCreated", "Title", "Content", "Tags"
    )
    Test-DataFile -FilePath $config.NotesFullPath -Description "Notes file" -RequiredHeaders $notesHeaders
}

# Commands file (if defined)
if ($config.CommandsFullPath) {
    $commandsHeaders = @(
        "CommandID", "Name", "Description", "CommandText", "DateCreated", "Tags"
    )
    Test-DataFile -FilePath $config.CommandsFullPath -Description "Commands file" -RequiredHeaders $commandsHeaders
}

# Check config file
Write-BoldText "`nVerifying configuration file"
$configFilePath = Join-Path $config.BaseDataDir "config.json"
if (Test-Path $configFilePath) {
    Write-Host "✓ Config file exists: $configFilePath" -ForegroundColor Green
    
    # Try to read it as JSON
    try {
        $configContent = Get-Content -Path $configFilePath -Raw | ConvertFrom-Json
        Write-Host "✓ Config file is valid JSON" -ForegroundColor Green
    } catch {
        Write-Host "✗ Config file exists but is not valid JSON: $_" -ForegroundColor Red
    }
} else {
    Write-Host "✗ Config file does not exist: $configFilePath" -ForegroundColor Red
}

Write-BoldText "`nData file testing completed" -ForegroundColor Cyan