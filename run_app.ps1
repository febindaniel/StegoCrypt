$ErrorActionPreference = "Stop"

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "   Steganography App Launcher" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

# 0. Check Dependencies
Write-Host "`n[0/2] Checking Python Dependencies..." -ForegroundColor Yellow
try {
    pip install -r .\backend\requirements.txt
}
catch {
    Write-Host "Warning: Could not check/install dependencies. Backend might fail." -ForegroundColor Red
}

# 1. Start Backend
Write-Host "`n[1/2] Starting Python Backend..." -ForegroundColor Yellow
$backendProcess = Start-Process python -ArgumentList "app.py" -WorkingDirectory ".\backend" -PassThru
Write-Host "Backend started (PID: $($backendProcess.Id))." -ForegroundColor Green

# 2. Start Frontend
Write-Host "`n[2/2] Starting Flutter Frontend..." -ForegroundColor Yellow
Write-Host "Please wait for the app to build and launch..." -ForegroundColor Gray

Push-Location ".\frontend"
try {
    flutter run -d windows
}
finally {
    Pop-Location
    # Optional: Kill backend when frontend closes
    # Stop-Process -Id $backendProcess.Id -ErrorAction SilentlyContinue
    Write-Host "`nApp closed." -ForegroundColor Gray
}
