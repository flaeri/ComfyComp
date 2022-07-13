#push script location
$scriptPath = $MyInvocation.MyCommand.Path
$dir = Split-Path $scriptPath
Push-Location $dir

#loading functions
. .\helpers\commonFunctions.ps1
. .\helpers\Verifier.ps1

# Settings
$ll = "24"      #loglevel, set 32 if you want normal output. This (24) will only show warnings.
$ow = "n"       #overwrite files in output dir. Switch to "y" (yes), if you would like.

#
### Stop editing stuff now, unless you are every confident in your changes :)
#

Push-Location -path $rootLocation #Don't edit edit this, edit the config.json or delete it

write-host "`r"
Write-Output "This script will copy individual audio tracks to separate files"
Write-Output "Hit Enter to start, or ctrl+c / exit the window to stop"
pause
write-host "`r"

#grab the items in the input folder
$videos = Get-ChildItem -Path $inputVids -Recurse

#loop them all.
foreach ($video in $videos) {
    $shortName = $video.BaseName #useful for naming.
    $ext = $video.Extension #useful for naming
    Write-host "--- Start ---"
    Write-host "Start processing: $video"
    write-host "`r"

    $probeData = ffprobe -hide_banner -loglevel quiet $inputVids\$video -show_streams | select-string -pattern 'codec_type=audio'
    $numAudioStreams = $probeData.Length
    write-host "$video has $numAudioStreams track(s)"

    $i = 0
    $startTime = get-date
    while ($i -ne $numAudioStreams) {
        write-host "processing track $i"
        ffmpeg $hb -$ow -loglevel $ll -i $inputVids\$video -map 0:a:$i -c:a copy -vn `
        $outputVids\$shortName-track$i$ext
        $i++
    }

    $endTime = get-date
    $time = new-timespan -start $startTime -End $endTime

    write-host "`r"
    Write-host "$video completed in: $time" -ForegroundColor Magenta
    Write-host "--- End ---"
}

#CountEm
Write-Host "Done! Files attempted:" $videos.Count
Pop-Location #pop location twice to return you to
Pop-Location #the working dir it was ran from
pause #hit em up with a nice pause, so they know its done and didn't crash :)
exit 0