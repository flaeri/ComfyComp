#
### User adjustable stuff.
#
## PICK WHERE YOU WANT THE ROOT TO BE
#
$rootLocation = "C:\temp\ComfyComp" #root directory, all folders will be under this. Make sure you modify this to match where you extracted the contents.
$inputVids = "01 Input"     #
$outputVids = "02 Output"   # Feel free to name them whatever you want, but they need to exist. This is the default names of the folders provided.
$logs = "03 Logs"           #
$folders = $rootLocation, $inputVids, $outputVids, $logs
$ll = 24                    #loglevel, set 32 if you want normal output. This (24) will only show warnings.
$suffix = "comp"            #name that is used as a suffix for files in the output folder. Easier to tell them apart, and lower risk of overwriting.
$vmafModelPath = "E\\:/ffmpeg/share/model/vmaf_v0.6.1.json"
$vmafPool = "harmonic_mean"
$vmafThreads = 10

### Stop editing stuff now, unless you are every confident in your changes :)

# vars the script needs. Please dont alter.
$yesNo = "&Yes", "&No"
$FlaeriFfmpegPath = "C:\ffmpeg"   #Only used if ffmpeg is not found in the users path.

Push-Location -path $rootLocation #Dont edit edit this. Edit Above.

#Cute banner
Get-Content .\banner.txt
write-host "`n"

# tagline, and shilling
write-host "https://blog.otterbro.com" -ForegroundColor Magenta -BackgroundColor black
write-host "VMAF processor" -ForegroundColor Magenta -BackgroundColor black
write-host "`n"

# Testing if ffmpeg in path
$ffPath = get-command ffmpeg -erroraction 'silentlycontinue'
    if ($null -eq $ffPath) {
        if (Test-Path -Path "$FlaeriFfmpegPath\ffmpeg.exe") {
            $ENV:PATH="$ENV:PATH;$FlaeriFfmpegPath"
            if (Get-Command ffmpeg) {
                Write-Host "FFMPEG found!" -ForegroundColor green
            }
        } else {
            Write-Host "ffmpeg was not found in your path, and you've never ran the autoinstall script" -ForegroundColor Red
            $questionDownload = "Would you like to auto download and have this script call that instead? (Your permanent path will NOT be altered)"
            $download = $Host.UI.PromptForChoice($questionDownload, $questionDownload, $yesNo, 0)
            if ($download -eq 0) {
                Invoke-Expression .\ffmpegAutoInstaller.ps1 #this fires the powershell script to download ffmpeg.
                exit
            } else {
                write-host "`n"
                write-Host "You chose not to auto download. You need to download ffmpeg: https://www.gyan.dev/ffmpeg/builds/" -ForegroundColor red
                write-host "After you've downloaded, you need to extract the contents, and add the folder containing ffmpeg.exe to your envoirenment/path" -ForegroundColor red
                write-host "`n"
                write-host "The script will now exit. Please run it again if you change your mind, or you've installed ffmpeg correctly " -ForegroundColor yellow
            pause
            exit
        }
    }
}

#print state of current parameters
Write-Host "Model path = $vmafModelPath"
Write-Host "VAMF pool = $vmafPool"
Write-Host "Threads = $vmafThreads"
write-host "`n"

#where you at
write-host "Working directory: $PWD"
#testing folders
foreach ($folder in $folders) {
    if (Test-Path -Path $folder) {
    Write-Host "$folder confirmed!" -ForegroundColor Green
}
    else {
        write-host "$folder does not exist. Please create it or adjust the paths and folder names at the start of the script, then rerun the script. The script will now exit" -ForegroundColor Red
        pause
        exit
    }
}

Write-host "overwriting output files: $ow"
write-host "`n"

Write-Output "Hit Enter to start, or ctrl+c / exit the window to stop"
pause
write-host "`n"

#grab the items in the input folder
$videos = Get-ChildItem -Path $inputVids -Recurse

#loop them all.
foreach ($video in $videos) {
    $shortName = $video.BaseName #useful for naming.
    $env:FFREPORT = "file=$logs\\$shortName.log:level=32" #ffmpeg is hardcoded to look for an envoirenment variable, cus it needs to be known before we fire.
    Write-host "Start Evaluating: $video"
    write-host "`n"

    #multi line drifting
    ffmpeg -benchmark -loglevel $ll -hwaccel auto -i $outputVids\$shortName-$suffix.mp4 -hwaccel auto -i $inputVids\$video `
    -lavfi libvmaf=model_path=$vmafModelPath':'pool=$vmafPool':'n_threads=$vmafThreads':'log_fmt=xml:log_path=$shortName.vmaf.txt `
    -f null -

    Write-host "Evaluation of $video completed in:"
    $time = select-string -Path $logs\$shortName.log -Pattern 'rtime=(.*)' | ForEach-Object{$_.Matches.Groups[1].Value} #ugly parsing to grab time to complete
    Write-host "$time seconds" -ForegroundColor Magenta #need that var, wanna post it in multiple places
    $time | Out-File -FilePath $logs\$shortName-time.txt -Append #want it in the log, append, cute for multile runs.

    #vmaf score
    $vmafScore = select-string -Path $logs\$shortName.log -Pattern 'VMAF score:(.*)' | ForEach-Object{$_.Matches.Groups[0].Value}
    Write-host "$vmafScore" -ForegroundColor Magenta #need that var, wanna post it in multiple places
    $vmafScore | Out-File -FilePath $logs\$shortName-vmafInfo.txt -Append #want it in the log, append, cute for multile runs.

    #vmaf score detailed
    $vmafScoreFull = select-string -Path "$shortName.vmaf.txt" -Pattern '<metric name="vmaf"(.*)' | ForEach-Object{$_.Matches.Groups[0].Value}
    Write-host "$vmafScoreFull" -ForegroundColor Magenta #need that var, wanna post it in multiple places
    $vmafScoreFull | Out-File -FilePath $logs\$shortName-vmafInfo.txt -Append #want it in the log, append, cute for multile runs.

    #fps
    $fps = select-string -Path "$shortName.vmaf.txt" -Pattern 'fps="(.*)' | ForEach-Object{$_.Matches.Groups[0].Value}
    $fps = $fps -replace "[^0-9.]" 
    Write-host "FPS: $fps" -ForegroundColor Magenta #need that var, wanna post it in multiple places
    $fps | Out-File -FilePath $logs\$shortName-vmafInfo.txt -Append #want it in the log, append, cute for multile runs.
    write-host "`n"

    #remove-item $logs\$shortName.log #remove the full log. #uncomment if you want to clean the logs on completion.
}
#CountEm
Write-Host "videos attempted:" $videos.Count
pause #hit em up with a nice pause, so they know its done and didnt crash :)