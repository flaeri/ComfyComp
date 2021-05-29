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
        test = "test"
    } | ConvertTo-Json | Out-File $path
    write-host "Config written!" -ForegroundColor green
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