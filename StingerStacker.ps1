Function Get-FileName($initialDirectory) {
    [System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms") | Out-Null
    $OpenFileDialog = New-Object System.Windows.Forms.OpenFileDialog
    $OpenFileDialog.initialDirectory = $initialDirectory
    $OpenFileDialog.ShowDialog() | Out-Null
    $OpenFileDialog.FileName
}


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
$inputExt = [IO.Path]::GetExtension($inputStinger)

write-host "`n"
Write-Host "Working on it, promise, please be patient" -ForegroundColor Yellow

if ($inputExt -eq ".webm") {
    write-host "Guessing this is a vp9 webm, attempting" -ForegroundColor Yellow
    ffmpeg -loglevel 25 -c:v libvpx-vp9 -i "$inputStinger" -i "$inputMatte" `
    -filter_complex "hstack,format=yuva420p" -c:v libvpx-vp9 -crf 31 -b:v 0 -cpu-used 5 `
    -pix_fmt yuva420p $shortName-stacked.webm
} else {
    Write-Host "not a webm, trying auto" -ForegroundColor Yellow
    ffmpeg -loglevel 25 -i "$inputStinger" -i "$inputMatte" `
    -filter_complex "hstack" -c:v libvpx-vp9 -crf 31 -b:v 0 -cpu-used 5 `
    -pix_fmt yuva420p $shortName-stacked.webm
}

write-host "`n"
Write-Host "done! Please test $pwd\$shortName-stacked.webm" -ForegroundColor Green
pause