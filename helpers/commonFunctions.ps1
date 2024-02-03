## codec maps
# av1
$ffmpegAv1LevelMap = @{
    0 = "2.0";
    1 = "2.1";
    2 = "2.2";
    3 = "2.3";
    4 = "3.0";
    5 = "3.1";
    6 = "3.2";
    7 = "3.3";
    8 = "4.0";
    9 = "4.1";
    10 = "4.2";
    11 = "4.3";
    12 = "5.0";
    13 = "5.1";
    14 = "5.2";
    15 = "5.3";
    16 = "6.0";
    17 = "6.1";
    18 = "6.2";
    19 = "6.3";
}

Function Get-FileName($initialDirectory) {
    [System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms") | Out-Null
    $OpenFileDialog = New-Object System.Windows.Forms.OpenFileDialog
    $OpenFileDialog.initialDirectory = $initialDirectory
    $OpenFileDialog.ShowDialog() | Out-Null
    $OpenFileDialog.FileName
}

Function Get-Folder($initialDirectory="")
{
    [System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms")|Out-Null

    $foldername = New-Object System.Windows.Forms.FolderBrowserDialog
    $foldername.Description = "Select a folder"
    $foldername.rootfolder = "MyComputer"
    $foldername.SelectedPath = $initialDirectory

    if($foldername.ShowDialog() -eq "OK")
    {
        $folder += $foldername.SelectedPath
    }
    return $folder
}

Function Write-Config
{
    [CmdletBinding()]
	param(
        [Parameter()]
		[string] $path,
        $rootLocation
    )
    @{
        rootlocation = $rootLocation
    } | ConvertTo-Json | Out-File $path
    write-host "Config written! `n" -ForegroundColor green
}

Function Read-Config
{
    [CmdletBinding()]
	param(
        [Parameter()]
		[string] $Path
    )
    Get-Content $Path -raw | ConvertFrom-Json
}

Function Start-Timer($name)
{
    write-host "`r"
    Write-host "Start processing: $name" -ForegroundColor Yellow
    Set-Variable -name startTime -Value (get-date) -Scope script
}

Function Stop-Timer($name, $startTime)
{
    $endTime = get-date
    $time = new-timespan -start $startTime -End $endTime
    Write-host "$name completed in: $time" -ForegroundColor Magenta
}

Function Set-FileVars($video)
{
    Set-Variable -name fullName -Value $video.FullName -Scope script #fullpath
    Set-Variable -name baseName -Value $video.BaseName -Scope script #noExt
    Set-Variable -name name -Value $video.Name -Scope script #name w ext
    Set-Variable -name ext -Value $video.Extension -Scope script #.ext
    Set-Variable -name dir -Value $video.Directory -Scope script # path to folder
}

Function psPause()
{
    [void][System.Console]::ReadKey($FALSE)
}

Function Get-InputCodec {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$inputFile
    )

    return & ffprobe -v error -select_streams v:0 -show_entries stream=codec_name -of default=noprint_wrappers=1:nokey=1 $inputFile
}

function Get-FrameInfo {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$inputFile,
        
        [Parameter(Mandatory=$false)]
        [int]$totalFrames,

        [Parameter(Mandatory=$false)]
        [int]$framerate

    )
    
    write-host "`r"
    write-host "Checking for keyframes..."
    $probeData = & ffprobe -v error -read_intervals %12 -select_streams v:0 -show_entries frame=key_frame,pict_type,duration,repeat_pict,pts $inputFile
    # Split the output into an array of frames
    $framesRaw = $probeData -split '\r\n'

    # Process each raw frame
    $frames = @()
    $frameHashtable = @{}
    foreach ($line in $framesRaw) {

        if ($line -match "^\[FRAME\]|^\[/FRAME\]") {
            # If it's a new frame line and there's a previous frame, add it to the frames array
            if ($frameHashtable.Count -gt 0) {
                $frames += $frameHashtable
            }
            # Clear the hashtable for the new frame
            $frameHashtable = @{}
        }
        elseif ($line -match "=") {
            $key, $value = $line -split "=", 2
            $key = $key.Trim()
            $value = $value.Trim()
            $frameHashtable[$key] = $value
        }
    }

    # Add the last frame
    if ($frameHashtable.Count -gt 0) {
        $frames += $frameHashtable
    }

    # Initialize an empty array to hold pict_type of first 20 frames
    $frameTypes = @()

    <# foreach ($frame in $frames) {
        foreach ($property in $frame.Keys) {
            Write-Host ("$property " + $frame[$property])
        }
        Write-Host "----------------"
    }  #>

    $Duration = [int]$frames[1]["pts"]-[int]$frames[0]["pts"]
    $vfr = $false

    # Iterate over the first 20 frames
    for ($i = 0; $i -lt [Math]::Min(10, $frames.Count); $i++) {
        #$Duration = $frames[$i]["duration"]
        if ($i -eq 0) {
            write-host "First frame duration: $Duration"
            $frameTypes += $frames[$i]["pict_type"]
            $previousPts = $frames[$i]["pts"]
        } else {
            # Add the pict_type of the frame to the array
            $frameTypes += $frames[$i]["pict_type"]
            $currentPts = $frames[$i]["pts"]
            $correctPts = [int]$previousPts + [int]$Duration
            #write-host "pre: $previousPts cur: $currentPts dur: $Duration"

            if ($currentPts -ne $correctPts) {
                $vfr = $true
                $wrongDuration = [int]$currentPts - [int]$previousPts
                write-host "Pts not matching duration. Frame at index $i should have duration $Duration, but previous frame had duration $wrongDuration."
            }
            # Update the previous duration to the current one for the next iteration
            $previousPts = $currentPts
        } 
    }
    
    if ($vfr) {
        write-host "`r"
        Write-Warning "VFR detected! Not all frames have the same PTS interval"
        write-host "`r"
    }

    # Join the frame types into a single string
    $frameTypesString = -join $frameTypes
    
    # Initialize variables for GOP detection
    $frameCount = 0
    $keyframeCount = 0
    $frameLimit = 1500
    $totalFramesInProbe = [Math]::Min((12 * $framerate) - 1, $totalFrames - 1)

    # Use the minimum of frameLimit and totalFramesInProbe
    $frameThreshold = [Math]::Min($frameLimit, $totalFramesInProbe)

    $continueProcessing = $true
    $gopSize = 0

    foreach ($frame in $frames) {
        # Increment the frame count for each frame
        $frameCount++

        if ($frame.key_frame -eq 1 -and $continueProcessing) {
            # If it's a key frame, increment the key frame count
            $keyframeCount++

            if ($keyframeCount -eq 2) {
                # If it's not the first key frame, calculate the interval and return
                Write-Host "GOP found!" -ForegroundColor Green
                $gopSize = $frameCount-1
                $continueProcessing = $false
            }
        }
        
        if ($frameCount -ge $frameThreshold -and $continueProcessing) {
            # Exit the loop if the frame count has reached the threshold and no second key frame has been found yet
            $continueProcessing = $false
        }
    }

    # If no keyframe interval found, print the message
    if ($gopSize -eq 0) {
        Write-Host "`nWarn: No keyframe found! Video only has a single GOP, or keyint distance is over $frameThreshold frames or is over 12 sec. GOP will be inaccurate`n" -ForegroundColor Red
        $gopSize = $frameCount
    }

    return @{gopSize = $gopSize; frameTypesString = $frameTypesString; vfr = $vfr;}

}

Function Get-MaxRef {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$inputFile
    )
    write-host "Hunting for reference frames..."
    $ffmpegOutput = & ffmpeg -debug mmco -i $inputFile -an -t 12 -f null - 2>&1

    $maxRefFrames = 0
    $refFrameCounter = 0
    $insideShortTermList = $false

    foreach ($line in $ffmpegOutput) {
        if ($line -match "short term list:") {
            $insideShortTermList = $true
            $refFrameCounter = 0
        }
        elseif ($line -match "long term list:" -or $line -match "RefPicList") {
            $insideShortTermList = $false
            if ($refFrameCounter -gt $maxRefFrames) {
                $maxRefFrames = $refFrameCounter
            }
        }
        elseif ($insideShortTermList -and $line -match "fn:") {
            $refFrameCounter++
        }
    }

    write-host "Done finding refs!" -ForegroundColor Green
    return $maxRefFrames

}

Function Get-VideoStreamInfo {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$inputFile
    )

    # Run the ffprobe command
    write-host "`r"
    write-host "Gathering stream and format data..."
    $probeData = & ffprobe -v error -read_intervals %12 -select_streams v:0 -show_entries stream $inputFile
    $formatData = & ffprobe -v error -show_entries format $inputFile

    write-host "Parsing data..."
    # Split the output into an array of lines
    $lines = $probeData -split '\n' | Where-Object { $_.Trim() -ne "" }
    $formatLines = $formatdata -split '\n' | Where-Object { $_.Trim() -ne "" }

    # Initialize an empty hashtable to store the properties
    $info = @{}
    $formatInfo = @{}

    foreach ($line in $lines) {
        # Split the line into a key-value pair
        $parts = $line -split '=', 2

        # Store the key-value pair in the hashtable
        $info[$parts[0]] = $parts[1]
    }

    foreach ($formatLine in $formatLines) {
        # Split the line into a key-value pair
        $formatParts = $formatLine -split '=', 2

        # Store the key-value pair in the hashtable
        $formatInfo[$formatParts[0]] = $formatParts[1]
    }

    ## Renaming and fixing keys
    $info['SAR'] = $info['sample_aspect_ratio']
    $info.Remove('sample_aspect_ratio')
    
    $info['DAR'] = $info['display_aspect_ratio']
    $info.Remove('display_aspect_ratio')
    
    #FPS
    $maxFrameRateParts = $info['r_frame_rate'] -split '/'
    $maxFrameRate = $maxFrameRateParts[0] / $maxFrameRateParts[1]
    $info['MaxFPS(R)'] = [math]::Round($maxFrameRate, 3)
    $info.Remove('r_frame_rate')

    $avgFrameRateParts = $info['avg_frame_rate'] -split '/'
    try {
        $avgFrameRate = $avgFrameRateParts[0] / $avgFrameRateParts[1]
        $info['AvgFPS'] = [math]::Round($avgFrameRate, 3)
    } catch {
        Write-Warning "Avg framerate missing/unknown!"
        $info['AvgFPS'] = "?"
    }
    $info.Remove('avg_frame_rate')

    $info['BFrames'] = $info['has_b_frames'] -ne '0'
    $info.Remove('has_b_frames')

    # Extract total frames
    $totalFrames = $info['nb_frames']
    if ($totalFrames -eq "N/A") {
        Write-Warning "No explicit total frames, guesstimating..."
        write-host "stream duration: $($info['duration']), format duration: $($formatInfo['duration'])"

        # Convert durations to Double before calculation
        [double]$duration = 0
        [double]$maxFps = [double]$info['MaxFPS(R)']

        # Default to format-level duration

        $duration = $formatInfo['duration'] -as [double]
        if ($duration -eq 0) {
            Write-Warning "Failed to get format duration. `nformat duration: $($formatInfo['duration'])"
        }

        # Override with stream-level duration if available
        <# if (![string]::IsNullOrEmpty($info['duration']) -and $info['duration'] -ne "N/A" -and [double]::TryParse($info['duration'], [ref]$duration)) {
            $duration = [double]::Parse($info['duration'], [Globalization.CultureInfo]::InvariantCulture)
            write-host "Stream duration Found! `r$duration" -ForegroundColor Green
        } else {
            Write-Warning "Failed to get stream duration: `rstream duration: $info['duration']"
        } #>

        $totalFrames = [Math]::Round($duration * $maxFps)
        write-host "Guessed Total Frames: $totalFrames, Duration: $duration, FPS: $maxFps"
    } else {
        write-host "Total frames: $totalFrames" -ForegroundColor Green
    }

    # Call the function to get the first keyframe interval
    $result = Get-FrameInfo -inputFile $inputFile -totalFrames $totalFrames -framerate $maxFrameRate
    $firstKeyframeInterval = $result.gopSize
    $frameTypesString = $result.frameTypesString
    $vfr = $result.vfr

    # Calculate the keyframe interval in seconds
    $keyframeIntervalInSeconds = [math]::Round($firstKeyframeInterval / $maxFrameRate, 3)

    # Add the keyframe interval as a property
    $info['keyint (sec)'] = "$firstKeyframeInterval ($keyframeIntervalInSeconds)"
    $info['GOP Struct'] = $frameTypesString
    $info['VFR?'] = $vfr

    write-host "`r"
    if ($info['codec_name'] -eq "h264") {
        write-host "h264 found, checking refs..." -ForegroundColor Green
        $maxRefSeen = Get-MaxRef -inputFile $inputFile
        $info['refs'] = $maxRefSeen
    } else {
        write-host "not h264, cannot check refs!" -ForegroundColor Yellow
        $info['refs'] = "?"
    }

    #fix av1 levels
    if ($info['codec_name'] -eq "av1") {
        $ffmpegLevel = [int]$info['level']  # Convert string to int
        $av1Level = $ffmpegAv1LevelMap[$ffmpegLevel]
        if ($null -eq $av1Level) {
            write-warning "Unknown av1 level: $ffmpegLevel"
        } else {
            $info['level'] = $av1Level
        }
    }

    # Fix HEVC levels
    if ($info['codec_name'] -eq 'hevc') {
        $ffmpegLevel = [int]$info['level']  # Convert string to int
        $hevcLevel = "{0:N1}" -f ($ffmpegLevel / 30)  # Divide by 30 and format as a string with one decimal place
        $info['level'] = $hevcLevel
    }

    # Convert the hashtable to a custom object and return it
    return New-Object PSObject -Property $info
}

function Get-VideoInfo {
    param (
        [Parameter(Mandatory=$true)]
        [string]$video
    )

    # Probe input file
    $probeData = ffprobe -v error -show_entries format=duration:stream=height:stream=color_space:stream=color_range -of default=noprint_wrappers=1 "$video"

    # get duration of file
    $durationSec = ($probeData | Select-String "duration=").Line.Split('=')[1].Trim()
    $durationSecClamp = [math]::Round($durationSec)

    # get height
    $vidHeight = ($probeData | Select-String "height=").Line.Split('=')[1].Trim()

    # get input color range. Not currently used
    $inRange = ($probeData | Select-String "color_range=").Line.Split('=')[1].Trim()

    # get HDR
    $colorSpace = ($probeData | Select-String "color_space=").Line.Split('=')[1].Trim()
    $hdr = $false
    if ($colorSpace -like "bt2020*") {
        Write-Host "`n HDR file detected, Color Space: $colorSpace" -ForegroundColor Yellow
        $hdr = $true
    }

    # Return results as a custom object
    return @{
        DurationSec       = $durationSec
        DurationSecClamp  = $durationSecClamp
        VidHeight         = $vidHeight
        HDR               = $hdr
    }
}

function Get-File {
    do {
        # Prompt the user to drag and drop a video
        $videoPath = Read-Host -Prompt "`nPlease drag&drop a video, then hit Enter"

        # Strip surrounding quotes if they exist
        $videoPath = $videoPath -replace '^"(.*)"$', '$1'

        # Check if the input is not empty and is a valid file path
        if (-not [String]::IsNullOrWhiteSpace($videoPath) -and (Test-Path -Path $videoPath -PathType Leaf)) {
            # The input is a valid file path, convert it to FileInfo object
            $video = Get-ChildItem -Path $videoPath

            # Naming stuff
            Set-FileVars $video # Full=wPath, Base=noExt
            break
        } else {
            # The input is invalid, display a warning and continue the loop
            Write-Host "Invalid input. Please enter a valid file path." -ForegroundColor Yellow
        }
    } while ($true)

    return $video
}