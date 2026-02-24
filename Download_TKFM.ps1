# MAATKFM2 Batch Download and Extract Script
# Configuration Section
# ============================================

$REPO_API_URL = "https://api.github.com/repos/21dczhang/MAATKFM2/releases/latest"
$REPO_RELEASES_URL = "https://github.com/21dczhang/MAATKFM2/releases/latest"
$DEFAULT_VERSION = "v0.1.8"  # Fallback version

Write-Host "[*] Checking for latest release on GitHub..." -ForegroundColor Yellow

$VERSION = $null

# 方法1: 尝试通过 API 获取
try {
    $latestRelease = Invoke-RestMethod -Uri $REPO_API_URL -ErrorAction Stop
    $VERSION = $latestRelease.tag_name
    Write-Host "Latest version found via API: $VERSION" -ForegroundColor Green
} catch {
    # 方法2: 尝试通过网页重定向获取版本号
    Write-Host "API failed, trying alternative method..." -ForegroundColor Yellow
    try {
        $response = Invoke-WebRequest -Uri $REPO_RELEASES_URL -MaximumRedirection 0 -ErrorAction SilentlyContinue
    } catch {
        # 捕获重定向
        if ($_.Exception.Response.Headers.Location) {
            $redirectUrl = $_.Exception.Response.Headers.Location.AbsoluteUri
            if ($redirectUrl -match '/releases/tag/([^/]+)$') {
                $VERSION = $matches[1]
                Write-Host "Latest version found via redirect: $VERSION" -ForegroundColor Green
            }
        }
    }
}

# 如果都失败，使用默认版本
if (-not $VERSION) {
    Write-Host "Could not detect latest version. Using default: $DEFAULT_VERSION" -ForegroundColor Yellow
    $VERSION = $DEFAULT_VERSION
}

# ============================================
# Construct download URL
# ============================================

$DESKTOP_PATH = "C:\Users\Aurora\Desktop"
$TEMP_DOWNLOAD = "$env:TEMP\MaaTKFM2-temp.zip"
$FOLDER_COUNT = 5

# 使用具体版本号构建下载 URL
$DOWNLOAD_URL = "https://github.com/21dczhang/MAATKFM2/releases/download/$VERSION/MaaTKFM2-win-x86_64-$VERSION.zip"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "MAATKFM2 Batch Download and Extract Tool" -ForegroundColor Cyan
Write-Host "Target Version: $VERSION" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check if target path exists
if (-not (Test-Path $DESKTOP_PATH)) {
    Write-Host "Error: Target path does not exist: $DESKTOP_PATH" -ForegroundColor Red
    exit 1
}

# Download file
Write-Host "[1/3] Downloading MaaTKFM2-win-x86_64-$VERSION.zip ..." -ForegroundColor Yellow
Write-Host "  URL: $DOWNLOAD_URL" -ForegroundColor Gray

$downloadSuccess = $false
$ProgressPreference = 'SilentlyContinue'

try {
    (New-Object System.Net.WebClient).DownloadFile($DOWNLOAD_URL, $TEMP_DOWNLOAD)
    Write-Host "Download completed." -ForegroundColor Green
    $downloadSuccess = $true
} catch {
    Write-Host "Download failed: $_" -ForegroundColor Red
    
    # 如果不是默认版本，尝试使用默认版本
    if ($VERSION -ne $DEFAULT_VERSION) {
        Write-Host "Retrying with default version: $DEFAULT_VERSION ..." -ForegroundColor Yellow
        $DOWNLOAD_URL = "https://github.com/21dczhang/MAATKFM2/releases/download/$DEFAULT_VERSION/MaaTKFM2-win-x86_64-$DEFAULT_VERSION.zip"
        
        try {
            (New-Object System.Net.WebClient).DownloadFile($DOWNLOAD_URL, $TEMP_DOWNLOAD)
            Write-Host "Download completed using default version." -ForegroundColor Green
            $downloadSuccess = $true
        } catch {
            Write-Host "Retry also failed: $_" -ForegroundColor Red
        }
    }
}

if (-not $downloadSuccess) {
    Write-Host "Unable to download file. Please check your network connection or GitHub access." -ForegroundColor Red
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