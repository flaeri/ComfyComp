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
$in = "C:\temp\comfyComp\01 Input"      #location of files you want to encoder
$out = "C:\temp\comfyComp\02 Output"   #location of where you want the encoded files to be
$ext = "mp4"                #extension/container

#encoder settings
$preset = "veryfast"
$crf = 14
$pixfmt = "yuv444p"

#etc
$ll = 24            #loglevel, set 32 if you want normal output. This (24) will only show warnings.
$ow = "n"           #overwrite files in output dir. Switch to "y" (yes), if you would like.
$suffix = "comp"    #name used as suffix for files in output folder. Easier to tell them apart, and lower risk of overwriting.

# --- END of user configurable ---

#get list of files
$videos = Get-ChildItem -Path $in -Recurse

write-host "`n Number of videos:" $videos.count -ForegroundColor Yellow
Write-host "Overwrite output files: $ow" -ForegroundColor Yellow
write-host "`n Ready to go? If not, exit or hit ctrl+c"
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
    $fullOut = "$out\$baseName-$suffix$ext"
    $skipVid = $False
   
    if ((test-path $fullOut) -And ($ow -eq "n")) {
        $skip++
        $skipVid = $True
        write-host "$name already exists, skipping" -ForegroundColor Yellow
        write-host "`r"
    }

    if (!($skipVid)) {
        Start-Timer $name

        # FFMPEG goes here, leave $stuff, feel free to modify, remove others
        ffmpeg -$ow -loglevel $ll -i $fullName -c:v libx264 -c:a copy -preset $preset -crf $crf -pix_fmt $pixfmt `
        -src_range 0 -dst_range 0 -movflags faststart `
        $out\$baseName-$suffix$ext

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