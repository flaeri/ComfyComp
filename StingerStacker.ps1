#loading functions
. .\helpers\commonFunctions.ps1

# Try reading config
$configPath = ".\config.json"

if (test-path $configPath) {
    $config = Read-Config $configPath
} else {
    write-host "Config NOT found!" -ForegroundColor Red
    write-host "Creating config, please select where you want your files `n"
    $rootLocation = get-folder

    Write-Config $configPath $rootLocation
    $config = Read-Config $configPath
}

#testing rootLocation is valid and exists
$rootLocation = $config.rootlocation
if (!(test-path $rootLocation)) {
    write-host "The location ($rootLocation) you've chosen seem to be invalid or missing." -ForegroundColor Red
    write-host "Please modify $configPath, or delete it to start over" -ForegroundColor Red
    pause
    exit
}

$inputVids = "01 Input"     #
$outputVids = "02 Output"   # Feel free to name them whatever you want, but they need to exist. This is the default names of the folders provided.
$logs = "03 Logs"           #

#Cute banner
Get-Content .\banner.txt
write-host "`n"

# tagline, and shilling
write-host "https://blog.otterbro.com" -ForegroundColor Magenta -BackgroundColor black
write-host "Variable Input Stinger Stacker" -ForegroundColor Magenta -BackgroundColor black
write-host "`n"

# Testing if ffmpeg in path
Write-Host "Running ComfyChecker" -ForegroundColor Yellow
Invoke-Expression .\helpers\ComfyChecker.ps1
if ($LASTEXITCODE -eq 1) {
    Write-Host "ComfyChecker failed, aborted, or was exited" -ForegroundColor Red
    exit
}
Write-Host "Done checking!" -ForegroundColor Green

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