### User configurable ###
$x264p = "veryfast" # x264 preset (slow, medium, fast, faster, veryfast)
$x264crf = 18       # x264 crf target
# nvenc
$nvencCq = 23      # Nvenc H264 constant quality target

# Misc
$suffix = "normal"    #output is tagged with this, like "myVideo-disc.webm/mp4"
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

function Build-FFmpegCommandNormal {
    param (
        [Parameter(Mandatory=$true)]
        $video,

        [Parameter(Mandatory=$true)]
        $hdr,

        [Parameter(Mandatory=$true)]
        [Int16]$encoder

    )
    ## Build ffmpeg command
    # Input

    ## Escape apostrophes in the filename
    $escapedVideo = $video -replace "'", "`'"

    ## Build ffmpeg command
    # Input
    $ll = 48
    $preInput = "-hide_banner -loglevel $ll"
    $inFile = "-i `"$escapedVideo`"" # Use double quotes and escaped filename

    # scale / HDR
    if ($hdr) {
        write-host "`rTonemapping HDR!" -ForegroundColor Yellow
        $scale = "-vf zscale=transfer=linear,tonemap=tonemap=reinhard:desat=0,zscale=r=tv:p=bt709:t=bt709:m=bt709,format=yuv420p -map_metadata -1"
    }

    # Flags
    $flags = "-movflags +faststart"

    # Output
    $audioBr = 192
    $outFile = "`"$dir\$baseName-$suffix.mp4`"" # Use double quotes and escape them

    #codec selector
    switch ( $encoder )
    {
        # h264 nvenc
        0 {
            write-host "setting up nvenc"
            $cv = "-c:v h264_nvenc -preset p6 -rc vbr -cq $nvencCq -b:v 0 -maxrate 120M -bufsize 240M -pix_fmt nv12 -spatial-aq 1 -temporal-aq 1 -aq-strength 7"
            $ca = "-c:a aac -b:a $audioBr`k"
            $command = "ffmpeg $preInput $inFile $cv $ca $scale $flags $outFile"
        }
        # libx264
        1 {
            write-host "setting up x264"
            $cv = "-c:v libx264 -preset $x264p -crf $x264crf -pix_fmt yuv420p"
            $ca = "-c:a aac -b:a $audioBr`k"
            $command = "ffmpeg $preInput $inFile $cv $ca $scale $flags $outFile"
        }
    }
    return $command
}

$video = Get-File #gets and parses file, path, extensions etc
$videoInfo = Get-VideoInfo -video $video #runs ffprobe, bring back videoInfo.DurationSec, VidHeigh, HDR etc

### select encoder ###

write-host "Testing encoders..." -ForegroundColor Yellow
ffmpeg -hide_banner -f lavfi -loglevel error -i smptebars=duration=1:size=1920x1080:rate=30 -c:v h264_nvenc -t 0.1 -f null -
if ($?) {
    write-host "Nvenc OK!" -ForegroundColor green
    $enc = 0 #nvenc
} else {
    write-host "No nvenc, using x264"
    $enc = 1 #x264
}

$ffCommand = Build-FFmpegCommandNormal -video $video -hdr $videoInfo.HDR -encoder 1 #$enc

#timer
Start-Timer "$name"
Invoke-expression $ffCommand

$outputFilePath = Join-Path -Path $dir -ChildPath "$baseName-$suffix.mp4"

# Check if the file exists and is not empty
if (-not (Test-Path -Path $outputFilePath -PathType Leaf)) {
    Write-Host "FFmpeg failed!" -ForegroundColor Red
    write-host "Path: $outputFilePath"
    Write-Host "Output file not found. Please check error messages above."
    psPause
} elseif ((Get-Item -Path $outputFilePath).Length -le 0) {
    Write-Host "FFmpeg failed!" -ForegroundColor Red
    Write-Host "Output file is empty. Please check error messages above."
    psPause
}

write-host "`n"
Stop-Timer $name $startTime

Pop-Location #pop location back to the dir script was ran from
write-host "`Done, hit any key to open the folder containing the file(s)"
psPause
explorer $video.Directory