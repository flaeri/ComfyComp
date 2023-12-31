# User configurable with prompt
$maxSizeInput = Read-Host -Prompt "Enter max file size in kilobytes (e.g., 8000 for 8 MB)"
$audioBrInput = Read-Host -Prompt "Enter audio bitrate in kbit (e.g., 128 for 128 kbps)"

# Remove spaces and convert to integer
$maxSize = [int]($maxSizeInput -replace '\s', '')
$audioBr = [int]($audioBrInput -replace '\s', '')

# Rest of your script
$video = Read-Host -Prompt "`nPlease drag&drop a video" # Drag video in
$video = Get-ChildItem -Path ($video -replace '"', "") # Input is a string, fix it
Clear-Host

# Calc
# 5% overhead safety 
$safeSize = $maxSize * 0.95

# Get duration of file
$durationSec = ffprobe -v error -show_entries format=duration -of default=noprint_wrappers=1:nokey=1 "$video"
$durationSecClamp = [math]::Round($durationSec)

$vidBr = $safeSize * 8 / $durationSec # size in MB * 8 = bits, divided by duration. x 1000 for kbps
$vidBr = [math]::Round($vidBr) # int please
$vidBr = $vidBr - $audioBr # account for audio bitrate

# Format video bitrate with space as thousand delimiter
$culture = [System.Globalization.CultureInfo]::InvariantCulture.Clone()
$culture.NumberFormat.NumberGroupSeparator = " "
$vidBrFormatted = "{0:N0}" -f $vidBr
$vidBrFormatted = $vidBrFormatted -replace ",", " " # Replace comma with space if necessary

Write-Host "Duration: $durationSecClamp sec" -ForegroundColor Yellow
Write-Host "Video Bitrate (kbps): $vidBrFormatted" -ForegroundColor Yellow
Write-Host "Audio Bitrate (kbps): $audioBr" -ForegroundColor Yellow
pause