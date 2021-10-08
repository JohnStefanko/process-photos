<#
.SYNOPSIS
    Moves images from the specified path to the NAS Album folder based on EXIF DateTimeOriginal.

.DESCRIPTION
    Assumes Exiftool is installed via Chocolatey at "C:\ProgramData\chocolatey\bin\exiftool.exe."

.PARAMETER Path
    Path to folder with images to be renamed

.INPUTS
    None. You cannot pipe objects to Add-Extension.

.OUTPUTS
    Create movedfiles.txt, dupfiles.txt, and backupfiles.txt showing which NAS folders need to be backed up.

.EXAMPLE
    Move-Photos -path C:\data\photos

.LINK
    None.

#>
[CmdletBinding()]
param (
    [Parameter(Mandatory=$true,HelpMessage="Enter path for files to move")]
    [string]
    $path
)
$path = "P:\Data\Pictures\From Camera\a6000"
#"C:\Users\John\Pictures\iCloud Photos\Downloads"
#"C:\Users\John\Pictures\iCloud Photos\Downloads\dups"
#"P:\Data\Pictures\From Camera\a6000"
#$dupPath = Join-Path -Path $path -ChildPath "dups"
$dupPath = "P:\Data\Pictures\From Camera\a6000\dups"
$NASpath = "X:\Data\Pictures\Album"
$copyPath = "P:\Data\Pictures\Album"
$modelsPath = "X:\Data\_config\Pictures\EXIFmodels.txt"
$backupFolders = @()
$moveFiles = @()
$images = @()
$dupFiles = @()
if(!(Test-Path $NASpath))
{
    "NAS drive not mapped!"
    Exit
}
if(!(Test-Path -Path $dupPath ))
{
    New-Item -ItemType directory -Path $dupPath
}
$models = Get-Content -Raw $modelsPath | ConvertFrom-StringData
$jpg = Get-ChildItem $path -Filter *.jpg
$dng = Get-ChildItem $path -Filter *.dng
$arw = Get-ChildItem $path -Filter *.arw
$srw = Get-ChildItem $path -Filter *.srw
$heic = Get-ChildItem $path -filter *.heic

$images = $jpg + $arw + $dng + $srw

# create Exiftool process
$psi = New-Object System.Diagnostics.ProcessStartInfo
$psi.FileName = "C:\ProgramData\chocolatey\bin\exiftool.exe"
$psi.Arguments = "-stay_open True -@ -"; # note the second hyphen
$psi.UseShellExecute = $false
$psi.RedirectStandardInput = $true
$psi.RedirectStandardOutput = $true
$psi.RedirectStandardError = $true

$exiftool = [System.Diagnostics.Process]::Start($psi)

foreach($i in $images)
{
$imagePath = $i.FullName
#$imagePath
$exiftool.StandardInput.WriteLine("-Model")
$exiftool.StandardInput.WriteLine("-s3")
$exiftool.StandardInput.WriteLine("-d")
# get date in format to cast string as DateTime object
$exiftool.StandardInput.WriteLine("%m/%d/%Y %H:%M")
$exiftool.StandardInput.WriteLine("-DateTimeOriginal")
$exiftool.StandardInput.WriteLine("$imagePath")
$exiftool.StandardInput.WriteLine("-execute")
$exifModel = $exiftool.StandardOutput.ReadLine()
# if no EXIF Model, skip to next photo
if ($exifModel -eq "{ready}") {
    continue
}
$exifDTO = [DateTime]$exiftool.StandardOutput.ReadLine()
$exiftool.StandardOutput.ReadLine()

$model = $models[$exifModel]
$imageNumber = switch ($model) {
    "NX300" {$i.Name.Substring(4,4)}
    "a6000" {$i.Name.Substring(4,4)}
    "iPhone7Plus" {$i.Name.Substring(4,4)}
    "iPhone8Plus" {$i.Name.Substring(4,4)}
    Default {(Get-Item $i).Length}
}

$newName = ($model, $exifDTO.ToString("yyyy-MM-dd"), $exifDTO.ToString("HHmm"), $imageNumber -join "_") + $i.Extension
#rename with EXIF data
if (Test-Path (Join-Path -Path $path -ChildPath $newName)) {
    $newName = ($model, $exifDTO.ToString("yyyy-MM-dd"), $exifDTO.ToString("HHmm"), $imageNumber, (Get-Item $i).Length -join "_") + $i.Extension
}

$i = Rename-Item -path $i.FullName -NewName $newName -PassThru

#copy to NAS Album
$folderYear = $exifDTO.ToString("yyyy")
$folderMonth = $exifDTO.ToString("yyyy-MM-MMMM")

$newPath = Join-Path -path $NASpath -ChildPath $folderYear $folderMonth
$newCopyPath = Join-Path -path $copyPath -ChildPath $folderYear $folderMonth
$j = Copy-Item -Path $i.FullName -Destination $newCopyPath -PassThru
#move to local Album; check if exists, if so > dup
if (!(Test-Path (Join-Path -Path $newPath -ChildPath $i.Name) ))
{
    $j = Move-Item -Path $i.FullName -Destination $newPath -PassThru
    $moveFiles += $j.FullName
    $backupFolders += $newPath.ToString()
    $i.Name
}
else {
    $j = Move-Item -Path $i.FullName -Destination $dupPath -PassThru
    $dupFiles += $i.Name
}

# end image loop
}

# send command to shutdown
$exiftool.StandardInput.WriteLine("-stay_open")
$exiftool.StandardInput.WriteLine("False")

# wait for process to exit and output STDIN and STDOUT
#$exiftool.StandardError.ReadToEnd()
#$exiftool.StandardOutput.ReadToEnd()
$exiftool.WaitForExit()
$backupFolders = $backupFolders | Sort-Object -Unique
Set-Content -path (Join-Path -Path $path -ChildPath "backupfolders.txt") -Value $backupFolders
$backupFolders
Set-Content -path (Join-Path -Path $path -ChildPath "movedfiles.txt") -Value $moveFiles.count
Add-Content -path (Join-Path -Path $path -ChildPath "movedfiles.txt") -Value $moveFiles
"Moved files - " + $moveFiles.count
Set-Content -path (Join-Path -Path $path -ChildPath "dupfiles.txt") -Value $dupfiles.count
Add-Content -path (Join-Path -Path $path -ChildPath "dupfiles.txt") -Value $dupFiles
"Duplicate files - " + $dupFiles.count
