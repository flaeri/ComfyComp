﻿#push script location
$scriptPath = $MyInvocation.MyCommand.Path
$dir = Split-Path $scriptPath
Push-Location $dir

#loading functions
. .\helpers\commonFunctions.ps1
. .\helpers\Verifier.ps1

# Settings
$ow = "n"           #overwrite files in output dir. Switch to "y" (yes), if you would like.
$cq = 24            #CQ value, lower number, higher quality and bigger files.
$mr = "100M"        #maxrate, 100mbit shouldn't need to change unless its huge resolution, also does bufsize
$ll = 24            #loglevel, set 32 if you want normal output. This (24) will only show warnings.
$suffix = "comp"    #name that is used as a suffix for files in the output folder. Easier to tell them apart, and lower risk of overwriting.

#
### Stop editing stuff now, unless you are every confident in your changes :)
#

write-host "HEVC nvenc, VBR-CQ, adapts to nvenc hardware capabilities. Easily adjustable." -ForegroundColor Magenta -BackgroundColor black
write-host "`r"

Push-Location -path $rootLocation #Dont edit edit this, edit the config.json or delete it

#testing for nvenc
ffmpeg -hide_banner -loglevel $ll -f lavfi -i smptebars=duration=1:size=1920x1080:rate=30 -c:v hevc_nvenc -t 1 -f null -
if ( $LASTEXITCODE -eq 1) {
    write-host "Nvenc HEVC is NOT supported on this card, sorry!" -ForegroundColor Red
    write-host "The script will now exit" -ForegroundColor Yellow -BackgroundColor Black
    Pause
    exit
} else {
    write-host "Nvenc HEVC supported!" -ForegroundColor Green
}

#testing hevc b-frames
ffmpeg -hide_banner -loglevel 0 -f lavfi -i smptebars=duration=1:size=1920x1080:rate=30 -c:v hevc_nvenc -bf 2 -t 1 -f null -
Write-Host "`r"
if ( $LASTEXITCODE -eq 1) {
    write-host "HEVC B-frames not supported on your chip" -ForegroundColor Red
    $bf = 0
    Write-Host "B-Frames =" $bf
    write-host "We will continue without them :) Some other features also need to be disabled" -ForegroundColor Yellow -BackgroundColor Black
} else {
    write-host "HEVC B-frames ARE supported on your chip, yay!" -ForegroundColor Green
    $bf = 2
    Write-Host "B-Frames =" $bf
}
#if b-frame fail, we assume its 10 series or below, and we need to disable more stuff. This is stupid, and I'm okay with that.
if ($bf -ne 0) {
    $taq = 1
    $ref = 4
    $bref = 2
} else {
    $taq = 0
    $ref = 0
    $bref = 0
}
#print state of current parameters
Write-Host "Temporal AQ = $taq"
Write-Host "Reference frames = $ref"
Write-Host "B reference = $bref"
write-host "`r"

#where you at
write-host "Working directory: $PWD"
#testing folders
foreach ($folder in $folders) {
    if (Test-Path -Path $folder) {
    Write-Host "$folder confirmed!" -ForegroundColor Green
}
    else {
        write-host "$folder does not exist. Creating." -ForegroundColor Yellow
        mkdir $folder
    }
}

write-host "`r"
Write-host "Current parameters:"
Write-host "CQ value chosen: $cq"
Write-host "Maxrate: $mr"
Write-host "overwriting output files: $ow"
write-host "`r"

Write-Output "Hit Enter to start, or ctrl+c / exit the window to stop"
pause
write-host "`r"

#grab the items in the input folder
$videos = Get-ChildItem -Path $inputVids -Recurse

#loop them all.
foreach ($video in $videos) {
    $shortName = $video.BaseName #useful for naming.
    $env:FFREPORT = "file=$logs\\$shortName.log:level=32" #ffmpeg is hardcoded to look for an environment variable, cus it needs to be known before we fire.
    Write-host "Start encoding: $video"
    write-host "`r"

    #multi line drifting
    ffmpeg -$ow -benchmark -loglevel $ll -hwaccel auto -i $inputVids\$video -map 0 -c:v hevc_nvenc -refs $ref `
    -preset p7 -rc vbr -cq $cq -bf $bf -maxrate $mr -bufsize $mr -spatial-aq 1 -temporal-aq $taq -aq-strength 7 `
    -b_ref_mode $bref -c:a copy $outputVids\$shortName-$suffix.mp4

    Write-host "Encoding $video completed in:"
    $time = select-string -Path $logs\$shortName.log -Pattern 'rtime=(.*)' | ForEach-Object{$_.Matches.Groups[1].Value} #ugly parsing to grab time to complete
    Write-host "$time seconds" -ForegroundColor Magenta
    $time | Out-File -FilePath $logs\$shortName-time.txt -Append
    write-host "`r"

    #remove-item $logs\$shortName.log #remove the full log. #uncomment if you want to clean the logs on completion.
}
#CountEm
Write-Host "Done! Files attempted:" $videos.Count
pause #hit em up with a nice pause, so they know its done and didn't crash :)
exit 0