### User configurable ###

# Size and Bitrate
$maxSize = 50   #Megabytes, usually limit is 50 or 100 depending on the server/nitro
$audioBr = 128  #Kilobytes, audio bitrate

# Speed and Quality
$cpuUsed = 3        # VP9
$x264p = "veryfast" # x264 preset (slow, medium, fast, faster, veryfast) 

# Misc
$suffix = "disc"    #output is tagged with this, like "myVideo-disc.webm/mp4"
$ll = 24            #how much ffmpeg outputs to the console

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

#static
$question = "Fast (h264, lower quality), Slow (vp9, higher quality)"
$option = "&Fast", "&Slow"

#pick encode, 0 = fast, 1 = slow
$choice = $Host.UI.PromptForChoice("Slow or Fast?", $question, $Option, 1)

#get
$video = read-host -Prompt "`nPlease drag&drop a video, then hit Enter" #drag video in
$video = get-childitem -path ($video -replace '"', "") #input is dumbass string, fix it
Clear-Host

# naming stuff
Set-FileVars($video) #full=wPath, base=noExt,

# enc: 0=nvenc, 1=x264, 3=vp9
if ($choice -eq 0) {
    write-host "Testing nvenc..." -ForegroundColor Yellow
    ffmpeg -hide_banner -loglevel 0 -f lavfi -i smptebars=duration=1:size=1920x1080:rate=30 -c:v h264_nvenc -t 0.1 -f null -
    if ($?) {
        write-host "Nvenc OK!" -ForegroundColor green
        $enc = 0 #nvenc
    } else {
        write-host "No nvenc device found! x264 it is!" -ForegroundColor Yellow
        $enc = 1 #x264
    }
    $ext = "mp4"
} else {
    write-host "vp9 time :)"
    $enc = 2 #vp9
    $ext = "webm"
}

# 5% overhead safety 
$safeSize = $maxSize * 0.95

## get duration of file
$durationSec = ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$video"
$durationSecClamp = [math]::Round($durationSec)

$vidBr = $safeSize * 8 / $durationSec * 1000 # size in MB * 8 = bits, divided by duration. x 1000 for kbps
$vidBr = [math]::Round($vidBr) # int plz
$vidBr = $vidBr - $audioBr # account for audio bitrate
$bufSize = $vidBr*2

write-host "`n$name`:"
write-host "Duration: $durationSecClamp sec" -ForegroundColor Yellow
write-host "Bitrate (kbps): $vidBr" -ForegroundColor Yellow
write-host "`nGo? ctrl+c to cancel" -ForegroundColor Green
pause

#timer
Start-Timer "$name"

switch ( $enc )
{
    # h264 nvenc
    0 {ffmpeg -hide_banner -loglevel $ll -hwaccel cuda -i $video -c:v h264_nvenc -preset p6 -rc vbr `
        -cq 24 -bf 2 -maxrate $vidBr`k -bufsize $bufSize`k -spatial-aq 1 -temporal-aq 1 -aq-strength 7 `
        -b:a $audioBr`k -pix_fmt yuv420p -movflags +faststart $dir\$baseName-$suffix.$ext}
    # libx264
    1 {ffmpeg -hide_banner -loglevel $ll -i $video -c:v libx264 -preset $x264p -crf 1 -b:v $vidBr`k -maxrate $vidBr`k -bufsize $bufSize`k `
        -b:a $audioBr`k -pix_fmt yuv420p -movflags +faststart $dir\$baseName-$suffix.$ext}
    # vp9
    2 {ffmpeg -hide_banner -loglevel $ll -i $video -c:v libvpx-vp9 -cpu-used $cpuUsed -row-mt 1 -crf 26 `
        -b:v $vidBr`k -b:a $audioBr`k -pix_fmt yuv420p $dir\$baseName-$suffix.$ext}
}

write-host "`n"
Stop-Timer $name $startTime

$outputFile = get-childitem -Path "$dir\$baseName-$suffix.$ext"
$outputFileSize = [math]::Round($outputFile.Length / 1MB)
if ($outputFileSize -gt $maxSize) {
    write-host "Fail! File is larger ($outputFileSize MB) than $maxSize MB" -ForegroundColor Red
} else {
    write-host "OK! Filesize is $outPutFileSize MB" -ForegroundColor Green
}


Pop-Location #pop location back to the dir script was ran from
write-host "`Done, hit any key to open the folder containing the file"
psPause
explorer $video.Directory