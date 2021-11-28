<#
.SYNOPSIS
    Process culled photos; move 2+ star rating to year/month folder structure under \Album; move 1 star rating photos to \Archive folder. 

.DESCRIPTION
    Assumes Exiftool is installed via Chocolatey at "C:\ProgramData\chocolatey\bin\exiftool.exe."

.PARAMETER Path
    Path to folder with images to be processed.

.INPUTS
    Path of photos to process.

.OUTPUTS
    Create movedfiles.txt, dupfiles.txt, and backupfiles.txt showing which NAS folders need to be backed up.

.EXAMPLE
    Process-Photos -path C:\data\photos

.LINK
    References: 
    exiftool stay_open: https://exiftool.org/exiftool_pod.html#Advanced-options

#>
#[CmdletBinding()]
#param (
#    [Parameter(Mandatory=$true,HelpMessage="Enter path for files to move")]
#    [string]
#    $path
#)
$path = "P:\Data\Pictures\From Camera\a6000"
#"C:\Users\John\Pictures\iCloud Photos\Downloads"
#"C:\Users\John\Pictures\iCloud Photos\Downloads\dups"
#"P:\Data\Pictures\From Camera\a6000"
$dupPath = Join-Path -Path $path -ChildPath "dups"
$localPathRoot = 'P:\Data\Pictures'
$NasPathRoot 'X:\Data\Pictures'

$modelsFile = "$PSScriptRoot\EXIFmodels.txt"
#$modelsFile = "X:\Data\_config\Pictures\EXIFmodels.txt"
$moveFiles = @()
$images = @()
$imageNumbers = @()
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
# get exif model name > friendly model array
$models = Get-Content -Raw $modelsFile | ConvertFrom-StringData
$jpg = Get-ChildItem $path -Filter *.jpg
$dng = Get-ChildItem $path -Filter *.dng
$arw = Get-ChildItem $path -Filter *.arw
$srw = Get-ChildItem $path -Filter *.srw
$heic = Get-ChildItem $path -filter *.heic
$images = $jpg + $dng + $heic + $arw

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
$xmpPath = $imagePath + ".xmp"
# -srcfile 
# %f.%e.xmp; tried using @ to represent original image file but can't get -srcfile to take multiple options
# set datetime format to cast string as DateTime object
$exiftool.StandardInput.WriteLine("-d")
$exiftool.StandardInput.WriteLine("%m/%d/%Y %H:%M")
$exiftool.StandardInput.WriteLine("-DateTimeOriginal")
$exiftool.StandardInput.WriteLine("$imagePath")
$exiftool.StandardInput.WriteLine("-execute")
# read first line of output
$exifDTO = [DateTime]$exiftool.StandardOutput.ReadLine()
#todo: should be "{ready}"; could add check here
$exiftool.StandardOutput.ReadLine() 
$exiftool.StandardInput.WriteLine("Rating")
$exiftool.StandardInput.WriteLine("s3")
$exiftool.StandardInput.WriteLine("$xmpPath")
$exiftool.StandardInput.WriteLine("-execute")
$exifRating = $exiftool.StandardOutput.ReadLine()
# if no Rating, assume "1" (i.e. for \Archive)
if ($exifRating -eq "{ready}") {
    $exifRating = "1"
}
$exiftool.StandardOutput.ReadLine()

$folderYear = $exifDTO.ToString("yyyy")
$folderMonth = $exifDTO.ToString("yyyy-MM-MMMM")

#rating = 1: move to \archive
#rating = 2: move to \album
#rating = 3: move \studio
#copy to NAS based on xmp Rating (i.e. stars)
$destinationPath = switch ($exifRating) {
    "1" {"archive"}
    "2" {"album"}
    "3" {"studio"}
    Default {"archive"}
}

$copyPath = Join-Path -Path $NasPathRoot -ChildPath $destinationPath -AdditionalChildPath $folderYear $folderMonth
if (!(Test-Path (Join-Path -Path $copyPath -ChildPath $i.Name) ))
{
    $j = Copy-Item -Path $i.FullName -Destination $newCopyPath -PassThru

}
else {
    
}

$movePath = Join-Path -Path $localPathRoot -ChildPath $destinationPath -AdditionalChildPath $folderYear $folderMonth




if (!(Test-Path (Join-Path -Path $movePath -ChildPath $i.Name) ))
{
    $j = Move-Item -Path $i.FullName -Destination $movePath -PassThru
    # make .mie file; backup of original exif data
    $imagePath = $j.FullName
    $miePath = $j.FullName + ".mie"
    $exiftool.StandardInput.WriteLine("-tagsFromFile")
    $exiftool.StandardInput.WriteLine("$imagepath")
    $exiftool.StandardInput.WriteLine("-all:all")
    $exiftool.StandardInput.WriteLine("-icc_profile")
    $exiftool.StandardInput.WriteLine("$miePath")
    $exiftool.StandardInput.WriteLine("-execute")
    #$exiftoolError = $exiftool.StandardError.ReadLine()
    #$exiftoolError
    $exiftoolOut = $exiftool.StandardOutput.ReadLine()
    $exiftoolOut
    while ($exiftoolOut -ne "{ready}") {
        $exiftoolOut = $exiftool.StandardOutput.ReadLine()
    }
    # write move info to file
    $moveFiles += $j.FullName
    $backupFolders += $movePath.ToString()
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
$stdout = $exiftool.StandardError.ReadToEnd()
$stdout
$backupFolders = $backupFolders | Sort-Object -Unique
Set-Content -path (Join-Path -Path $path -ChildPath "backupfolders.txt") -Value $backupFolders
$backupFolders
Set-Content -path (Join-Path -Path $path -ChildPath "movedfiles.txt") -Value $moveFiles.count
Add-Content -path (Join-Path -Path $path -ChildPath "movedfiles.txt") -Value $moveFiles
"Moved files - " + $moveFiles.count
Set-Content -path (Join-Path -Path $path -ChildPath "dupfiles.txt") -Value $dupfiles.count
Add-Content -path (Join-Path -Path $path -ChildPath "dupfiles.txt") -Value $dupFiles
"Duplicate files - " + $dupFiles.count

