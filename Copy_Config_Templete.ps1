# JSON Configuration Sync Script
# Syncs configuration files from Template to multiple target folders
# ============================================

$DESKTOP_PATH = "C:\Users\Aurora\Desktop"
$TEMPLATE_FOLDER = Join-Path $DESKTOP_PATH "MaaTKFM_Templete"
$TARGET_FOLDERS = @("MaaTKFM201", "MaaTKFM202", "MaaTKFM203", "MaaTKFM204", "MaaTKFM205")

# Special field mapping: folder name -> version offset
$FOLDER_VERSION_MAP = @{
    "MaaTKFM201" = 2
    "MaaTKFM202" = 3
    "MaaTKFM203" = 4
    "MaaTKFM204" = 5
    "MaaTKFM205" = 6
}

# Special fields configuration (these are literal property names, not paths)
$SPECIAL_EMULATOR_FIELD = "Instance.default.EmulatorConfig"
$SPECIAL_SUCCESS_FIELD = "ExternalNotificationCustomSuccessText"
$SPECIAL_FAILURE_FIELD = "ExternalNotificationCustomFailureText"
$TASKITEMS_FIELD = "Instance.default.TaskItems"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "JSON Configuration Sync Tool" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Function to extract folder number (e.g., "MaaTKFM201" -> "201")
function Get-FolderNumber {
    param (
        [string]$FolderName
    )
    
    if ($FolderName -match 'MaaTKFM(\d+)$') {
        return $matches[1]
    }
    return $null
}

# Function to sync index values in option arrays
function Sync-OptionIndexes {
    param (
        [array]$TemplateOptions,
        [array]$TargetOptions
    )
    
    if ($null -eq $TemplateOptions -or $null -eq $TargetOptions) {
        return
    }
    
    for ($i = 0; $i -lt $TemplateOptions.Count; $i++) {
        if ($i -lt $TargetOptions.Count) {
            $templateOpt = $TemplateOptions[$i]
            $targetOpt = $TargetOptions[$i]
            
            # Sync index if names match
            if ($templateOpt.name -eq $targetOpt.name) {
                if ($templateOpt.index -ne $targetOpt.index) {
                    $oldIndex = $targetOpt.index
                    $targetOpt.index = $templateOpt.index
                    Write-Host "      [INDEX] '$($targetOpt.name)': $oldIndex → $($templateOpt.index)" -ForegroundColor Cyan
                }
                
                # Recursively handle sub_options if they exist
                if ($null -ne $templateOpt.sub_options -and $null -ne $targetOpt.sub_options) {
                    Sync-OptionIndexes -TemplateOptions $templateOpt.sub_options -TargetOptions $targetOpt.sub_options
                }
            }
        }
    }
}

# Function to sync TaskItems indexes from template to target
function Sync-TaskItemsIndexes {
    param (
        [array]$TemplateTaskItems,
        [array]$TargetTaskItems
    )
    
    if ($null -eq $TemplateTaskItems -or $null -eq $TargetTaskItems) {
        return
    }
    
    $syncCount = 0
    
    foreach ($templateTask in $TemplateTaskItems) {
        # Find matching task in target by name and entry
        $matchingTask = $TargetTaskItems | Where-Object {
            $_.name -eq $templateTask.name -and $_.entry -eq $templateTask.entry
        }
        
        if ($null -ne $matchingTask) {
            # Check if task has options array
            if ($null -ne $templateTask.option -and $null -ne $matchingTask.option) {
                Write-Host "    [TASK] Syncing indexes for: $($templateTask.name)" -ForegroundColor Yellow
                
                # Sync option indexes
                Sync-OptionIndexes -TemplateOptions $templateTask.option -TargetOptions $matchingTask.option
                
                $syncCount++
            }
        }
    }
    
    if ($syncCount -gt 0) {
        Write-Host "    [TASKITEMS] Synced $syncCount task(s) with option indexes" -ForegroundColor Green
    }
}

# Function to recursively merge JSON objects
# Template values override target values, but target-only keys are preserved
function Merge-JsonObjects {
    param (
        [PSCustomObject]$Template,
        [PSCustomObject]$Target
    )
    
    # Convert to hashtables for easier manipulation
    $result = @{}
    
    # First, copy all properties from target (preserve target-only fields)
    if ($null -ne $Target) {
        $Target.PSObject.Properties | ForEach-Object {
            $result[$_.Name] = $_.Value
        }
    }
    
    # Then, override with template properties
    if ($null -ne $Template) {
        $Template.PSObject.Properties | ForEach-Object {
            $key = $_.Name
            $templateValue = $_.Value
            
            # If both are objects (not arrays), merge recursively
            if ($templateValue -is [PSCustomObject] -and $result.ContainsKey($key) -and $result[$key] -is [PSCustomObject]) {
                $result[$key] = Merge-JsonObjects -Template $templateValue -Target $result[$key]
            }
            # Otherwise, template value takes precedence
            else {
                $result[$key] = $templateValue
            }
        }
    }
    
    # Convert back to PSCustomObject
    return [PSCustomObject]$result
}

# Function to process special field transformations
function Transform-SpecialFields {
    param (
        [PSCustomObject]$JsonObject,
        [PSCustomObject]$TemplateObject,
        [string]$FolderName
    )
    
    $folderNumber = Get-FolderNumber -FolderName $FolderName
    
    if ($null -eq $folderNumber) {
        Write-Host "    [WARNING] Could not extract folder number from: $FolderName" -ForegroundColor Yellow
        return
    }
    
    # Get all property names
    $propertyNames = $JsonObject.PSObject.Properties.Name
    
    # 1. Handle EmulatorConfig field (literal property name with dots)
    if ($propertyNames -contains $SPECIAL_EMULATOR_FIELD) {
        $emulatorValue = $JsonObject.$SPECIAL_EMULATOR_FIELD
        
        if ($null -ne $emulatorValue -and $emulatorValue -match '^-v\s+\d+$') {
            if ($FOLDER_VERSION_MAP.ContainsKey($FolderName)) {
                $newVersion = $FOLDER_VERSION_MAP[$FolderName]
                $newValue = "-v $newVersion"
                
                $JsonObject.$SPECIAL_EMULATOR_FIELD = $newValue
                Write-Host "    [SPECIAL] Updated '$SPECIAL_EMULATOR_FIELD': '$emulatorValue' → '$newValue'" -ForegroundColor Magenta
            }
        }
    }
    
    # 2. Handle Success Text field
    if ($propertyNames -contains $SPECIAL_SUCCESS_FIELD) {
        $successValue = $JsonObject.$SPECIAL_SUCCESS_FIELD
        
        if ($null -ne $successValue -and $successValue -match 'TKFM\d+') {
            $newValue = $successValue -replace 'TKFM\d+', "TKFM$folderNumber"
            
            $JsonObject.$SPECIAL_SUCCESS_FIELD = $newValue
            Write-Host "    [SPECIAL] Updated '$SPECIAL_SUCCESS_FIELD': '$successValue' → '$newValue'" -ForegroundColor Magenta
        }
    }
    
    # 3. Handle Failure Text field
    if ($propertyNames -contains $SPECIAL_FAILURE_FIELD) {
        $failureValue = $JsonObject.$SPECIAL_FAILURE_FIELD
        
        if ($null -ne $failureValue -and $failureValue -match 'TKFM\d+') {
            $newValue = $failureValue -replace 'TKFM\d+', "TKFM$folderNumber"
            
            $JsonObject.$SPECIAL_FAILURE_FIELD = $newValue
            Write-Host "    [SPECIAL] Updated '$SPECIAL_FAILURE_FIELD': '$failureValue' → '$newValue'" -ForegroundColor Magenta
        }
    }
    
    # 4. Handle TaskItems index synchronization
    if ($propertyNames -contains $TASKITEMS_FIELD) {
        $templatePropertyNames = $TemplateObject.PSObject.Properties.Name
        
        if ($templatePropertyNames -contains $TASKITEMS_FIELD) {
            $targetTaskItems = $JsonObject.$TASKITEMS_FIELD
            $templateTaskItems = $TemplateObject.$TASKITEMS_FIELD
            
            if ($null -ne $targetTaskItems -and $null -ne $templateTaskItems) {
                Sync-TaskItemsIndexes -TemplateTaskItems $templateTaskItems -TargetTaskItems $targetTaskItems
            }
        }
    }
}

# Function to process a single JSON file
function Sync-JsonFile {
    param (
        [string]$TemplateFile,
        [string]$TargetFile,
        [string]$FolderName
    )
    
    try {
        # Read template JSON
        $templateContent = Get-Content -Path $TemplateFile -Raw -Encoding UTF8 | ConvertFrom-Json
        
        # Check if target file exists
        if (Test-Path $TargetFile) {
            # Read target JSON
            $targetContent = Get-Content -Path $TargetFile -Raw -Encoding UTF8 | ConvertFrom-Json
            
            # Merge: template fields override, target-only fields preserved
            $mergedContent = Merge-JsonObjects -Template $templateContent -Target $targetContent
        }
        else {
            # Target doesn't exist, use template as-is
            Write-Host "    [NEW] Creating new file" -ForegroundColor Yellow
            $mergedContent = $templateContent
            
            # Ensure directory exists
            $targetDir = Split-Path -Parent $TargetFile
            if (-not (Test-Path $targetDir)) {
                New-Item -ItemType Directory -Path $targetDir -Force | Out-Null
            }
        }
        
        # Apply special field transformations AFTER merging
        Transform-SpecialFields -JsonObject $mergedContent -TemplateObject $templateContent -FolderName $FolderName
        
        # Write back to target (preserve UTF-8 encoding, format nicely)
        $jsonString = $mergedContent | ConvertTo-Json -Depth 100
        
        # Ensure UTF-8 without BOM
        [System.IO.File]::WriteAllText($TargetFile, $jsonString, (New-Object System.Text.UTF8Encoding $false))
        
        return $true
    }
    catch {
        Write-Host "    [ERROR] $_" -ForegroundColor Red
        return $false
    }
}

# Validate template folder exists
if (-not (Test-Path $TEMPLATE_FOLDER)) {
    Write-Host "Error: Template folder not found: $TEMPLATE_FOLDER" -ForegroundColor Red
    exit 1
}

# Find all JSON files in template folder
Write-Host "[*] Scanning template folder for JSON files..." -ForegroundColor Yellow
$templateJsonFiles = Get-ChildItem -Path $TEMPLATE_FOLDER -Filter "*.json" -Recurse

if ($templateJsonFiles.Count -eq 0) {
    Write-Host "Warning: No JSON files found in template folder." -ForegroundColor Yellow
    exit 0
}

Write-Host "Found $($templateJsonFiles.Count) JSON file(s) in template." -ForegroundColor Green
Write-Host ""

# Process each target folder
$totalProcessed = 0
$totalSuccess = 0
$totalFailed = 0

foreach ($targetFolderName in $TARGET_FOLDERS) {
    $targetFolderPath = Join-Path $DESKTOP_PATH $targetFolderName
    
    Write-Host "========================================" -ForegroundColor Cyan
    Write-Host "Processing: $targetFolderName" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan
    
    if (-not (Test-Path $targetFolderPath)) {
        Write-Host "  [SKIP] Folder does not exist: $targetFolderPath" -ForegroundColor Yellow
        Write-Host ""
        continue
    }
    
    # Process each JSON file from template
    foreach ($templateFile in $templateJsonFiles) {
        # Calculate relative path from template folder
        $relativePath = $templateFile.FullName.Substring($TEMPLATE_FOLDER.Length + 1)
        
        # Construct target file path
        $targetFile = Join-Path $targetFolderPath $relativePath
        
        Write-Host "  Processing: $relativePath" -ForegroundColor Gray
        
        $totalProcessed++
        if (Sync-JsonFile -TemplateFile $templateFile.FullName -TargetFile $targetFile -FolderName $targetFolderName) {
            $totalSuccess++
            Write-Host "    [OK] Synced successfully" -ForegroundColor Green
        }
        else {
            $totalFailed++
        }
    }
    
    Write-Host ""
}

# Summary
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Sync Summary" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Total files processed: $totalProcessed" -ForegroundColor White
Write-Host "Successful: $totalSuccess" -ForegroundColor Green
Write-Host "Failed: $totalFailed" -ForegroundColor $(if ($totalFailed -gt 0) { "Red" } else { "Green" })
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Press any key to exit..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")