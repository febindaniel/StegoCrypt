$ErrorActionPreference = "Stop"

Write-Host "Building Distribution Package..." -ForegroundColor Cyan

# Define Directories
$releaseDir = "Imgenc_Release"

# 1. Clean previous release
if (Test-Path $releaseDir) { 
    Write-Host "Cleaning previous release..." -ForegroundColor Gray
    Remove-Item $releaseDir -Recurse -Force 
}
New-Item -ItemType Directory -Path $releaseDir | Out-Null

# 2. Build Backend
Write-Host "Building Backend EXE..." -ForegroundColor Yellow
# PyInstaller outputs to ./dist by default
pyinstaller --onefile --noconsole --clean --name imgenc_backend backend/app.py

# 3. Build Frontend
Write-Host "Building Frontend (Windows)..." -ForegroundColor Yellow
Push-Location frontend
flutter build windows --release
Pop-Location

# 4. Assemble
Write-Host "Assembling..." -ForegroundColor Yellow

# Copy Frontend Files
# The flutter build output contains the exe and all necessary dlls/data inside 'runner/Release'
Copy-Item -Path "frontend/build/windows/x64/runner/Release/*" -Destination $releaseDir -Recurse

# Copy Backend EXE
# PyInstaller put it in dist/
if (Test-Path "dist/imgenc_backend.exe") {
    Copy-Item -Path "dist/imgenc_backend.exe" -Destination "$releaseDir/imgenc_backend.exe"
}
else {
    Write-Error "Backend EXE not found in dist/! PyInstaller might have failed."
}

# Create Launcher Bat
$batContent = @"
@echo off
start "" /B "imgenc_backend.exe"
start "" "imgenc_frontend.exe"
"@
Set-Content -Path "$releaseDir/Run App.bat" -Value $batContent

Write-Host "`n========================================================" -ForegroundColor Green
Write-Host "Build Complete!" -ForegroundColor Green
Write-Host "Find your app info the folder: $releaseDir" -ForegroundColor Cyan
Write-Host "You can zip '$releaseDir' and share it." -ForegroundColor Cyan
Write-Host "========================================================" -ForegroundColor Green
