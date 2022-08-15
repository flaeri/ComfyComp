# User configurable
$maxSize = 100 #Megabytes, usually limit is 50 or 100 depending on the server/nitro
$audioBr = 128 #Kilobytes, audio bitrate
$suffix = "disc" #output is tagged with this, like "myVideo-disc.webm"

### STOP TOUCHY NOW ###

#push script location
$scriptPath = $MyInvocation.MyCommand.Path
$dir = Split-Path $scriptPath
Push-Location $dir

#load helpers
. .\helpers\banner.ps1
. .\helpers\ffmpegInfo.ps1
. .\helpers\commonFunctions.ps1
write-host "`r"
Write-Host "Done checking!" -ForegroundColor Green

#get
$video = read-host -Prompt "`nPlease drag&drop a video" #drag video in
$video = get-childitem -path ($video -replace '"', "") #input is dumbass string, fix it
Clear-Host

# naming stuff
Set-FileVars($video) #full=wPath, base=noExt,

# calc

## get duration of file
$durationSec = ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$video"

$vidBr = $maxsize * 8 / $durationSec * 1000 # size in MB * 8 = bits, divided by duration. x 1000 for kbps
$vidBr = [math]::Round($vidBr) # int plz
$vidBr = $vidBr - $audioBr # account for audio bitrate

write-host "`n$name`:" -ForegroundColor Green
write-host "Duration: $durationSec sec" -ForegroundColor Yellow
write-host "Bitrate (kbps): $vidBr" -ForegroundColor Yellow
write-host "`nGo?" -ForegroundColor Green
pause

#timer
Start-Timer "$name"

ffmpeg -hide_banner -loglevel 32 -i $video -c:v libvpx-vp9 -deadline realtime -cpu-used 6 -row-mt 1 -crf 26 `
-b:v $vidBr`k -b:a $audioBr`k -pix_fmt yuv420p $baseName-$suffix`.webm

write-host "`n"
Stop-Timer $name $startTime

Pop-Location #pop location back to the dir script was ran from
write-host "`Done, hit any key to open the folder containing the file"
psPause
explorer $video.Directory