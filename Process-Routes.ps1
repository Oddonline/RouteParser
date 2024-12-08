# Process-Routes.ps1
param(
    [Parameter(Mandatory=$true)]
    [string]$XmlFolderPath,
    
    [Parameter(Mandatory=$false)]
    [string]$OutputPath = ".\RouteData",
    
    [Parameter(Mandatory=$false)]
    [switch]$GenerateDeltaOnly
)

# Initialize
$ErrorActionPreference = 'Stop'
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
Import-Module "$PSScriptRoot\XmlProcessor.psm1" -Force

# Function to extract route number from filename
function Get-RouteNumber {
    param([string]$fileName)
    if ($fileName -match "_(\d{4})_") {
        return $matches[1]
    }
    throw "Could not extract route number from filename: $fileName"
}

# Create base directories
$paths = @{
    Current = Join-Path $OutputPath "current"
    Archive = Join-Path $OutputPath "archive\$timestamp"
    Delta = Join-Path $OutputPath "delta\$timestamp"
    Logs = Join-Path $OutputPath "logs"
}

foreach ($dir in $paths.Values) {
    if (-not (Test-Path $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
}

$logFile = Join-Path $paths.Logs "process_$timestamp.log"

function Write-Log {
    param($Message)
    $logMessage = "$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss'): $Message"
    Add-Content -Path $logFile -Value $logMessage
    Write-Host $logMessage
}

function Get-EntityChanges {
    param(
        $CurrentData,
        $NewData,
        $IdField = 'id'
    )
    
    $changes = @{
        Added = @()
        Modified = @()
        Deleted = @()
        Unchanged = @()
    }
    
    # Create lookup tables
    $currentLookup = @{}
    $newLookup = @{}
    
    if ($CurrentData) {
        $CurrentData | ForEach-Object { $currentLookup[$_.$IdField] = $_ }
    }
    if ($NewData) {
        $NewData | ForEach-Object { $newLookup[$_.$IdField] = $_ }
    }
    
    # Find added and modified
    foreach ($id in $newLookup.Keys) {
        if (-not $currentLookup.ContainsKey($id)) {
            $changes.Added += $newLookup[$id]
        }
        else {
            $newJson = $newLookup[$id] | ConvertTo-Json -Compress
            $currentJson = $currentLookup[$id] | ConvertTo-Json -Compress
            if ($newJson -ne $currentJson) {
                $changes.Modified += $newLookup[$id]
            }
            else {
                $changes.Unchanged += $newLookup[$id]
            }
        }
    }
    
    # Find deleted
    foreach ($id in $currentLookup.Keys) {
        if (-not $newLookup.ContainsKey($id)) {
            $changes.Deleted += $currentLookup[$id]
        }
    }
    
    return $changes
}

# Get all XML files in the folder
$xmlFiles = Get-ChildItem -Path $XmlFolderPath -Filter "NOR_NOR-Line-*.xml"
Write-Log "Found $($xmlFiles.Count) XML files to process"

foreach ($xmlFile in $xmlFiles) {
    try {
        Write-Log "Processing $($xmlFile.Name)"
        $routeNumber = Get-RouteNumber $xmlFile.Name
        
        # Set up route-specific paths
        $routePaths = @{
            Current = Join-Path $paths.Current $routeNumber
            Archive = Join-Path $paths.Archive $routeNumber
            Delta = Join-Path $paths.Delta $routeNumber
        }
        
        # Create route directories
        foreach ($dir in $routePaths.Values) {
            if (-not (Test-Path $dir)) {
                New-Item -ItemType Directory -Path $dir -Force | Out-Null
            }
        }

        # Process XML
        $xml = New-Object System.Xml.XmlDocument
        $xml.PreserveWhitespace = $true
        $content = Get-Content -Path $xmlFile.FullName -Encoding UTF8 -Raw
        $xml.LoadXml($content)
        
        # Setup namespace manager
        $nsManager = New-Object System.Xml.XmlNamespaceManager($xml.NameTable)
        $nsManager.AddNamespace("a", "http://www.netex.org.uk/netex")
        
        # Process each entity type
        $entityTypes = @(
            @{ Name = "lines"; IdField = "LineId" },
            @{ Name = "routes"; IdField = "RouteId" },
            @{ Name = "route_points"; IdField = "PointId" },
            @{ Name = "journey_patterns"; IdField = "JourneyPatternId" },
            @{ Name = "stop_sequences"; IdField = "StopSequenceId" },
            @{ Name = "service_journeys"; IdField = "ServiceJourneyId" },
            @{ Name = "passing_times"; IdField = "PassingTimeId" },
            @{ Name = "dated_journeys"; IdField = "DatedServiceJourneyId" }
        )
        
        foreach ($entityType in $entityTypes) {
            Write-Log ("Processing {0} for route {1}" -f $entityType.Name, $routeNumber)
            
            # Get current data if it exists
            $currentPath = Join-Path $routePaths.Current "$($entityType.Name).json"
            $currentData = if (Test-Path $currentPath) { 
                Get-Content $currentPath -Raw | ConvertFrom-Json
            }
            
            # Process new data
            $newData = & "Get-$($entityType.Name)" $xml $nsManager
            
            # Detect changes
            $changes = Get-EntityChanges -CurrentData $currentData -NewData $newData -IdField $entityType.IdField
            
            Write-Log ("$($entityType.Name) changes for route {0}: Added={1}, Modified={2}, Deleted={3}" -f 
                $routeNumber, $changes.Added.Count, $changes.Modified.Count, $changes.Deleted.Count)
            
            if ($changes.Added.Count -gt 0 -or $changes.Modified.Count -gt 0 -or $changes.Deleted.Count -gt 0) {
                # Save delta files if there are changes
                if ($changes.Added.Count -gt 0) {
                    $changes.Added | ConvertTo-Json -Depth 10 | 
                        Set-Content (Join-Path $routePaths.Delta "$($entityType.Name)_added.json") -Encoding UTF8
                }
                if ($changes.Modified.Count -gt 0) {
                    $changes.Modified | ConvertTo-Json -Depth 10 | 
                        Set-Content (Join-Path $routePaths.Delta "$($entityType.Name)_modified.json") -Encoding UTF8
                }
                if ($changes.Deleted.Count -gt 0) {
                    $changes.Deleted | ConvertTo-Json -Depth 10 | 
                        Set-Content (Join-Path $routePaths.Delta "$($entityType.Name)_deleted.json") -Encoding UTF8
                }
                
                if (-not $GenerateDeltaOnly) {
                    # Archive current version
                    if (Test-Path $currentPath) {
                        Copy-Item $currentPath (Join-Path $routePaths.Archive "$($entityType.Name).json")
                    }
                    
                    # Update current version
                    $newData | ConvertTo-Json -Depth 10 | 
                        Set-Content $currentPath -Encoding UTF8
                }
            }
        }
        
        Write-Log "Completed processing route $routeNumber"
    }
    catch {
        Write-Log "ERROR processing $($xmlFile.Name): $($_.Exception.Message)"
        Write-Log $_.ScriptStackTrace
        # Continue with next file rather than stopping
        continue
    }
}

Write-Log "Processing completed"
