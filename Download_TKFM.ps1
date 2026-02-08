# MAATKFM2 Batch Download and Extract Script
# Configuration Section - You can modify the version number
$VERSION = "v0.1.0"

# ============================================
# Do not modify the following unless necessary
# ============================================

# Download URL
$DOWNLOAD_URL = "https://github.com/21dczhang/MAATKFM2/releases/download/$VERSION/MaaTKFM2-win-x86_64-$VERSION.zip"

# Target base path
$DESKTOP_PATH = "C:\Users\Aurora\Desktop"
$TEMP_DOWNLOAD = "$env:TEMP\MaaTKFM2-temp.zip"

# Number of folders to create
$FOLDER_COUNT = 4

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "MAATKFM2 Batch Download and Extract Tool" -ForegroundColor Cyan
Write-Host "Version: $VERSION" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check if target path exists
if (-not (Test-Path $DESKTOP_PATH)) {
    Write-Host "Error: Target path does not exist: $DESKTOP_PATH" -ForegroundColor Red
    exit 1
}

# Download file
Write-Host "[1/3] Downloading MaaTKFM2-win-x86_64-$VERSION.zip ..." -ForegroundColor Yellow
try {
    $webClient = New-Object System.Net.WebClient
    $webClient.DownloadFile($DOWNLOAD_URL, $TEMP_DOWNLOAD)
    Write-Host "Download completed." -ForegroundColor Green
} catch {
    Write-Host "Download failed: $_" -ForegroundColor Red
    exit 1
}

# Extract to multiple folders
Write-Host ""
Write-Host "[2/3] Extracting to $FOLDER_COUNT folders..." -ForegroundColor Yellow

for ($i = 1; $i -le $FOLDER_COUNT; $i++) {
    $folderName = "MaaTKFM20$i"
    $targetPath = Join-Path $DESKTOP_PATH $folderName
    
    Write-Host "  Processing: $folderName ..." -ForegroundColor Gray
    
    # Remove existing folder if present
    if (Test-Path $targetPath) {
        Write-Host "    Folder exists. Removing..." -ForegroundColor Yellow
        Remove-Item -Path $targetPath -Recurse -Force
    }
    
    # Create target directory
    New-Item -ItemType Directory -Path $targetPath -Force | Out-Null
    
    # Extract archive
    try {
        Expand-Archive -Path $TEMP_DOWNLOAD -DestinationPath $targetPath -Force
        Write-Host "  Extraction completed for $folderName." -ForegroundColor Green
    } catch {
        Write-Host "  Extraction failed for ${folderName}: $_" -ForegroundColor Red
    }
}

# Clean up temporary file
Write-Host ""
Write-Host "[3/3] Cleaning up temporary file..." -ForegroundColor Yellow
if (Test-Path $TEMP_DOWNLOAD) {
    Remove-Item -Path $TEMP_DOWNLOAD -Force
    Write-Host "Temporary file removed." -ForegroundColor Green
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "All operations completed." -ForegroundColor Green
Write-Host "Extract location: $DESKTOP_PATH" -ForegroundColor Cyan
Write-Host "Created folders:" -ForegroundColor Cyan
for ($i = 1; $i -le $FOLDER_COUNT; $i++) {
    Write-Host "  - MaaTKFM20$i" -ForegroundColor White
}
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Press any key to exit..."
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")