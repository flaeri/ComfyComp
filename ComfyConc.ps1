#push script location
$scriptPath = $MyInvocation.MyCommand.Path
$dir = Split-Path $scriptPath
Push-Location $dir

#loading functions
. .\helpers\commonFunctions.ps1
. .\helpers\Verifier.ps1

#Setup tests
$qProceed = "Please confirm the files chosen. Yes to proceed, No to quit"
$yesNo = "&Yes", "&No"

# Settings
$ll = 24            #loglevel, set 32 if you want normal output. This (24) will only show warnings.
$ow = "n"           #overwrite files in output dir. Switch to "y" (yes), if you would like.
$suffix = "conc"    #name that is used as a suffix for files in the output folder. Easier to tell them apart, and lower risk of overwriting.

#
### Stop editing stuff now, unless you are every confident in your changes :)
#
write-host "Concatenate files. Please ensure they are all the same (settings, container (extension), or output may fail" -ForegroundColor Magenta -BackgroundColor black
write-host "`r"

Push-Location -path $rootLocation #Don't edit edit this. Delete your config file, or modify it

#grab the items in the input folder
if (test-path videos.txt) {
    Remove-Item videos.txt
}

foreach ($i in Get-ChildItem .\$inputVids) {
    "file '$inputVids\$i'" | Out-File -Encoding oem -append -FilePath videos.txt
    $ext = $i.Extension #useful for naming
}

write-host "`r"
Write-Host "Found the following files:" -ForegroundColor Yellow
Get-Content .\videos.txt

$start = $Host.UI.PromptForChoice("Start?", $qProceed, $yesNo, 0)
            if ($start -eq 1) {
                remove-item videos.txt
                exit}
$time = get-date -Format dd-MM-yy_HH-MM-ss

write-host "`r"
Write-Host "Run initiated, please be patient." -ForegroundColor Yellow
ffmpeg -$ow -benchmark -loglevel $ll -f concat -safe 0 -i .\videos.txt -c copy $outputVids\$time-$suffix$ext

write-host "`r"
Write-Host "Done! Cleaning up temp file. Hit a key to exit" -ForegroundColor Yellow
Remove-Item videos.txt

Pop-Location #pop location twice to return you to
Pop-Location #the working dir it was ran from
psPause
exit 0