#loading functions
. .\helpers\commonFunctions.ps1

# Try reading config
$configPath = ".\config.json"

#Setup tests
$qProceed = "Please confirm the files chosen. Yes to proceed, No to quit"
$yesNo = "&Yes", "&No"

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

#$rootLocation = "C:\temp\ComfyComp" #root directory, all folders will be under this. Make sure you modify this to match where you extracted the contents.
$inputVids = "01 Input"     #
$outputVids = "02 Output"   # Feel free to name them whatever you want, but they need to exist. This is the default names of the folders provided.
$logs = "03 Logs"           #
$folders = $rootLocation, $inputVids, $outputVids, $logs
$ll = 24                    #loglevel, set 32 if you want normal output. This (24) will only show warnings.
$ow = "n"                   #overwrite files in output dir. Switch to "y" (yes), if you would like.
$suffix = "comp"            #name that is used as a suffix for files in the output folder. Easier to tell them apart, and lower risk of overwriting.

#
### Stop editing stuff now, unless you are every confident in your changes :)
#
#Cute banner
Get-Content .\banner.txt
write-host "`n"

# tagline, and shilling
write-host "https://blog.otterbro.com" -ForegroundColor Magenta -BackgroundColor black
write-host "Combine files, output ProRes422" -ForegroundColor Magenta -BackgroundColor black
write-host "`n"

# Testing if ffmpeg in path
Write-Host "Running ComfyChecker" -ForegroundColor Yellow
Invoke-Expression .\helpers\ComfyChecker.ps1
if ($LASTEXITCODE -eq 1) {
    Write-Host "ComfyChecker failed, aborted, or was exited" -ForegroundColor Red
    pause
    exit
}
Write-Host "Done checking!" -ForegroundColor Green

Push-Location -path $rootLocation #Dont edit edit this. Edit Above.

#grab the items in the input folder
Remove-Item videos.txt #make sure a temp file from previous sessions is not left, somehow.

foreach ($i in Get-ChildItem .\$inputVids) {
    "file '$inputVids\$i'" | Out-File -Encoding oem -append -FilePath videos.txt
}

write-host "`n"
Write-Host "Found the following files:" -ForegroundColor Yellow
Get-Content .\videos.txt

$start = $Host.UI.PromptForChoice("Start?", $qProceed, $yesNo, 0)
            if ($start -eq 1) {
                remove-item videos.txt
                exit}

write-host "`n"
Write-Host "Run initiated, please be patient." -ForegroundColor Yellow
ffmpeg -$ow -benchmark -loglevel $ll -f concat -safe 0 -i .\videos.txt -c copy $outputVids\output.mp4

write-host "`n"
Write-Host "Done! Cleaning up temp file. Hit a key to exit" -ForegroundColor Yellow
Remove-Item videos.txt

pause