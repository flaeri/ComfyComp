. .\helpers\banner.ps1

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
while ($null -eq $rootlocation) {
    write-host "The location ($rootLocation) you've chosen seem to be invalid or missing." -ForegroundColor Red
    write-host "Please modify $configPath, or delete it to start over" -ForegroundColor Red
    $confirmation = Read-Host "Would you like to delete the file (y/n)?"
    if ($confirmation -eq 'y') {
        Remove-Item -Path ".\config.json"
        . .\helpers\Verifier.ps1
    }
    
    $config = Read-Config $configPath
    $rootLocation = $config.rootlocation
}


$inputVids = "01 Input"     #
$outputVids = "02 Output"   # Feel free to name them whatever you want, but they need to exist. This is the default names of the folders provided.
$logs = "03 Logs"           #
$folders = $rootLocation, $inputVids, $outputVids, $logs

. .\helpers\ffmpegInfo.ps1

Push-Location -Path $rootLocation
#where you at
write-host "`r"
write-host "Working directory: $PWD"
#testing folders
foreach ($folder in $folders) {
    if (Test-Path -Path $folder) {
    Write-Host "$folder confirmed!" -ForegroundColor Green
}
    else {
        write-host "$folder does not exist. Creating." -ForegroundColor Yellow
        New-Item -ItemType "directory" $folder
    }
}
Pop-Location

write-host "`r"
Write-Host "Done checking!" -ForegroundColor Green