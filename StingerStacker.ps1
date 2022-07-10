#push script location
$scriptPath = $MyInvocation.MyCommand.Path
$dir = Split-Path $scriptPath
Push-Location $dir

#loading functions
. .\helpers\commonFunctions.ps1
. .\helpers\Verifier.ps1

write-host "Variable Input Stinger Stacker" -ForegroundColor Magenta -BackgroundColor black
write-host "`n"

write-host "`n"
Write-Host "You will be prompted to select two files. First select the STINGER, and then pick the MATTE" -ForegroundColor Yellow
Pause

$inputStinger = Get-FileName
if ($inputStinger -eq "") {
    Write-Host "you didnt select anything, exiting" -ForegroundColor Red
    Pause
    exit
}
$inputMatte = Get-FileName
if ($inputStinger -eq "") {
    Write-Host "you didnt select anything, exiting" -ForegroundColor Red
    Pause
    exit
}

Push-Location -path $rootLocation #Dont edit edit this, edit the config.json or delete it

$Name = Get-ChildItem $inputStinger

$shortName = $Name.BaseName
$inputCodec = ffprobe -v error -select_streams v:0 -show_entries stream=codec_name -of default=noprint_wrappers=1:nokey=1 $inputStinger

write-host "`n"
Write-Host "Working on it, promise, please be patient" -ForegroundColor Yellow

if ($inputCodec -eq "vp9") {
    write-host "vp9, ensuring correct decoder" -ForegroundColor Yellow
    ffmpeg -loglevel 25 -c:v libvpx-vp9 -i "$inputStinger" -i "$inputMatte" `
    -filter_complex "hstack,format=yuva420p" -c:v libvpx-vp9 -crf 31 -b:v 0 -cpu-used 5 `
    -pix_fmt yuva420p $outputVids\$shortName-stacked.webm
} elseif ($inputCodec -eq "vp8") {
    write-host "vp8, ensuring correct decoder" -ForegroundColor Yellow
    ffmpeg -loglevel 25 -c:v libvpx -i "$inputStinger" -i "$inputMatte" `
    -filter_complex "hstack,format=yuva420p" -c:v libvpx-vp9 -crf 31 -b:v 0 -cpu-used 5 `
    -pix_fmt yuva420p $outputVids\$shortName-stacked.webm
} else {
    Write-Host "not a webm, trying auto" -ForegroundColor Yellow
    ffmpeg -loglevel 25 -i "$inputStinger" -i "$inputMatte" `
    -filter_complex "hstack" -c:v libvpx-vp9 -crf 31 -b:v 0 -cpu-used 5 `
    -pix_fmt yuva420p $outputVids\$shortName-stacked.webm
}

write-host "`n"
Write-Host "done! Please test $outputVids\$shortName-stacked.webm" -ForegroundColor Green
pause