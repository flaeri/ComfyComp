#push script location
$scriptPath = $MyInvocation.MyCommand.Path
$dir = Split-Path $scriptPath
Push-Location $dir

#loading functions, running tests
. .\helpers\banner.ps1
. .\helpers\ffmpegInfo.ps1
. .\helpers\commonFunctions.ps1
write-host "`r"
Write-Host "Done checking!" -ForegroundColor Green

# --- User configurable ---

#file/folder
$in = "C:\temp\comfyComp\input"      #location of files you want to encoder
$out = "C:\temp\comfyComp\output"   #location of where you want the encoded files to be

#etc
$ll = 24            #loglevel, set 32 if you want normal output. This (24) will only show warnings.
$ow = "n"           #overwrite files in output dir. Switch to "y" (yes), if you would like.
$suffix = "custom"  #name used as suffix for files in output folder. Easier to tell them apart, and lower risk of overwriting.
$outputExt = "mp4"  #output extension, like mov,mp4,mkv etc


#ffmepg command
function Build-FFmpegCommandCustom {
    param (
        [Parameter(Mandatory=$true)]
        $video,

        [Parameter(Mandatory=$true)]
        $vidInfo

    )
    ## Build ffmpeg command
    # Input

    ## Escape apostrophes in the filename
    $escapedVideo = $video -replace "'", "`'"

    ## Build ffmpeg command
    # Input
    #$ll = 32
    $preInput = "-hide_banner -loglevel $ll -progress pipe:1"
    $inFile = "-i `"$escapedVideo`"" # Use double quotes and escaped filename

    # edit here
    $command = "ffmpeg $preInput $inFile -c:v libx264 -c:a copy -preset veryfast -crf 14 -pix_fmt yuv444p -movflags faststart $out\$baseName-$suffix.mp4"

    write-host "`nUsing ffcmd: $command"
    return $command
}

# --- END of user configurable ---

#get list of files
$videos = Get-ChildItem -Path $in -Recurse

write-host "Number of videos:" $videos.count -ForegroundColor Yellow
Write-host "Overwrite output files: $ow" -ForegroundColor Yellow
write-host "Ready to go? If not, exit or hit ctrl+c" -ForegroundColor Green
Pause
write-host "`r"

#counters
$fail = 0
$ok = 0
$skip = 0

#totalTime
$totalStart = get-date

foreach ($video in $videos) {

    Set-FileVars($video) #full=wPath, base=noExt,

    $videoInfo = Get-VideoInfo -video $video #runs ffprobe, bring back videoInfo.DurationSec, VidHeigh, HDR etc
    $streamInfo = Get-VideoFramerateAndDuration -inputFile $video
    $ffCommand = Build-FFmpegCommandCustom -video $video -vidInfo $videoInfo

    $fullOut = "$out\$baseName-$suffix.$outputExt"
    $skipVid = $False

    if ((test-path $fullOut) -And ($ow -eq "n")) {
        $skip++
        $skipVid = $True
        write-host "$name already exists, skipping" -ForegroundColor Yellow
        write-host "`r"
    }

    if (!($skipVid)) {
        Start-Timer $name

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

        if (!$?) {
            $fail++
        } else {
            $ok++
        }
        Stop-Timer $name $startTime
    }
}

$fg = "green"
if ($skip -gt 0) {
    set-variable -name fg -value "yellow"
}
if ($fail -gt 0) {
    set-variable -name fg -value "red"
}

$totalTime = new-timespan -start $totalStart -End (get-date)

write-host "`n ---- Summary ----"
write-host "Total completion time: $totalTime" -foregroundcolor Magenta
Write-Host "Success: $ok | Skip: $skip | Fail: $fail" -ForegroundColor $fg
Pop-Location #pop location back to the dir script was ran from
psPause