$global:ffmpegOutdated = $false
$yesNo = "&Yes", "&No"

function GetFfmpegVersion ($ffmpegPath = "ffmpeg") {
    # Returns the version of FFmpeg at the given path or throws an exception if the version can't be parsed
    $ffmpegOutput = (& $ffmpegPath -version 2>&1 | Select-Object -First 1)

    # Handle the format with date (e.g., 2023-07-19)
    if ($ffmpegOutput -match "ffmpeg version (\d{4}-\d{2}-\d{2})") {
        return Get-Date $matches[1]
    } 
    # Handle version with 'n' prefix (e.g., n5.1.3 or n6.0)
    elseif ($ffmpegOutput -match "ffmpeg version n(\d+\.\d+(\.\d+)?)") {
        return [Version]$matches[1]
    }
    # Handle standard version format (e.g., 5.1.2 or 6.0)
    elseif ($ffmpegOutput -match "ffmpeg version (\d+\.\d+(\.\d+)?)") {
        return [Version]$matches[1]
    }
    else {
        throw "Failed to parse ffmpeg version from output: $ffmpegOutput"
    }
}

function CheckFfmpegVersionAtPath ($path) {
    $minRequiredDate = Get-Date "2023-06-30" #2023-06-30

    # Check if the file exists for non-default paths
    if ($path -ne "ffmpeg" -and -not (Test-Path $path)) {
        Write-Host "No FFmpeg found at ${path}." -ForegroundColor Yellow
        return $true
    }

    try {
        $version = GetFfmpegVersion $path
        write-host "Testing $path"
        if ($version -is [DateTime]) {
            write-host "Version is DateTime: $($version.ToString('yyyy-MM-dd'))"
            # Handle date versions
            if ($version -lt $minRequiredDate) {
                write-host "Out of date" -ForegroundColor Yellow
                return $true
            }
        } elseif ($version -is [Version]) {
            write-host "Version is Version: $version"
            # Handle numeric versions
            if ($version -le [Version]"6.0") {
                write-host "Out of date" -ForegroundColor Yellow
                return $true
            }
        }
    } catch {
        Write-Host "Error checking ffmpeg version at ${path}: $_" -ForegroundColor Red
        return $true
    }

    return $false
}

function CheckFfmpegVersions {
    # Check default ffmpeg in PATH
    $pathOutdated = CheckFfmpegVersionAtPath "ffmpeg"

    # If ffmpeg in PATH is outdated, check FFmpeg version in C:\ffmpeg
    if ($pathOutdated) {
        $flaeriOutdated = CheckFfmpegVersionAtPath "C:\ffmpeg\ffmpeg.exe"
        if (!$flaeriOutdated) {
            # The version in C:\ffmpeg is up-to-date, so update the PATH for this session
            $ENV:PATH = "$FlaeriFfmpegPath;$ENV:PATH"
            Write-Host "Using the up-to-date ffmpeg version from $FlaeriFfmpegPath" -ForegroundColor Green
            return
        }
    } else {
        $global:ffmpegOutdated = $false
        Write-Host "You have a compatible version of ffmpeg in your PATH." -ForegroundColor Green
        return
    }

    $global:ffmpegOutdated = $true
    OfferToUpdate
}

function OfferToUpdate {
    Write-Host "Your ffmpeg version is outdated." -ForegroundColor Yellow
    $questionUpdate = "Would you like to update ffmpeg?"
    $updateChoice = $Host.UI.PromptForChoice("Update?", $questionUpdate, $yesNo, 0)
    if ($updateChoice -eq 0) {
        # Invoke the ffmpegAutoInstaller script to download and install the updated version
        Invoke-Expression .\helpers\ffmpegAutoInstaller.ps1
    } else {
        Write-Host "You chose not to update. Some features might not work as expected." -ForegroundColor Yellow
    }
}
