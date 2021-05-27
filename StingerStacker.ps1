#Cute banner
Get-Content .\banner.txt
write-host "`n"

# tagline, and shilling
write-host "https://blog.otterbro.com" -ForegroundColor Magenta -BackgroundColor black
write-host "Variable Input Stinger Stacker" -ForegroundColor Magenta -BackgroundColor black
write-host "`n"

# TOD: move the FFMPEG checker script to a seperate script.

$inputStinger = $(Read-Host -Prompt 'Please drag your STINGER file into this window now, and hit Enter')
$inputMatte = $(Read-Host -Prompt 'Please drag your MATTE file into this window now, and hit Enter')

#sanetize input
$inputStinger = $inputStinger -replace '"'
$inputMatte = $inputMatte -replace '"'

# Get-Content $(Read-host -Prompt "Enter Path")

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