#push script location
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

#testing for nvenc
ffmpeg -hide_banner -loglevel 0 -f lavfi -i smptebars=duration=1:size=1920x1080:rate=30 -c:v hevc_nvenc -t 0.1 -f null -
if (!$?) {
    write-host "Nvenc HEVC is NOT supported on this card, sorry!" -ForegroundColor Red
    write-host "The script will now exit" -ForegroundColor Yellow -BackgroundColor Black
    psPause
    exit
} else {
    write-host "Nvenc HEVC supported!" -ForegroundColor Green
}

#testing hevc b-frames
ffmpeg -hide_banner -loglevel 0 -f lavfi -i smptebars=duration=1:size=1920x1080:rate=30 -c:v hevc_nvenc -bf 2 -t 1 -f null -
if (!$?) {
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
Push-Location -path $rootLocation #Dont edit edit this, edit the config.json or delete it
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

#grab the items in the input folder
$videos = Get-ChildItem -Path $inputVids -Recurse

write-host "`n Number of videos:" $videos.count -ForegroundColor Yellow
write-host "Ready to go? If not, exit or hit ctrl+c"
Pause
write-host "`r"

#counters
$fail = 0
$ok = 0
$skip = 0

#totalTime
$totalStart = get-date

#loop them all.
foreach ($video in $videos) {

    Set-FileVars($video) #full=wPath, base=noExt,
    $fullOut = "$outputVids\$baseName-$suffix.mp4" #maybe change this
    $skipVid = $False

    if ((test-path $fullOut) -And ($ow -eq "n")) {
        $skip++
        $skipVid = $True
        write-host "$name already exists, skipping" -ForegroundColor Yellow
        write-host "`r"
    }

    if (!($skipVid)) {
        Start-Timer $name

        #multi line drifting
        ffmpeg -$ow -loglevel $ll -hwaccel auto -i $fullName -map 0 -c:v hevc_nvenc -refs $ref `
        -preset p7 -rc vbr -cq $cq -bf $bf -maxrate $mr -bufsize $mr -spatial-aq 1 -temporal-aq $taq -aq-strength 7 `
        -b_ref_mode $bref -c:a copy $outputVids\$baseName-$suffix.mp4 #change output

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