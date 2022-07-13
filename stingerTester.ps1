#push script location
$scriptPath = $MyInvocation.MyCommand.Path
$dir = Split-Path $scriptPath
Push-Location $dir

#loading functions
. .\helpers\commonFunctions.ps1
. .\helpers\Verifier.ps1

write-host "`r"
write-host "Stinger Tester. Checks for valid alpha channel in video" -ForegroundColor Magenta -BackgroundColor black

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

#determine codec
$inputCodec = ffprobe -v error -select_streams v:0 -show_entries stream=codec_name -of default=noprint_wrappers=1:nokey=1 $inputStinger

if ($inputCodec -eq "vp9") {
    $vidInfo = $( $output = & ffmpeg -c:v libvpx-vp9 -i "$inputStinger") 2>&1
    if ($vidInfo | Select-String yuva420p) {
        write-host "VP9 codec, alpha channel OK" -ForegroundColor Green
    } else {
        write-host "VP9 codec, but NO alpha channel" -ForegroundColor Red
        Pause
        Exit
    }
} 

if ($inputCodec -eq "vp8") {
    $vidInfo = $( $output = & ffmpeg -c:v libvpx -i "$inputStinger") 2>&1
    if ($vidInfo | Select-String yuva420p) {
        write-host "VP8 codec, alpha channel OK" -ForegroundColor Green
    } else {
        write-host "VP8 codec, but NO alpha channel" -ForegroundColor Red
        Pause
        Exit
    }
}

#determine pix_fmt
$pix_fmt = ffprobe -v error -select_streams v:0 -show_entries stream=pix_fmt: -of default=noprint_wrappers=1:nokey=1 $inputStinger

#valid pixel formats
$formatlist = @('yuva420p', 'argb', 'bgra', 'gbrap12le')

write-host "`r"

if ($inputCodec -ne 'vp8' -and $inputCodec -ne 'vp9') {
    if ($formatlist -contains $pix_fmt) {
        write-host "------------"
        write-host "Codec: $inputCodec"
        write-host "Pixel format: $pix_fmt"
        write-host "Alpha channel found!" -ForegroundColor Green
    } else {
        write-host "------------"
        write-host "Codec: $inputCodec"
        write-host "Pixel format: $pix_fmt"
        write-host "NO alpha channel found!" -ForegroundColor Red
        Pause
        exit
    }
}

write-host "Reminder, even if an alpha channel was found in the video, that does not guarantee it is in use." -ForegroundColor yellow
write-host "`r"
pause