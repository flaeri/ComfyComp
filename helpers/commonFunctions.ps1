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