# ============================================================
# SCRIPT: Create desktop shortcuts for MFAAvalonia.exe
# PURPOSE: Create desktop shortcuts to MFAAvalonia.exe in MaaTKFM folders
#
# TARGET DIRECTORIES:
#   - C:\Users\Aurora\Desktop\MaaTKFM201
#   - C:\Users\Aurora\Desktop\MaaTKFM202
#   - C:\Users\Aurora\Desktop\MaaTKFM203
#   - C:\Users\Aurora\Desktop\MaaTKFM204
#
# SHORTCUTS CREATED:
#   C:\Users\Aurora\Desktop\MaaTKFM201.lnk -> MaaTKFM201\MFAAvalonia.exe
#   C:\Users\Aurora\Desktop\MaaTKFM202.lnk -> MaaTKFM202\MFAAvalonia.exe
#   C:\Users\Aurora\Desktop\MaaTKFM203.lnk -> MaaTKFM203\MFAAvalonia.exe
#   C:\Users\Aurora\Desktop\MaaTKFM204.lnk -> MaaTKFM204\MFAAvalonia.exe
# ============================================================

# Target base directories
$targetBases = @(
    "C:\Users\Aurora\Desktop\MaaTKFM201",
    "C:\Users\Aurora\Desktop\MaaTKFM202",
    "C:\Users\Aurora\Desktop\MaaTKFM203",
    "C:\Users\Aurora\Desktop\MaaTKFM204"
)

# Desktop path for shortcuts
$desktopPath = "C:\Users\Aurora\Desktop"

Write-Host "========================================" -ForegroundColor Magenta
Write-Host "Starting shortcut creation..." -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Magenta
Write-Host ""

foreach ($base in $targetBases) {
    # Extract folder name (e.g., "MaaTKFM201")
    $folderName = Split-Path -Leaf $base
    
    Write-Host "Processing: $folderName" -ForegroundColor Yellow
    
    # Check if target directory exists
    if (-not (Test-Path $base)) {
        Write-Host "  Warning: Directory not found: $base" -ForegroundColor Red
        Write-Host ""
        continue
    }
    
    # Executable path
    $exePath = "$base\MFAAvalonia.exe"
    $shortcutPath = "$desktopPath\$folderName.lnk"
    
    # Check if executable exists
    if (-not (Test-Path $exePath)) {
        Write-Host "  Warning: MFAAvalonia.exe not found at $exePath" -ForegroundColor Red
        Write-Host ""
        continue
    }
    
    # Check if shortcut already exists
    if (Test-Path $shortcutPath) {
        Write-Host "  Shortcut already exists: $shortcutPath" -ForegroundColor Gray
        Write-Host "  Skipping..." -ForegroundColor Gray
        Write-Host ""
        continue
    }
    
    # Create desktop shortcut
    Write-Host "  Creating desktop shortcut..." -ForegroundColor Cyan
    
    try {
        $WScriptShell = New-Object -ComObject WScript.Shell
        $shortcut = $WScriptShell.CreateShortcut($shortcutPath)
        $shortcut.TargetPath = $exePath
        $shortcut.WorkingDirectory = $base
        $shortcut.Description = "Shortcut to MFAAvalonia.exe in $folderName"
        $shortcut.Save()
        Write-Host "  Shortcut created: $shortcutPath" -ForegroundColor Green
    } catch {
        Write-Host "  Warning: Failed to create shortcut: $_" -ForegroundColor Red
    }
    
    Write-Host ""
}

Write-Host "========================================" -ForegroundColor Magenta
Write-Host "All operations completed!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Magenta