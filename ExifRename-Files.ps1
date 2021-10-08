<#
.SYNOPSIS
    Renames image files based on EXIF Model, DateTimeOriginal, and original image number.

.DESCRIPTION
    Assumes Exiftool is installed via Chocolatey at "C:\ProgramData\chocolatey\bin\exiftool.exe"

.PARAMETER Path
    Path to folder with images to be renamed

.INPUTS
    None. You cannot pipe objects to Add-Extension.

.OUTPUTS
    None.

.EXAMPLE
    ExifRename-Files -path C:\data\photos

.LINK
    None.
#>

<#
file dialog doesn't work with Core
Add-Type -AssemblyName System.Windows.Forms
$browser = New-Object System.Windows.Forms.FolderBrowserDialog -Property @{SelectedPath = [Environment]::GetFolderPath("MyDocuments")}
$browser.Description = "Select folder"
$null = $browser.ShowDialog()
$path = $browser.SelectedPath

#SelectedPath = 'X:\Data\Pictures\From Camera\NX300'
#>
[CmdletBinding()]
param (
    [Parameter(Mandatory=$true,HelpMessage="Enter path for files to rename")]
    [string]
    $path
)
$path = "C:\Users\John\Pictures\iCloud Photos\Downloads"
#$path = "X:\Data\Pictures\From Camera\a6000-2"
#$path = "C:\Users\John\Pictures\Test-Script"

$NASpath = "X:\Data\Pictures"
$modelsPath = "X:\Data\_config\Pictures\EXIFmodels.txt"
$images = @()
if(!(Test-Path $NASpath))
{
    "NAS drive not mapped!"
    Exit
}

$models = Get-Content -Raw $modelsPath | ConvertFrom-StringData
$jpg = Get-ChildItem $path -Filter *.jpg
$dng = Get-ChildItem $path -Filter *.dng
$arw = Get-ChildItem $path -Filter *.arw
$srw = Get-ChildItem $path -Filter *.srw
$heic = Get-ChildItem $path -filter *.heic
$images = $jpg + $arw + $dng + $srw + $heic

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

# end image loop
}

# send command to shutdown
$exiftool.StandardInput.WriteLine("-stay_open")
$exiftool.StandardInput.WriteLine("False")

# wait for process to exit and output STDIN and STDOUT
#$exiftool.StandardError.ReadToEnd()
#$exiftool.StandardOutput.ReadToEnd()
$exiftool.WaitForExit()

