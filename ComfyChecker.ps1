# checking for ffmpeg and potentially downloading and adding to path.

# vars the script needs. Please dont alter.
$yesNo = "&Yes", "&No"
$FlaeriFfmpegPath = "C:\ffmpeg"  #Only used if ffmpeg is not found in the users path.

#checking for ffmpeg
$ffPath = get-command ffmpeg -erroraction 'silentlycontinue'
    if ($null -eq $ffPath) {
        Write-Host "Did NOT find ffmpeg in path" -ForegroundColor Yellow
        if (Test-Path -Path "$FlaeriFfmpegPath\ffmpeg.exe") {
            Write-Host "Found ffmpeg in $FlaeriFfmpegPath, adding to path" -ForegroundColor Green
            $ENV:PATH="$ENV:PATH;$FlaeriFfmpegPath"
        } else {
            Write-Host "ffmpeg was not found in your path, and you've never ran the autoinstall script" -ForegroundColor Red
            $questionDownload = "Would you like to auto download and have this script call that instead? (Your permanent path will NOT be altered)"
            $download = $Host.UI.PromptForChoice("Download?", $questionDownload, $yesNo, 0)
            if ($download -eq 0) {
                Invoke-Expression .\ffmpegAutoInstaller.ps1 #this fires the powershell script to download ffmpeg.
                exit
            } else {
                write-host "`n"
                write-Host "You chose not to auto download. You need to download ffmpeg: https://www.gyan.dev/ffmpeg/builds/" -ForegroundColor red
                write-host "After you've downloaded, you need to extract the contents, and add the folder containing ffmpeg.exe to your environment/path" -ForegroundColor red
                write-host "`n"
                write-host "The script will now exit. Please run it again if you change your mind, or you've installed ffmpeg correctly " -ForegroundColor yellow
            pause
            exit 1
        }
    }
}