#
### User adjustable stuff.
#
## PICK WHERE YOU WANT THE ROOT TO BE
#
Push-Location -path 'C:\TEMP\ffmpeg test' #root directory, all folder will be under this
$inputVids = "01 Input"
$outputVids = "02 Output" 
$logs = "03 Logs"
$cq = 24 #CQ value, lower number, higher quality and bigger files.
$mr = "100M" #maxrate, 100mbit shouldnt need to change unless its huge resolution, also does bufsize
$ll = 24 #loglevel, set 32 if you want normal output. This (24) will only show warnings.
$ow = "n" #overwrite files in output dir. Switch to "y" (yes), if you would like.
#Cute banner
Get-Content .\banner.txt
write-host "`n"

# tagline, and shilling
write-host "https://blog.otterbro.com" -ForegroundColor Magenta -BackgroundColor black
write-host "HEVC nvenc, VBR-CQ, adapts to nvenc hardware capabilities. Easily adjustable." -ForegroundColor Magenta -BackgroundColor black
write-host "`n"

#testing hevc b-frames
ffmpeg -hide_banner -loglevel $ll -f lavfi -i smptebars=duration=1:size=1920x1080:rate=30 -c:v hevc_nvenc -bf 2 -t 1 -f null -
Write-Host "`n"
if ( $LASTEXITCODE -eq 1) {
    write-host "HEVC B-frames not supported on your chip" -ForegroundColor Red
    $bf = 0
    Write-Host "B-Frames =" $bf
    write-host "We will continue without them :) some other features also need to be disabled" -ForegroundColor Yellow -BackgroundColor Black
} else {
    write-host "HEVC B-frames ARE supported on your chip, yay!" -ForegroundColor Green
    $bf = 2
    Write-Host "B-Frames =" $bf
}
#if b-frames fail, we assume its 10 series or below, and we need to disable more stuff. Dont bully me, I dont care enough to re-write this to not be dumb... I know it is.
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
write-host "`n"

#where you at
write-host "Working directory: $PWD"
write-host "`n"
Write-host "Current parameters:"
Write-host "CQ value chosen: $cq"
Write-host "Maxrate: $mr"
Write-host "overwriting output files: $ow"
write-host "`n"

Write-Output "Hit Enter to start, or ctrl+c / exit the window to stop"
pause
write-host "`n"

#grab the items in the input folder
$videos = Get-ChildItem -Path $inputVids -Recurse

#loop them all.
foreach ($video in $videos) {
    $shortName = $video.BaseName #useful for naming.
    $env:FFREPORT = "file=$logs\\$shortName.log:level=32" #ffmpeg is hardcoded to look for an envoirenment variable, cus it needs to be known before we fire.
    Write-host "Start encoding: $video"
    write-host "`n"

    #multi line drifting
    ffmpeg -$ow -benchmark -loglevel $ll -hwaccel auto -i $inputVids\$video -map 0 -c:v hevc_nvenc -refs $ref `
    -preset p7 -rc vbr -cq $cq -bf $bf -maxrate $mr -bufsize $mr -spatial-aq 1 -temporal-aq $taq -aq-strength 7 `
    -b_ref_mode $bref -c:a copy $outputVids\$shortName-comp.mp4

    Write-host "Encoding $video completed in:"
    $time = select-string -Path $logs\$shortName.log -Pattern 'rtime=(.*)' | ForEach-Object{$_.Matches.Groups[1].Value} #ugly parsing to grab time to complete
    Write-host "$time seconds" -ForegroundColor Magenta #need that var, wanna post it in multiple places
    $time | Out-File -FilePath $logs\$shortName-time.txt -Append #want it in the log, append, cute for multile runs.
    write-host "`n"

    #remove-item $logs\$shortName.log #remove the full log. #uncomment if you want to clean the logs on completion.
}
#CountEm
Write-Host "videos attempted:" $videos.Count
pause #hit em up with a nice pause, so they know its done and didnt crash :)