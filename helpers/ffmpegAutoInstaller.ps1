# This script will automatically download and extract ffmpeg into C:\ffmpeg
$ffmpegPath = "C:\ffmpeg"

Write-Host "Downloading the latest ffmpeg version to $ffmpegPath." -ForegroundColor Yellow
$ProgressPreference = 'SilentlyContinue' # Faster download
Write-Host "We're downloading. Please be patient :)"
Invoke-WebRequest -Uri https://otterbro.com/ffmpeg.zip -outfile "ffmpeg.zip"
$ProgressPreference = 'Continue'

# Create directory if it doesn't exist, or clear it if it does
if (Test-Path $ffmpegPath) {
    Get-ChildItem -Path $ffmpegPath -Recurse | Remove-Item -Force -Recurse
} else {
    New-Item -path $ffmpegPath -ItemType "directory"
}

# Extract ffmpeg
Expand-Archive -path "ffmpeg.zip" $ffmpegPath
Remove-Item "ffmpeg.zip"
$global:ffmpegOutdated = $false
Write-Host "Updated ffmpeg in $ffmpegPath." -ForegroundColor Green