#push script location
$scriptPath = $MyInvocation.MyCommand.Path
$dir = Split-Path $scriptPath
Push-Location $dir

#loading functions
. .\helpers\commonFunctions.ps1
. .\helpers\Verifier.ps1

### USER SETTINGS

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
psPause
write-host "`r"

#grab the items in the input folder
$videos = Get-ChildItem -Path $inputVids -Recurse

if ($videos.count -eq 0) {
    write-host "There are no files in the input folder. Exiting!" -ForegroundColor Red
    write-host "Input folder: $rootLocation\$inputVids" -ForegroundColor Yellow
    psPause
    exit
}

write-host "`n Number of videos:" $videos.count -ForegroundColor Yellow
Write-host "overwriting output files: $ow"
write-host "Ready to go? If not, exit or hit ctrl+c"
Pause
write-host "`r"

#counters
$fail = 0
$ok = 0
$skip = 0

#totalTime
$totalStart = get-date

foreach ($video in $videos) {

    Set-FileVars($video) #full=wPath, base=noExt, ext=.ext
    $i = 0
    $fullOut = "$outputVids\$baseName-track$i$ext"
    $skipVid = $False
    $startTime = get-date

    $probeData = ffprobe -hide_banner -loglevel quiet $fullName -show_streams | select-string -pattern 'codec_type=audio'
    $numAudioStreams = $probeData.Length
    write-host "`r --- $name, track(s): $numAudioStreams ---"
   
    if ((test-path $fullOut) -And ($ow -eq "n")) {
        $skip++
        $skipVid = $True
        write-host "$name already exists, skipping" -ForegroundColor Yellow
        write-host "`r"
    }

    if (!($skipVid)) {
        Start-Timer $name

        
        
        while ($i -ne $numAudioStreams) {
            write-host "processing track $i"
            ffmpeg $hb -$ow -loglevel $ll -i $fullName -map 0:a:$i -c:a copy -vn `
            $outputVids\$baseName-track$i$ext
            $i++
        }

        if (!$?) {
            $fail++
        } else {
            $ok++
        }
        Stop-Timer $name $startTime
        write-host "`r"
    }

    $fg = "green"
    if ($skip -gt 0) {
        set-variable -name fg -value "yellow"
    }
    if ($fail -gt 0) {
        set-variable -name fg -value "red"
    }
}
    
    $totalTime = new-timespan -start $totalStart -End (get-date)
    
    write-host "`n ---- Summary ----"
    write-host "Total completion time: $totalTime" -foregroundcolor Magenta
    Write-Host "Success: $ok | Skip: $skip | Fail: $fail" -ForegroundColor $fg
    
Pop-Location #pop location twice to return you to
Pop-Location #the working dir it was ran from
psPause
exit 0