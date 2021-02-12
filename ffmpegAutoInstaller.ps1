# This script will automatically download and extract gyans latest ffmpeg build into
# C:\ffmpeg\ and add it to your path :)
$ffmpegPath = "C:\ffmpeg"
if (Test-Path "$ffmpegPath\ffmpeg.exe") {
    Start-Process "$ffmpegPath\ffmpeg.exe"
    write-host "Seems you already have ffmpeg in $ffmpegpath" -ForegroundColor Green
    write-host "no need to run this script again, we have what we need." -ForegroundColor Green
} else {
    Write-Host "$ffmpegPath does not exist, downloading it." -ForegroundColor Yellow
    $ProgressPreference = 'SilentlyContinue' #its very slow to download without this
    Write-Host "We're downloading. Please be patient :)"
    Invoke-WebRequest -Uri https://otterbro.com/ffmpeg20210106.zip -outfile "ffmpeg.zip"
    $ProgressPreference = 'Continue'
    mkdir -path "$ffmpegPath"
    Expand-Archive -path "ffmpeg.zip" $ffmpegPath
    Remove-Item "ffmpeg.zip"
}
write-host "Trying to run ComfyComp again!" -ForegroundColor Green
Invoke-Expression .\comfyComp.ps1