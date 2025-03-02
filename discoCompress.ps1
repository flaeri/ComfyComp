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
$nextChoice = -1 # used for determining what the user wants after first run

$Encoders = @{
    "hevc_nvenc" = @{ supported = $false; priority = 1 }
    "hevc_qsv" = @{ supported = $false; priority = 2 }
    "h264_nvenc" = @{ supported = $false; priority = 1 }
    "h264_qsv" = @{ supported = $false; priority = 2 }
    "x264" = @{ supported = $true; priority = 3 }
    "libvpx-vp9" = @{ supported = $false; priority = 1 }
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

function Optimize-Quality  {
    param (
        [Parameter(Mandatory=$true)]
        [Int32]$vidBr,

        [Parameter(Mandatory=$true)]
        [string]$encoder,

        [Parameter(Mandatory=$true)]
        [Int16]$height,

        [Parameter(Mandatory=$true)]
        [double]$bphTarget
    )

    $bph = $vidBr/ $height #bitrate per video height
    if ($encoder -eq "libvpx-vp9") {$bph = $bph * 2}

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

function Get-AvailableEncoders {
    foreach ($encoder in $Encoders.Keys) {
        if (Test-Encoder -Encoder $encoder) {
            write-host "$encoder OK!" -ForegroundColor Green
            $Encoders[$encoder].supported = $true
        }
    }
}

function Get-EncodingChoice {
    $question = "Choose encoding option: `n HEVC (fast, efficient, somewhat limited compatibility), `n H264 (default), `n VP9 (slow, very efficient, good compatibility)"
    $choices = @()

    if ($Encoders["hevc_nvenc"].supported -or $Encoders["hevc_qsv"].supported) {
        $choices += New-Object System.Management.Automation.Host.ChoiceDescription "&1. HEVC", "HEVC (fast, efficient, somewhat limited compatibility)"
    }
    if ($Encoders["h264_nvenc"].supported -or $Encoders["h264_qsv"].supported -or $Encoders["x264"].supported) {
        $choices += New-Object System.Management.Automation.Host.ChoiceDescription "&2. H264", "H264 (default)"
    }
    if ($Encoders["libvpx-vp9"].supported) {
        $choices += New-Object System.Management.Automation.Host.ChoiceDescription "&3. VP9", "VP9 (slow, very efficient, good compatibility)"
    }

    $defaultChoice = 1
    return $Host.UI.PromptForChoice("Encoding Options", $question, $choices, $defaultChoice)
}

function Select-Encoder {
    param (
        [int]$encoderChoice
    )

    $selectedEncoder = $null
    $outExtension = "mp4"

    switch ($encoderChoice) {
        0 { # HEVC
            $hevcEncoders = $Encoders.GetEnumerator() | Where-Object { $_.Key -like "hevc_*" -and $_.Value.supported } | Sort-Object -Property Value.priority
            if ($hevcEncoders.Count -gt 0) {
                $selectedEncoder = $hevcEncoders[0].Key
            } else {
                write-host "No HEVC encoder found, falling back to H264" -ForegroundColor Yellow
                $encoderChoice = 1
            }
        }
        1 { # H264
            $h264Encoders = $Encoders.GetEnumerator() | Where-Object { $_.Key -like "h264_*" -and $_.Value.supported } | Sort-Object -Property Value.priority
            if ($h264Encoders.Count -gt 0) {
                $selectedEncoder = $h264Encoders[0].Key
            } else {
                write-host "No hardware H264 encoder found, falling back to x264" -ForegroundColor Yellow
                $selectedEncoder = "x264"
            }
        }
        2 { # VP9
            if ($Encoders["libvpx-vp9"].supported) {
                $selectedEncoder = "libvpx-vp9"
                $outExtension = "webm"
            } else {
                write-host "No VP9 encoder found, falling back to x264" -ForegroundColor Yellow
                $selectedEncoder = "x264"
            }
        }
    }

    write-host "`nEncoding with $selectedEncoder" -ForegroundColor Yellow
    return $selectedEncoder, $outExtension
}

function Build-FFmpegCommand {
    param (
        [Parameter(Mandatory=$true)]
        $video,

        [Parameter(Mandatory=$true)]
        $hdr,

        [Parameter(Mandatory=$true)]
        [string]$encoder,

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
    switch ($encoder) {
        "h264_nvenc" {
            $cv = "-c:v h264_nvenc -preset p6 -rc vbr -cq $nvencCq -b:v 0 -maxrate $vidBr`k -bufsize $bufSize`k -pix_fmt nv12 -spatial-aq 1 -temporal-aq 1 -aq-strength 7"
            $ca = "-c:a aac -b:a $audioBr`k"
            $command = "ffmpeg $preInput $inFile $cv $ca $scale $flags $outFile"
        }
        "hevc_nvenc" {
            $cv = "-c:v hevc_nvenc -preset p6 -rc vbr -cq $nvencCq -b:v 0 -maxrate $vidBr`k -bufsize $bufSize`k -pix_fmt nv12 -spatial-aq 1 -temporal-aq 1 -aq-strength 7"
            $ca = "-c:a aac -b:a $audioBr`k"
            $command = "ffmpeg $preInput $inFile $cv $ca $scale $flags $outFile"
        }
        "h264_qsv" {
            $cv = "-c:v h264_qsv -b:v $vidBr`k -bufsize $bufsize`k -preset 1 -extbrc 1 -look_ahead 30 -pix_fmt nv12"
            $ca = "-c:a aac -b:a $audioBr`k"
            $command = "ffmpeg $preInput $inFile $cv $ca $scale $outFile"
        }
        "hevc_qsv" {
            $cv = "-c:v hevc_qsv -b:v $vidBr`k -bufsize $bufsize`k -preset 1 -extbrc 1 -look_ahead 30 -pix_fmt nv12"
            $ca = "-c:a aac -b:a $audioBr`k"
            $command = "ffmpeg $preInput $inFile $cv $ca $scale $outFile"
        }
        "x264" {
            $cv = "-c:v libx264 -preset $x264p -crf $x264crf -b:v $vidBr`k -maxrate $vidBr`k -bufsize $bufSize`k -pix_fmt yuv420p"
            $ca = "-c:a aac -b:a $audioBr`k"
            $command = "ffmpeg $preInput $inFile $cv $ca $scale $flags $outFile"
        }
        "libvpx-vp9" {
            $cv = "-c:v libvpx-vp9 -cpu-used $cpuUsed -row-mt 1 -crf $vp9Crf -b:v $vidBr`k -pix_fmt yuv420p"
            $ca = "-c:a libopus -b:a $audioBr`k"
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

### Main ###
Get-AvailableEncoders

do {
    if ($nextChoice -eq -1 -or $nextChoice -eq 1) {
        # If it's the first run or user chose to run with new settings
        $encoderChoice = Get-EncodingChoice
        $enc, $outExtension = Select-Encoder -encoderChoice $encoderChoice
    }    

    $video = Get-File #gets and parses file, path, extensions etc
    $videoInfo = Get-VideoInfo -video $video #runs ffprobe, bring back videoInfo.DurationSec, VidHeigh, HDR etc

    $maxSize, $safeSize = Get-Size #prompts for filesize and calculates size
    $bufsize, $vidBr = Get-Bitrate -safeSize $safeSize -duration $videoInfo.DurationSec -audioBr $audioBr
    $bph, $downscaleRes = Optimize-Quality -vidBr $vidBr -encoder $enc -height $videoinfo.VidHeight -bphTarget $bphTarget

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