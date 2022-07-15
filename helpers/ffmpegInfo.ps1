#reset errorlevel
$LASTEXITCODE = 0

# Testing if ffmpeg in path
Write-Host "Running ComfyChecker:" -ForegroundColor Yellow
Invoke-Expression .\helpers\ComfyChecker.ps1
$LASTEXITCODE
if ($LASTEXITCODE -eq 1) {
    Write-Host "ComfyChecker failed, aborted, or was exited" -ForegroundColor Red
    pause
    exit
} else {
    write-host "OK!" -ForegroundColor Green
}