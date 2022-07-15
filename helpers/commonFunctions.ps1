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
    #$time = $time.ToString("hh' h 'mm' min 'ss' sec'")
    Write-host "$name completed in: $time" -ForegroundColor Magenta
}