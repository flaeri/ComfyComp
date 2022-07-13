#push script location
$scriptPath = $MyInvocation.MyCommand.Path
$dir = Split-Path $scriptPath
Push-Location $dir

#loading functions
. .\helpers\commonFunctions.ps1
. .\helpers\Verifier.ps1

#settings
$ll = 24            #loglevel, set 32 if you want normal output. This (24) will only show warnings.
$ow = "n"           #overwrite files in output dir. Switch to "y" (yes), if you would like.
$suffix = "vp9fix"  #name that is used as a suffix for files in the output folder. Easier to tell them apart, and lower risk of overwriting.

#
### Stop editing stuff now, unless you are every confident in your changes :)
#

write-host "Stinger fixer. Re-encodes potentially wonky alpha videos" -ForegroundColor Magenta -BackgroundColor black
write-host "`r"

Push-Location -path $rootLocation #Don't edit edit this, edit the config.json or delete it

write-host "`r"
Write-Host "Please select the stinger file" -ForegroundColor Yellow
Pause

$inputStinger = Get-FileName
if ($inputStinger -eq "") {
    Write-Host "you didn't select anything, exiting" -ForegroundColor Red
    Pause
    exit
}

$Name = Get-ChildItem $inputStinger
$shortName = $Name.BaseName
$inputCodec = ffprobe -v error -select_streams v:0 -show_entries stream=codec_name -of default=noprint_wrappers=1:nokey=1 $inputStinger

write-host "Processing, please be patient" -ForegroundColor Yellow

$startTime = get-date

if ($inputCodec -eq "vp9") {
    write-host "vp9, ensuring correct decoder" -ForegroundColor Yellow
    ffmpeg -$ow -loglevel $ll -c:v libvpx-vp9 -i "$inputStinger" `
    -c:v libvpx-vp9 -crf 31 -b:v 0 -b:a 192k -cpu-used 5 `
    -pix_fmt yuva420p $outputVids\$shortName-$suffix.webm
} elseif ($inputCodec -eq "vp8") {
    write-host "vp8, ensuring correct decoder" -ForegroundColor Yellow
    ffmpeg -$ow -loglevel $ll -c:v libvpx -i "$inputStinger" `
    -c:v libvpx-vp9 -crf 31 -b:v 0 -b:a 192k -cpu-used 5 `
    -pix_fmt yuva420p $outputVids\$shortName-$suffix.webm
} else {
    Write-Host "not a webm, trying auto" -ForegroundColor Yellow
    ffmpeg -$ow -loglevel $ll -i "$inputStinger" `
    -c:v libvpx-vp9 -crf 31 -b:v 0 -b:a 192k -cpu-used 5 `
    -pix_fmt yuva420p $outputVids\$shortName-$suffix.webm
}

$endTime = get-date
$time = new-timespan -start $startTime -End $endTime

write-host "`r"
Write-host "Done! Completed in: $time" -ForegroundColor Magenta
Write-Host "Please test $outputVids\$shortName-$suffix.webm" -ForegroundColor Green

Pop-Location #pop location twice to return you to
Pop-Location #the working dir it was ran from
pause #hit em up with a nice pause, so they know its done and didn't crash :)
exit 0