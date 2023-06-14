#push script location
$scriptPath = $MyInvocation.MyCommand.Path
$dir = Split-Path $scriptPath
Push-Location $dir

#loading functions
. .\helpers\commonFunctions.ps1
. .\helpers\Verifier.ps1

write-host "`r"
write-host "Information extractor. Checks for useful video information" -ForegroundColor Magenta -BackgroundColor black

Push-Location -path $rootLocation #Don't edit edit this, edit the config.json or delete it

write-host "`r"
Write-Host "Please select the video file" -ForegroundColor Yellow

$inputVideo = Get-FileName
if ($inputVideo -eq "") {
    Write-Host "you didn't select anything, exiting" -ForegroundColor Red
    Pause
    exit
}

write-host "`r"
write-host "Parsing file, please wait..." -ForegroundColor Yellow

#Probe video info. This returns a custom object
$videoInfo = Get-VideoStreamInfo -inputFile $inputVideo

# Add the first keyframe interval to the video information
$videoInfo | Add-Member -Type NoteProperty -Name GOP -Value $firstKeyframeInterval

if ($videoInfo.codec_name -eq "h264") {
    $tableProps = "codec_name", "profile", "level", 'MaxFPS(R)', "AvgFPS", 'keyint (sec)', "GOP Struct", "time_base", "DAR", "SAR", "refs", "BFrames", "pix_fmt", "color_range", "color_space", "color_transfer", "color_primaries"
} elseif ($videoInfo.codec_name -eq "hevc") {
    $tableProps = "codec_name", "profile", "level", 'MaxFPS(R)', "AvgFPS", 'keyint (sec)', "GOP Struct", "time_base", "DAR", "SAR", "BFrames", "pix_fmt", "color_range", "color_space", "color_transfer", "color_primaries"
} else {
    $tableProps = "codec_name", "profile", "level", 'MaxFPS(R)', "AvgFPS", 'keyint (sec)', "GOP Struct", "time_base", "DAR", "SAR", "pix_fmt", "color_range", "color_space", "color_transfer", "color_primaries"
}

#print table
write-host "`r"
write-host "Result for: $inputVideo" -ForegroundColor Yellow
$videoInfo | Format-Table -Property $tableProps

pause
Pop-Location #pop location back to the dir script was ran from
Pop-Location #pop location back to the dir script was ran from