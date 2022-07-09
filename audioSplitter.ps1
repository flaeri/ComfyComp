#loading functions
. .\helpers\commonFunctions.ps1

$rootLocation = "C:\temp\ComfyComp" #root directory, all folders will be under this. Make sure you modify this to match where you extracted the contents.
$inputVids = "01 Input"     #
$outputVids = "02 Output"   # Feel free to name them whatever you want, but they need to exist. This is the default names of the folders provided.
$logs = "03 Logs"           #
$folders = $rootLocation, $inputVids, $outputVids, $logs
$ll = "24"                    #loglevel, set 32 if you want normal output. This (24) will only show warnings.
$ow = "y"                   #overwrite files in output dir. Switch to "y" (yes), if you would like.
$hb = "-hide_banner"

#
### Stop editing stuff now, unless you are every confident in your changes :)
#

# Testing if ffmpeg in path
Write-Host "Running ComfyChecker" -ForegroundColor Yellow
Invoke-Expression .\helpers\ComfyChecker.ps1
if ($LASTEXITCODE -eq 1) {
    Write-Host "ComfyChecker failed, aborted, or was exited" -ForegroundColor Red
    pause
    exit
}
Write-Host "Done checking!" -ForegroundColor Green

Push-Location -path $rootLocation #Dont edit edit this. Edit Above.

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

write-host "`n"
Write-Output "This script will copy individual audio tracks to seperate files"
Write-Output "Hit Enter to start, or ctrl+c / exit the window to stop"
pause
write-host "`n"

#grab the items in the input folder
$videos = Get-ChildItem -Path $inputVids -Recurse

#loop them all.
foreach ($video in $videos) {
    $shortName = $video.BaseName #useful for naming.
    $ext = $video.Extension #useful for naming
    Write-host "Start processing: $video"
    write-host "`n"

    $probeData = ffprobe $hb -loglevel quiet $inputVids\$video -show_streams | select-string -pattern 'codec_type=audio'
    $numAudioStreams = $probeData.Length
    write-host "$video has $numAudioStreams tracks"

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

    write-host "`n"
    Write-host "Encoding $video completed in:"
    Write-host $time -ForegroundColor Magenta
    write-host "`n"
}

#CountEm
Write-Host "Done! Files attempted:" $videos.Count
pause #hit em up with a nice pause, so they know its done and didnt crash :)