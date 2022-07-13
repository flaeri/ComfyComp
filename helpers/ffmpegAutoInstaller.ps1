# This script will automatically download and extract ffmpeg into
# C:\ffmpeg\ and add it to your path :)
$ffmpegPath = "C:\ffmpeg"
if (Test-Path "$ffmpegPath\ffmpeg.exe") {
    Start-Process "$ffmpegPath\ffmpeg.exe"
    write-host "Seems you already have ffmpeg in $ffmpegpath" -ForegroundColor Green
    write-host "no need to run this script again, we have what we need." -ForegroundColor Green
    pause
} else {
    Write-Host "$ffmpegPath does not exist, downloading it." -ForegroundColor Yellow
    $ProgressPreference = 'SilentlyContinue' #its very slow to download without this
    Write-Host "We're downloading. Please be patient :)"
    Invoke-WebRequest -Uri https://otterbro.com/ffmpeg.zip -outfile "ffmpeg.zip"
    $ProgressPreference = 'Continue'
    New-Item -path "$ffmpegPath" -ErrorAction SilentlyContinue
    Expand-Archive -path "ffmpeg.zip" $ffmpegPath
    Remove-Item "ffmpeg.zip"
    Write-Host "adding ffmpeg to path" -ForegroundColor Green
    $ENV:PATH="$ENV:PATH;$FlaeriFfmpegPath"
}