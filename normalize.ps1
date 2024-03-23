### User configurable ###
$x264p = "veryfast" # x264 preset (slow, medium, fast, faster, veryfast)
$x264crf = 18       # x264 crf target
# nvenc
$nvencCq = 23      # Nvenc H264 constant quality target

# Misc
$suffix = "norm"    #output is tagged with this, like "myVideo-disc.webm/mp4"
$ll = 24            #how much ffmpeg outputs to the console. 24 for quiet, 32 for progress/state

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
        $vidInfo,

        [Parameter(Mandatory=$true)]
        [Int16]$encoder

    )
    ## Build ffmpeg command
    # Input

    ## Escape apostrophes in the filename
    $escapedVideo = $video -replace "'", "`'"

    ## Build ffmpeg command
    # Input
    #$ll = 32
    $preInput = "-hide_banner -init_hw_device vulkan -loglevel $ll -progress pipe:1"
    $inFile = "-i `"$escapedVideo`"" # Use double quotes and escaped filename

    # Initialize the filter components
    $vFilters = @()

    # Check for downscaling requirement
    if ($vidInfo["VidWidth"] -gt 1920) {
        $vFilters += "libplacebo=w=1920:h=-2"
    }

    # HDR tonemapping, including transfer to linear light
    if ($vidInfo["HDR"]) {
        # Determine if we need to prepend a comma. This is necessary if downscaling is already part of the filter.
        $separator = if ($vFilters.Count -gt 0) { "," } else { "" }
        
        # Construct the HDR tonemapping filter, including color space conversion
        #$hdrFilter = "${separator}zscale=transfer=linear,tonemap=tonemap=reinhard:desat=0,zscale=r=tv:p=bt709:t=bt709:m=bt709"
        # $hdrFilter = "${separator}libplacebo=tonemapping=bt.2446a:range=tv:color_primaries=bt709:color_trc=bt709:colorspace=bt709"
        $hdrFilter = "${separator}libplacebo=tonemapping=bt.2390:range=tv:color_primaries=bt709:color_trc=bt709:colorspace=bt709"

        # Append the HDR filter to the filter array
        $vFilters += $hdrFilter
    }

    # Join all filter components
    $filterString = $vFilters -join ''

    # Construct the final filter argument
    $vfArg = if ($filterString) { "-vf `"$filterString`"" } else { "" }

    # Flags
    $flags = "-movflags +faststart -profile:v high -level:v 42"

    # Check if the video has a surround sound layout
    $af = ""
    if ($vidInfo["SurroundSound"]) {
        $audioLayout = $vidInfo["AudioChannelLayout"]
        $downmixCommand = Get-AudioDownmixCommand -audioChannelLayout $audioLayout
    
        if ($downmixCommand) {
            # Apply the specific downmix command if available
            $af = "-af `"$downmixCommand`""
            Write-Host "`nSpecific downmix command applied: `n$downmixCommand"
        } else {write-host "`nNo specific downmix found, using -ac 2"}
    }    

    # Output
    $audioBr = 192
    $outFile = "`"$dir\$baseName-$suffix.mp4`"" # Use double quotes and escape them

    #codec selector
    # Codec selection and command assembly
    $cv = ""
    $ca = "-c:a aac -b:a ${audioBr}k -ac 2"

    switch ($encoder) {
        0 {
            $cv = "-c:v h264_nvenc -preset p6 -rc vbr -cq $nvencCq -b:v 0 -maxrate 62M -bufsize 125M -pix_fmt nv12 -spatial-aq 1 -temporal-aq 1 -aq-strength 7"
        }
        1 {
            $cv = "-c:v libx264 -preset $x264p -crf $x264crf -pix_fmt yuv420p"
        }
    }

    $command = "ffmpeg $preInput $inFile $cv $ca $af $vfArg $flags $outFile"
    write-host "`nUsing ffcmd: $command"
    return $command
}

$video = Get-File #gets and parses file, path, extensions etc
$videoInfo = Get-VideoInfo -video $video #runs ffprobe, bring back videoInfo.DurationSec, VidHeigh, HDR etc
$streamInfo = Get-VideoFramerateAndDuration -inputFile $video

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

$ffCommand = Build-FFmpegCommandNormal -video $video -vidInfo $videoInfo -encoder $enc


#timer
Start-Timer "$name"
$progressData = @{}
# Start the encoding process and monitor its progress
Invoke-Expression $ffCommand | ForEach-Object {
    if ($_ -match "^(frame|fps|stream_0_0_q|bitrate|total_size|out_time_us|out_time_ms|out_time|dup_frames|drop_frames|speed|progress)=(.+)") {
        $progressData[$matches[1]] = $matches[2]
    }
    if ($_ -match "progress=(continue|end)") {
        Write-FFmpegProgress -ProgressData $progressData -videoInfo $videoInfo -streamInfo $streamInfo
        if ($matches[1] -eq "end") {
            Write-Host "FFmpeg encoding completed."
        }
        # Clear the hashtable for the next set of progress data
        $progressData.Clear()
    }
}

Stop-Timer $name $startTime

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

Pop-Location #pop location back to the dir script was ran from
write-host "`nDone, hit any key to open the folder containing the file(s)"
psPause
explorer $video.Directory