# ============================================================
# SCRIPT: Copy assets/resource and assets/interface.json to multiple targets
# PURPOSE: Deploy resource folder and interface.json file to 4 target directories
#
# SOURCE STRUCTURE (relative to script root):
#   C:\Users\Aurora\Desktop\c_cpp_project\MAATKFM2\
#   ├── assets\
#   │   ├── resource\          <-- entire contents copied to target\resource\
#   │   └── interface.json     <-- single file copied to target\interface.json
#
# TARGET STRUCTURE (for each of MaaTKFM201 ~ MaaTKFM204):
#   C:\Users\Aurora\Desktop\MaaTKFM201\
#   ├── resource\              <-- receives all files/folders from assets\resource
#   ├── interface.json         <-- copy of assets\interface.json
#   └── MFAAvalonia.exe        <-- executable to run after copying
#
# SHORTCUTS CREATED:
#   C:\Users\Aurora\Desktop\tfkm201.lnk -> MaaTKFM201\MFAAvalonia.exe
#   C:\Users\Aurora\Desktop\tfkm202.lnk -> MaaTKFM202\MFAAvalonia.exe
#   C:\Users\Aurora\Desktop\tfkm203.lnk -> MaaTKFM203\MFAAvalonia.exe
#   C:\Users\Aurora\Desktop\tfkm204.lnk -> MaaTKFM204\MFAAvalonia.exe
#
# TARGET DIRECTORIES:
#   - C:\Users\Aurora\Desktop\MaaTKFM201
#   - C:\Users\Aurora\Desktop\MaaTKFM202
#   - C:\Users\Aurora\Desktop\MaaTKFM203
#   - C:\Users\Aurora\Desktop\MaaTKFM204
#
# PROCESS FOR interface.json:
#   1. Delete existing interface.json if present
#   2. Run MFAAvalonia.exe
#   3. Kill MFAAvalonia.exe process
#   4. Kill MuMu emulator process (MuMuNxDevice.exe)
#   5. Copy new interface.json
#   6. Create desktop shortcut
#
# NOTE: This script uses only ASCII English text for compatibility.
# ============================================================

$scriptRoot = "C:\Users\Aurora\Desktop\c_cpp_project\MAATKFM2"

# Source paths
$sourceResourcePath = "$scriptRoot\assets\resource"
$sourceInterfaceFile = "$scriptRoot\assets\interface.json"

# Target base directories
$targetBases = @(
    "C:\Users\Aurora\Desktop\MaaTKFM201",
    "C:\Users\Aurora\Desktop\MaaTKFM202",
    "C:\Users\Aurora\Desktop\MaaTKFM203",
    "C:\Users\Aurora\Desktop\MaaTKFM204"
)

# Desktop path for shortcuts
$desktopPath = "C:\Users\Aurora\Desktop"

# MuMu emulator process name
$mumuProcessName = "MuMuNxDevice"

# Validate source paths
if (-not (Test-Path $sourceResourcePath)) {
    Write-Host "Error: Source resource path not found: $sourceResourcePath" -ForegroundColor Red
    exit 1
}

if (-not (Test-Path $sourceInterfaceFile)) {
    Write-Host "Error: Interface file not found: $sourceInterfaceFile" -ForegroundColor Red
    exit 1
}

Write-Host "Starting copy operations..." -ForegroundColor Green
Write-Host "Source resource: $sourceResourcePath" -ForegroundColor Cyan
Write-Host "Source interface.json: $sourceInterfaceFile" -ForegroundColor Cyan

foreach ($base in $targetBases) {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Magenta
    Write-Host "Processing target: $base" -ForegroundColor Yellow
    Write-Host "========================================" -ForegroundColor Magenta

    # Extract folder number (e.g., "201" from "MaaTKFM201")
    $folderName = Split-Path -Leaf $base
    if ($folderName -match '(\d+)$') {
        $number = $matches[1]
        $shortcutName = "tfkm$number"
    } else {
        Write-Host "  Warning: Cannot extract number from folder name, using default shortcut name." -ForegroundColor Yellow
        $shortcutName = "tfkm_shortcut"
    }

    # Ensure target base directory exists
    if (-not (Test-Path $base)) {
        Write-Host "  Creating directory: $base" -ForegroundColor Gray
        New-Item -Path $base -ItemType Directory -Force | Out-Null
    }

    # Copy resource folder contents to $base\resource
    Write-Host "  [1/7] Copying resource folder..." -ForegroundColor Cyan
    $destResource = "$base\resource"
    if (-not (Test-Path $destResource)) {
        New-Item -Path $destResource -ItemType Directory -Force | Out-Null
    }
    Copy-Item -Path "$sourceResourcePath\*" -Destination $destResource -Recurse -Force
    Write-Host "      Resource copied successfully." -ForegroundColor Green

    # Delete existing interface.json if present
    Write-Host "  [2/7] Checking for existing interface.json..." -ForegroundColor Cyan
    $targetInterfaceFile = "$base\interface.json"
    if (Test-Path $targetInterfaceFile) {
        Remove-Item -Path $targetInterfaceFile -Force
        Write-Host "      Deleted existing interface.json." -ForegroundColor Yellow
    } else {
        Write-Host "      No existing interface.json found." -ForegroundColor Gray
    }

    # Run MFAAvalonia.exe
    Write-Host "  [3/7] Starting MFAAvalonia.exe..." -ForegroundColor Cyan
    $exePath = "$base\MFAAvalonia.exe"
    if (Test-Path $exePath) {
        try {
            Start-Process -FilePath $exePath -WorkingDirectory $base
            Write-Host "      MFAAvalonia.exe started, waiting 5 seconds..." -ForegroundColor Green
            Start-Sleep -Seconds 5
        } catch {
            Write-Host "      Warning: Failed to start MFAAvalonia.exe: $_" -ForegroundColor Red
        }
    } else {
        Write-Host "      Warning: MFAAvalonia.exe not found at $exePath" -ForegroundColor Red
    }

    # Kill MFAAvalonia.exe process
    Write-Host "  [4/7] Terminating MFAAvalonia.exe..." -ForegroundColor Cyan
    try {
        $mfaProcesses = Get-Process -Name "MFAAvalonia" -ErrorAction SilentlyContinue
        if ($mfaProcesses) {
            $mfaProcesses | Stop-Process -Force
            Write-Host "      MFAAvalonia.exe terminated (killed $($mfaProcesses.Count) process(es))." -ForegroundColor Yellow
        } else {
            Write-Host "      No MFAAvalonia.exe process found." -ForegroundColor Gray
        }
    } catch {
        Write-Host "      Warning: Error terminating MFAAvalonia.exe: $_" -ForegroundColor Red
    }

    # Kill MuMu emulator process
    Write-Host "  [5/7] Terminating MuMu emulator (MuMuNxDevice.exe)..." -ForegroundColor Cyan
    try {
        $mumuProcesses = Get-Process -Name $mumuProcessName -ErrorAction SilentlyContinue
        if ($mumuProcesses) {
            $mumuProcesses | Stop-Process -Force
            Write-Host "      MuMuNxDevice.exe terminated (killed $($mumuProcesses.Count) process(es))." -ForegroundColor Yellow
        } else {
            Write-Host "      No MuMuNxDevice.exe process found." -ForegroundColor Gray
        }
    } catch {
        Write-Host "      Warning: Error terminating MuMuNxDevice.exe: $_" -ForegroundColor Red
    }

    # Copy new interface.json
    Write-Host "  [6/7] Copying new interface.json..." -ForegroundColor Cyan
    Copy-Item -Path $sourceInterfaceFile -Destination $targetInterfaceFile -Force
    Write-Host "      interface.json copied successfully." -ForegroundColor Green

    # Create desktop shortcut
    Write-Host "  [7/7] Creating desktop shortcut ($shortcutName.lnk)..." -ForegroundColor Cyan
    if (Test-Path $exePath) {
        try {
            $shortcutPath = "$desktopPath\$shortcutName.lnk"
            $WScriptShell = New-Object -ComObject WScript.Shell
            $shortcut = $WScriptShell.CreateShortcut($shortcutPath)
            $shortcut.TargetPath = $exePath
            $shortcut.WorkingDirectory = $base
            $shortcut.Description = "Shortcut to MFAAvalonia.exe in $folderName"
            $shortcut.Save()
            Write-Host "      Shortcut created: $shortcutPath" -ForegroundColor Green
        } catch {
            Write-Host "      Warning: Failed to create shortcut: $_" -ForegroundColor Red
        }
    } else {
        Write-Host "      Warning: Cannot create shortcut - MFAAvalonia.exe not found." -ForegroundColor Red
    }

    Write-Host ""
    Write-Host "  Target $base completed!" -ForegroundColor Green
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Magenta
Write-Host "All operations completed successfully!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Magenta