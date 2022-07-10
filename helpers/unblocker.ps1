write-host "`n"
write-host "This will allow the currently logged on user to run PowerShell scripts that are signed or unblocked, ok?" -ForegroundColor Yellow
pause
Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned

write-host "`n"
write-host "We will unblock all the powershell files in this folder, and its subfolders, ok?" -ForegroundColor Yellow
write-host "$PWD"
pause

get-childitem -Path "$pwd\*.ps1" -Recurse | Unblock-File
write-host "done!" -ForegroundColor Green
pause