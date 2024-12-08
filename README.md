# RouteParser

PowerShell scripts for processing route XML files and tracking changes over time. This tool is designed to process multiple XML files containing route information, detect changes between runs, and generate delta files for efficient data updates.

## Features

- Process multiple XML files in a batch
- Track changes between runs
- Generate delta files (added/modified/deleted entities)
- Maintain historical versions
- Detailed logging
- Organize data by route number

## Folder Structure

```
/RouteData
    /current               # Current version of all routes
        /8411             
            lines.json
            routes.json
            ...etc
        /8412
            lines.json
            routes.json
            ...etc
            
    /archive              # Historical versions
        /20231207_120000
            /8411
            /8412
            
    /delta               # Only changed data
        /20231207_120000
            /8411
                added.json
                modified.json
                deleted.json
            /8412
                added.json
                modified.json
                deleted.json
                
    /logs                # Processing logs
```

## Usage

1. Basic usage:
```powershell
.\Process-Routes.ps1 -XmlFolderPath "C:\Routes\XML" -OutputPath "D:\RouteData"
```

2. Generate only delta files without updating current version:
```powershell
.\Process-Routes.ps1 -XmlFolderPath "C:\Routes\XML" -OutputPath "D:\RouteData" -GenerateDeltaOnly
```

## Files

- `Process-Routes.ps1`: Main processing script
- `XmlProcessor.psm1`: XML processing module with entity extraction functions

## Requirements

- PowerShell 5.1 or later
- Write permissions to output directory

## Entity Types Processed

1. Lines
2. Routes
3. Route Points
4. Journey Patterns
5. Stop Sequences
6. Service Journeys
7. Passing Times
8. Dated Journeys

## Output Files

For each route number and entity type, the following files may be generated:

### Current Data
- `{entityType}.json`: Current version of the data

### Delta Files (when changes are detected)
- `{entityType}_added.json`: New entities
- `{entityType}_modified.json`: Changed entities
- `{entityType}_deleted.json`: Removed entities

## Logs

Processing logs are stored in the logs directory with timestamp:
- `process_YYYYMMDD_HHMMSS.log`