. .\helpers\ffUpdateCheck.ps1

$FlaeriFfmpegPath = "C:\ffmpeg"  # Only used if ffmpeg is not found in the users path.

# Checking for ffmpeg in system's PATH
$ffPath = get-command ffmpeg -erroraction 'silentlycontinue'

if ($null -ne $ffPath) {
    # Check versions
    CheckFfmpegVersions
} else {
    # FFmpeg is not in system's PATH, so check in C:\ffmpeg\ or offer to download
    if (Test-Path -Path "$FlaeriFfmpegPath\ffmpeg.exe") {
        $ENV:PATH = "$FlaeriFfmpegPath;$ENV:PATH"
        CheckFfmpegVersions
    } else {
        OfferToUpdate
    }
}