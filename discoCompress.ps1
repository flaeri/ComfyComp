### User configurable ###

# Size and Bitrate
$maxSize = 50  #Megabytes, usually limit is 8, 50 or 100 depending on the server/nitro
$audioBr = 128  #Kilobytes, audio bitrate

# Speed and Quality
# VP9 (slow)
$cpuUsed = 3        # VP9 speed vs quality
$vp9Crf = 32        # VP9
# x264 (fast)
$x264p = "veryfast" # x264 preset (slow, medium, fast, faster, veryfast)
$x264crf = 22       # x264
# nvenc
$nvencCq = 26       # Nvenc H264

# Misc
$suffix = "disc"    #output is tagged with this, like "myVideo-disc.webm/mp4"
$ll = 32            #how much ffmpeg outputs to the console. 24 for quiet, 32 for progress/state

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

#get filesize
$inputSize = Read-Host "`nChoose a file size (in MegaBytes). Hit Enter for default [$($maxSize)] MB"
$parsedInput = [int]([regex]::Match($inputSize, "^(\d+)").Groups[1].Value) #regex grab first group of digits. Gets rid of kb/mb or ,. or space
$fileSize = if ($parsedInput -eq 0) { $maxSize } else { $parsedInput }
$maxSize = $fileSize

#get file
$video = read-host -Prompt "`nPlease drag&drop a video, then hit Enter" #drag video in
$video = get-childitem -path ($video -replace '"', "") #input is dumbass string, fix it
Clear-Host

# naming stuff
Set-FileVars($video) #full=wPath, base=noExt,

# enc: 0=nvenc, 1=x264, 2=vp9
if ($choice -eq 0) {
    write-host "Testing nvenc..." -ForegroundColor Yellow
    ffmpeg -hide_banner -loglevel 0 -f lavfi -i smptebars=duration=1:size=1920x1080:rate=30 -c:v h264_nvenc -t 0.1 -f null -
    if ($?) {
        write-host "Nvenc OK!" -ForegroundColor green
        $enc = 0 #nvenc
    } else {
        write-host "No hw accel encode device found, x264 (CPU) it is!" -ForegroundColor Yellow
        $enc = 1 #x264
    }
    $ext = "mp4"
} else {
    write-host "vp9 time :)"
    $enc = 2 #vp9
    $ext = "webm"
}

# 10% overhead safety 
$safeSize = $maxSize * 0.90

## Probe input file
$probeData = ffprobe -v error -show_entries format=duration:stream=height:stream=color_space:stream=color_range -of default=noprint_wrappers=1 "$video"
# get duration of file
$durationSec = ($probeData | Select-String "duration=").Line.Split('=')[1].Trim()
$durationSecClamp = [math]::Round($durationSec)
#get width
$vidHeight = ($probeData | Select-String "height=").Line.Split('=')[1].Trim()
#get input color range. Not currently used
$inRange = ($probeData | Select-String "color_range=").Line.Split('=')[1].Trim()
#get HDR
$colorSpace = ($probeData | Select-String "color_space=").Line.Split('=')[1].Trim()
if ($colorSpace -like "bt2020*" ) {
    write-host "`n HDR file detected, Color Space: $colorSpace" -ForegroundColor Yellow
    $hdr = $true
}

# convert size
$vidBr = $safeSize * 8 / $durationSec * 1000 # size in MB * 8 = bits, divided by duration. x 1000 for kbps
$vidBr = [math]::Round($vidBr) # int plz
$vidBr = $vidBr - $audioBr # account for audio bitrate
$bufSize = $vidBr*2 #bufsize x2 increases quality, lowers accuracy

# bitrate guard, if video bitrate less  than 200 kbps, give up
if ($vidBr -le 200) {
    write-host "`nBitrate is too low ($vidBr kbps)! Either increase the filesize or shorten the duration" -ForegroundColor Red
    write-host "`Exiting!" -ForegroundColor Red
    psPause
    exit
}

$bpw = $vidBr/$vidHeight #bitrate per video height
if ($enc -eq 2) {$bpw = $bpw * 2} # if vp9, 2x bpw

# used to be 5.5
if ($bpw -lt 5.6) {
    if ($vidHeight -ge 1440) {
        $downscaleRes = 1080
        $x264crf = $x264crf-2
        $nvencCq = $nvencCq-2
    }
    $bpw = $vidBr/1080
    write-host "`nNot enough bit rate for $vidHeight`p, downscaling..." -ForegroundColor Yellow
    if ($bpw -lt 5.6) {
        $downscaleRes = 720
        $x264crf = $x264crf-2
        $vp9Crf = $vp9Crf+2
        $nvencCq = $nvencCq-2
        write-host "Go to 720p" -ForegroundColor Yellow
    }
}

write-host "`nFile: $name`:"
write-host "Duration: $durationSecClamp sec" -ForegroundColor Yellow
write-host "Bitrate: $vidBr kbps" -ForegroundColor Yellow
Write-host "Max Size: $maxSize mb" -ForegroundColor Yellow
write-host "`nGo? ctrl+c to cancel" -ForegroundColor Green
pause



## Build ffmpeg command
# Input
$preInput = "-hide_banner -loglevel $ll"
$inFile = "-i '$video'"

# scale / HDR
#$src_range = "-src_range 0"
$pix = "-pix_fmt yuv420p"
$scale = "" #"-vf zscale=r=limited:m=bt709,format=yuv420p"
if ($hdr) {
    $scale = "-vf zscale=transfer=linear,tonemap=tonemap=reinhard:desat=0,zscale=r=tv:p=bt709:t=bt709:m=bt709,format=yuv420p -map_metadata -1"
    if ($downscaleRes) {
        $scale = "-vf zscale=transfer=linear:w=-2:h=$downscaleRes,tonemap=tonemap=reinhard:desat=0,zscale=r=tv:p=bt709:t=bt709:m=bt709,format=yuv420p -map_metadata -1"
    }
} elseif ($downscaleRes) {
    $scale = "-vf scale=-2:$downscaleRes"
}

# Flags
$flags = "-movflags +faststart"

# Output
$outFile = "'$dir\$baseName-$suffix.$ext'"

#codec selector
switch ( $enc )
{
    # h264 nvenc
    0 {
        $cv = "-c:v h264_nvenc -preset p6 -rc vbr -cq $nvencCq -b:v 0 -maxrate $vidBr`k -bufsize $bufSize`k -spatial-aq 1 -temporal-aq 1 -aq-strength 7"
        $ca = "-c:a aac -b:a $audioBr`k"
        $command = "ffmpeg $preInput $inFile $cv $ca $pix $scale $flags $outFile"
    }
    # libx264
    1 {
        $cv = "-c:v libx264 -preset $x264p -crf $x264crf -b:v $vidBr`k -maxrate $vidBr`k -bufsize $bufSize`k"
        $ca = "-c:a aac -b:a $audioBr`k"
        $command = "ffmpeg $preInput $inFile $cv $ca $pix $scale $flags $outFile"
    }
    # vp9
    2 {
        $cv = "-c:v libvpx-vp9 -cpu-used $cpuUsed -row-mt 1 -crf $vp9Crf -b:v $vidBr`k"
        $ca = "-c:a libopus -b:a $audioBr`k"
        $command = "ffmpeg $preInput $inFile $cv $ca $pix $scale $outFile"
    }
}

#timer
Start-Timer "$name"
# Actual run
Invoke-Expression $command

write-host "`n"
Stop-Timer $name $startTime

$outputFile = get-childitem -Path "$dir\$baseName-$suffix.$ext"
$outputFileSize = [math]::Round($outputFile.Length / 1MB, 2)
if ($outputFileSize -gt $maxSize) {
    write-host "Fail! File is larger ($outputFileSize MB) than $maxSize MB" -ForegroundColor Red
} else {
    write-host "OK! Filesize is $outPutFileSize MB" -ForegroundColor Green
}

Pop-Location #pop location back to the dir script was ran from
write-host "`Done, hit any key to open the folder containing the file"
psPause
explorer $video.Directory