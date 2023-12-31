### User configurable ###

# Size and Bitrate
$maxSize = 50  #Megabytes, usually limit is 8, 50 or 100 depending on the server/nitro
$audioBr = 128  #Kilobytes, audio bitrate

# Speed and Quality
# VP9 (slow)
$cpuUsed = 3        # VP9 speed vs quality
$vp9Crf = 32        # VP9 crf target
# x264 (fast)
$x264p = "veryfast" # x264 preset (slow, medium, fast, faster, veryfast)
$x264crf = 22       # x264 crf target
# nvenc
$nvencCq = 26       # Nvenc H264 constant quality target

# Misc
$suffix = "disc"    #output is tagged with this, like "myVideo-disc.webm/mp4"
$ll = 32            #how much ffmpeg outputs to the console. 24 for quiet, 32 for progress/state
$bphTarget = 5.6    #Default 5.6. how many bits per heigh (limit), before downscaling happen.

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
$nextChoice = -1 # used for determining what the user wants after first run

function Get-EncodingChoice {
    return $Host.UI.PromptForChoice("Slow or Fast?", $question, $Option, 1)
}

function Get-Size {
    $inputSize = Read-Host "`nChoose a file size (in MegaBytes). Hit Enter for default [$($maxSize)] MB"
    $parsedInput = [int]([regex]::Match($inputSize, "^(\d+)").Groups[1].Value) #regex grab first group of digits. Gets rid of kb/mb or ,. or space
    $fileSize = if ($parsedInput -eq 0) { $maxSize } else { $parsedInput }
    $maxSize = $fileSize

    # 10% overhead safety 
    $safeSize = $maxSize * 0.90
    return $maxSize, $safeSize
}

function Get-File {
    do {
        # Prompt the user to drag and drop a video
        $videoPath = Read-Host -Prompt "`nPlease drag&drop a video, then hit Enter"

        # Strip surrounding quotes if they exist
        $videoPath = $videoPath -replace '^"(.*)"$', '$1'

        # Check if the input is not empty and is a valid file path
        if (-not [String]::IsNullOrWhiteSpace($videoPath) -and (Test-Path -Path $videoPath -PathType Leaf)) {
            # The input is a valid file path, convert it to FileInfo object
            $video = Get-ChildItem -Path $videoPath

            # Naming stuff
            Set-FileVars $video # Full=wPath, Base=noExt
            break
        } else {
            # The input is invalid, display a warning and continue the loop
            Write-Host "Invalid input. Please enter a valid file path." -ForegroundColor Yellow
        }
    } while ($true)

    return $video
}

function Select-Encoder {
    # enc: 0=nvenc, 1=x264, 2=vp9, 3=QSV
    if ($encoderChoice -eq 0) {
        write-host "Testing encoders..." -ForegroundColor Yellow
        ffmpeg -hide_banner -f lavfi -loglevel error -i smptebars=duration=1:size=1920x1080:rate=30 -c:v h264_nvenc -t 0.1 -f null -
        if ($?) {
            write-host "Nvenc OK!" -ForegroundColor green
            $enc = 0 #nvenc
        } else {
            ffmpeg -hide_banner -f lavfi -loglevel error -i smptebars=duration=1:size=1920x1080:rate=30 -c:v h264_qsv -t 0.1 -f null -
            if ($?) {
                write-host "QSV OK!" -ForegroundColor Green
                $enc = 3
            } else {
                write-host "No hw accel encode device found, x264 (CPU) it is!" -ForegroundColor Yellow
                $enc = 1 #x264
            }
        }
        $outExtension = "mp4"
    } else {
        ffmpeg -hide_banner -loglevel 0 -f lavfi -i smptebars=duration=1:size=1920x1080:rate=30 -c:v libvpx-vp9 -t 0.1 -f null -
        if ($?) {
            write-host "VP9 OK!" -ForegroundColor green
            $enc = 2 #nvenc
            $outExtension = "webm"
        } else {
            write-host "No VP9 encoder found, falling back to x264" -ForegroundColor Yellow
            $enc = 1 #x264
            $outExtension = "mp4"
        }
    }
    Clear-Host
    return $enc, $outExtension
}

function Get-VideoInfo {
    param (
        [Parameter(Mandatory=$true)]
        [string]$video
    )

    # Probe input file
    $probeData = ffprobe -v error -show_entries format=duration:stream=height:stream=color_space:stream=color_range -of default=noprint_wrappers=1 "$video"

    # get duration of file
    $durationSec = ($probeData | Select-String "duration=").Line.Split('=')[1].Trim()
    $durationSecClamp = [math]::Round($durationSec)

    # get height
    $vidHeight = ($probeData | Select-String "height=").Line.Split('=')[1].Trim()

    # get input color range. Not currently used
    $inRange = ($probeData | Select-String "color_range=").Line.Split('=')[1].Trim()

    # get HDR
    $colorSpace = ($probeData | Select-String "color_space=").Line.Split('=')[1].Trim()
    $hdr = $false
    if ($colorSpace -like "bt2020*") {
        Write-Host "`n HDR file detected, Color Space: $colorSpace" -ForegroundColor Yellow
        $hdr = $true
    }

    # Return results as a custom object
    return @{
        DurationSec       = $durationSec
        DurationSecClamp  = $durationSecClamp
        VidHeight         = $vidHeight
        HDR               = $hdr
    }
}

function Get-Bitrate {
    param (
        [Parameter(Mandatory=$true)]
        [Int32]$safeSize,

        [Parameter(Mandatory=$true)]
        [double]$duration,

        [Parameter(Mandatory=$true)]
        [Int32]$audioBr
    )

    # convert size
    $vidBr = $safeSize * 8 / $duration * 1000 # size in MB * 8 = bits, divided by duration. x 1000 for kbps
    $vidBr = [math]::Round($vidBr) # int plz
    $vidBr = $vidBr - $audioBr # account for audio bitrate
    $bufSize = $vidBr*2 #bufsize x2 increases quality, lowers accuracy

    # bitrate guard, if video bitrate less than 200 kbps, give up
    if ($vidBr -le 200) {
        write-host "`nBitrate is too low ($vidBr kbps)! Either increase the filesize or shorten the duration" -ForegroundColor Red
        write-host "`Exiting!" -ForegroundColor Red
        psPause
        exit
    }

    return $bufsize, $vidBr
}

function Get-BitsPerHeight  {
    param (
        [Parameter(Mandatory=$true)]
        [Int32]$vidBr,

        [Parameter(Mandatory=$true)]
        [Int16]$encoder,

        [Parameter(Mandatory=$true)]
        [Int16]$height,

        [Parameter(Mandatory=$true)]
        [double]$bphTarget
    )

    $bph = $vidBr/ $height #bitrate per video height
    if ($encoder -eq 2) {$bph = $bph * 2} # if vp9, 2x bph

    if ($bph -lt $bphTarget) {
        if ($height -ge 1440) {
            $downscaleRes = 1080
            $x264crf = $x264crf-2
            $nvencCq = $nvencCq-2
        }
        $bph = $vidBr/1080
        write-host "`nNot enough bit rate for $height`p, downscaling..." -ForegroundColor Yellow
        if ($bph -lt $bphTarget) {
            $downscaleRes = 720
            $x264crf = $x264crf-2
            $vp9Crf = $vp9Crf+2
            $nvencCq = $nvencCq-2
            write-host "Go to 720p" -ForegroundColor Yellow
        }
    }

    return $bph, $downscaleRes
}

function Write-VideoInfo {
    write-host "`nFile: $name`:"
    write-host "Duration: $($videoInfo.DurationSecClamp) sec" -ForegroundColor Yellow
    write-host "Bitrate: $vidBr kbps" -ForegroundColor Yellow
    Write-host "Max Size: $maxSize mb" -ForegroundColor Yellow
    Write-Host ("Bits per Height (BPH): {0}" -f [math]::Round($bph, 2)) -ForegroundColor Yellow
}

function Build-FFmpegCommand {
    param (
        [Parameter(Mandatory=$true)]
        $video,

        [Parameter(Mandatory=$true)]
        $hdr,

        [Parameter(Mandatory=$true)]
        [Int16]$encoder,

        [Parameter(Mandatory=$true)]
        [Int16]$downscaleRes,

        [Parameter(Mandatory=$true)]
        [string]$outExtension

    )
    ## Build ffmpeg command
    # Input

    ## Escape apostrophes in the filename
    $escapedVideo = $video -replace "'", "`'"

    ## Build ffmpeg command
    # Input
    $preInput = "-hide_banner -loglevel $ll"
    $inFile = "-i `"$escapedVideo`"" # Use double quotes and escaped filename

    # scale / HDR
    #$src_range = "-src_range 0"
    #$pix = "-pix_fmt yuv420p"
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
    $outFile = "`"$dir\$baseName-$suffix.$outExtension`"" # Use double quotes and escape them

    #codec selector
    switch ( $enc )
    {
        # h264 nvenc
        0 {
            $cv = "-c:v h264_nvenc -preset p6 -rc vbr -cq $nvencCq -b:v 0 -maxrate $vidBr`k -bufsize $bufSize`k -pix_fmt nv12 -spatial-aq 1 -temporal-aq 1 -aq-strength 7"
            $ca = "-c:a aac -b:a $audioBr`k"
            $command = "ffmpeg $preInput $inFile $cv $ca $scale $flags $outFile"
        }
        # libx264
        1 {
            $cv = "-c:v libx264 -preset $x264p -crf $x264crf -b:v $vidBr`k -maxrate $vidBr`k -bufsize $bufSize`k -pix_fmt yuv420p"
            $ca = "-c:a aac -b:a $audioBr`k"
            $command = "ffmpeg $preInput $inFile $cv $ca $scale $flags $outFile"
        }
        # vp9
        2 {
            $cv = "-c:v libvpx-vp9 -cpu-used $cpuUsed -row-mt 1 -crf $vp9Crf -b:v $vidBr`k -pix_fmt yuv420p"
            $ca = "-c:a libopus -b:a $audioBr`k"
            $command = "ffmpeg $preInput $inFile $cv $ca $scale $outFile"
        }
        # QSV
        3 {
            $cv = "-c:v h264_qsv -b:v $vidBr`k -bufsize $bufsize`k -preset 1 -min_qp_i 18 -min_qp_p 20 -min_qp_b 22 -extbrc 1 -look_ahead 1 -pix_fmt nv12"
            $ca = "-c:a aac -b:a $audioBr`k"
            $command = "ffmpeg $preInput $inFile $cv $ca $scale $outFile"
        }
    }
    return $command
}

function Invoke-Encode {
    param (
        [Parameter(Mandatory=$true)]
        $ffCommand,

        [Parameter(Mandatory=$true)]
        $outExtension

    )

    #timer
    Start-Timer "$name"
    # Actual run
    Invoke-Expression $ffCommand

    $outputFilePath = Join-Path -Path $dir -ChildPath "$baseName-$suffix.$outExtension"

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

    $outputFile = Get-ChildItem $outputFilePath
    $outputFileSize = [math]::Round($outputFile.Length / 1MB, 2)
    if ($outputFileSize -gt $maxSize) {
        write-host "Fail! File is larger ($outputFileSize MB) than $maxSize MB" -ForegroundColor Red
    } else {
        write-host "OK! Filesize is $outPutFileSize MB" -ForegroundColor Green
    }
}

function Get-NextActionChoice {
    $nextActionTitle = "Encode more files?"
    $nextActionQuestion = "What would you like to do next?"
    
    $option1 = New-Object System.Management.Automation.Host.ChoiceDescription "&Repeat, same settings", "Keep current settings and run on another file"
    $option2 = New-Object System.Management.Automation.Host.ChoiceDescription "Run with &new settings", "Choose new settings and run on another file"
    $option3 = New-Object System.Management.Automation.Host.ChoiceDescription "&Exit", "Exit the script"
    $nextActionOptions = [System.Management.Automation.Host.ChoiceDescription[]]($option1, $option2, $option3)

    return $Host.UI.PromptForChoice($nextActionTitle, $nextActionQuestion, $nextActionOptions, 2)
}

### end of functions ###

do {
    if ($nextChoice -eq -1 -or $nextChoice -eq 1) {
        # If it's the first run or user chose to run with new settings
        $encoderChoice = Get-EncodingChoice #pick encode, 0 = fast, 1 = slow
        $enc, $outExtension = Select-Encoder #gets encoder and extension
    }    

    $video = Get-File #gets and parses file, path, extensions etc
    $videoInfo = Get-VideoInfo -video $video #runs ffprobe, bring back videoInfo.DurationSec, VidHeigh, HDR etc

    $maxSize, $safeSize = Get-Size #prompts for filesize and calculates size
    $bufsize, $vidBr = Get-Bitrate -safeSize $safeSize -duration $videoInfo.DurationSec -audioBr $audioBr
    $bph, $downscaleRes = Get-BitsPerHeight -vidBr $vidBr -encoder $enc -height $videoinfo.VidHeight -bphTarget $bphTarget

    Write-VideoInfo
    write-host "`nGo? ctrl+c to cancel" -ForegroundColor Green
    pause

    $ffCommand = Build-FFmpegCommand -video $video -hdr $videoInfo.HDR -downscaleRes $downscaleRes -encoder $enc -outExtension $outExtension
    Invoke-Encode -ffCommand $ffCommand -outExtension $outExtension

    # Prompt for next action
    $nextChoice = Get-NextActionChoice

} while ($nextChoice -ne 2) # Keep going as long as the choice isn't "Exit"

Pop-Location #pop location back to the dir script was ran from
write-host "`Done, hit any key to open the folder containing the file(s)"
psPause
explorer $video.Directory