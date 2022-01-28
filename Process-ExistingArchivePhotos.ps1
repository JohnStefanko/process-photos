<#
.SYNOPSIS
    Process culled photos in local Album folder based on star rating ("-Rating")
        1: move to local \archive; get X: photo, move to X: \archive
        2: already in \album; do nothing
        3: move to local \studio; 

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
    command to run while debugging: 
    taskkill /IM "exiftool.exe" /F
#>
#[CmdletBinding()]
#param (
#    [Parameter(Mandatory=$true,HelpMessage="Enter path for files to move")]
#    [string]
#    $path
#)
$path = "P:\Data\Pictures\Archive\"
#"C:\Users\John\Pictures\iCloud Photos\Downloads"
#"C:\Users\John\Pictures\iCloud Photos\Downloads\dups"
#"P:\Data\Pictures\From Camera\a6000"
$copyDupPath = Join-Path -Path $path -ChildPath "copydups"
$moveDupPath = Join-Path -Path $path -ChildPath "movedups"
$localPathRoot = 'P:\Data\Pictures'
$NasPathRoot = 'X:\Data\Pictures'

$modelsFile = "$PSScriptRoot\EXIFmodels.txt"
#$modelsFile = "X:\Data\_config\Pictures\EXIFmodels.txt"
$moveFiles = @()
$images = @()
$imageNumbers = @()
$copyDupFiles = @()
$moveDupFiles = @()
$backupFolders = @()
if(!(Test-Path -Path $moveDupPath )) {
    New-Item -ItemType directory -Path $moveDupPath
}

# get exif model name > friendly model array
$models = Get-Content -Raw $modelsFile | ConvertFrom-StringData

$dng = Get-ChildItem $path -Filter *.dng
$arw = Get-ChildItem $path -Filter *.arw
$srw = Get-ChildItem $path -Filter *.srw
$rawFiles = $dng + $arw + $srw

# create Exiftool process
$psi = New-Object System.Diagnostics.ProcessStartInfo
$psi.FileName = "C:\ProgramData\chocolatey\bin\exiftool.exe"
$psi.Arguments = "-stay_open True -@ -"; # note the second hyphen
$psi.UseShellExecute = $false
$psi.RedirectStandardInput = $true
$psi.RedirectStandardOutput = $true
$psi.RedirectStandardError = $true

$exiftool = [System.Diagnostics.Process]::Start($psi)

#todo: make the below loop a function so it can be used for raw files first, then jpg files (that don't have matching raw files)
foreach ($rawFile in $rawFiles) {
    $rawFilePath = $rawFile.FullName
    $rawFileBaseName = $rawFile.BaseName
    $xmpFilePath = $rawFilePath + ".xmp"
    $xmpFile = Get-Item -Path $xmpFilePath
    $jpgFilePath = $rawFilePath + ".jpg"
    $jpgFile = Get-Item -Path $jpgFilePath
    $miePath = Join-Path -Path $path -ChildPath ($rawFile.Name + ".mie")

    #get rating
    $exiftool.StandardInput.WriteLine("-Rating")
    $exiftool.StandardInput.WriteLine("-s3")
    $exiftool.StandardInput.WriteLine("$xmpFilePath")
    $exiftool.StandardInput.WriteLine("-execute")
    $exifRating = $exiftool.StandardOutput.ReadLine()
    # if no Rating, assume "1" (i.e. for \Archive)
    if ($exifRating -eq "{ready}") {
        $exifRating = "1"
    }
    $exiftool.StandardOutput.ReadLine()

    # set datetime format to cast string as DateTime object
    $exiftool.StandardInput.WriteLine("-s3") # output format
    $exiftool.StandardInput.WriteLine("-d") # date format
    $exiftool.StandardInput.WriteLine("%m/%d/%Y %H:%M")
    $exiftool.StandardInput.WriteLine("-DateTimeOriginal")
    $exiftool.StandardInput.WriteLine("$rawFilePath")
    $exiftool.StandardInput.WriteLine("-execute")
    # read first line of output
    $exifDTO = [DateTime]$exiftool.StandardOutput.ReadLine()
    #todo: should be "{ready}"; could add check here
    $exiftool.StandardOutput.ReadLine() 

    $folderYear = $exifDTO.ToString("yyyy")
    $folderMonth = $exifDTO.ToString("yyyy-MM-MMMM")

    #copy based on xmp Rating (i.e. stars)
    switch ($exifRating) {
        "1" { 
            #do nothing
            $imageSet = @()
        }    
        "2" {
            #copy jpg, xmp to album
            $destinationPath = "album"
            $imageSet = Get-ChildItem $path -Filter ($rawFileBaseName + ".*") -Exclude $rawFile.FullName
        }
        "3" {
            #copy jpg, xmp to album
            $destinationPath = "album"
            $imageSet = Get-ChildItem $path -Filter ($rawFileBaseName + ".*") -Exclude $rawFile.FullName
        }
        "4" {
            #move to studio
            $destinationPath = "studio"
            $imageSet = Get-ChildItem $path -Filter ($rawFileBaseName + ".*")
        }
        "{ready}"{
            #this is exiftool output if no rating; do nothing
        }
        Default {
            #do nothing
            $imageSet = @()
        }
    }
    $copyPath = Join-Path -Path $localPathRoot -ChildPath $destinationPath $folderYear $folderMonth
    foreach ($imageFile in $imageSet) {
        #copy
        if (!(Test-Path (Join-Path -Path $copyPath -ChildPath $imageFile.Name) )) {
            $j = Copy-Item -Path $imageFile.FullName -Destination $copyPath -PassThru
            # write copy info to file
            $copyFiles += $j.FullName
            $backupFolders += $copyPath.ToString()
        }
        else {
            $j = Move-Item -Path $imageFile.FullName -Destination $dupPath -PassThru
            $moveDupFiles += $imageFile.Name
        }
    }
# end image loop
}

#process image files that don't have .xmp file
$heic = Get-ChildItem $path -filter *.heic
$jpg = Get-ChildItem $path -Filter *.jpg
$images = $jpg + $heic 


foreach ($imageFile in $images) {
    $imageFilePath = $imageFile.FullName
    $imageFileBaseName = $imageFile.BaseName
    $xmpFilePath = $imageFilePath + ".xmp"
    $xmpFile = Get-Item -Path $xmpFilePath
    
    #get rating
    $exiftool.StandardInput.WriteLine("-Rating")
    $exiftool.StandardInput.WriteLine("-s3")
    $exiftool.StandardInput.WriteLine("$xmpFilePath")
    $exiftool.StandardInput.WriteLine("-execute")
    $exifRating = $exiftool.StandardOutput.ReadLine()
    $exiftool.StandardOutput.ReadLine()

    # set datetime format to cast string as DateTime object
    $exiftool.StandardInput.WriteLine("-s3") # output format
    $exiftool.StandardInput.WriteLine("-d") # date format
    $exiftool.StandardInput.WriteLine("%m/%d/%Y %H:%M")
    $exiftool.StandardInput.WriteLine("-DateTimeOriginal")
    $exiftool.StandardInput.WriteLine("$rawFilePath")
    $exiftool.StandardInput.WriteLine("-execute")
    # read first line of output
    $exifDTO = [DateTime]$exiftool.StandardOutput.ReadLine()
    #todo: should be "{ready}"; could add check here
    $exiftool.StandardOutput.ReadLine() 

    $folderYear = $exifDTO.ToString("yyyy")
    $folderMonth = $exifDTO.ToString("yyyy-MM-MMMM")

    $imageSet = Get-ChildItem $path -Filter ($imageFileBaseName + ".*")
        
    switch ($exifRating) {
        "1" { 
            #move to archive
            $destinationPath = "archive"
            $movePath = Join-Path -Path $localPathRoot -ChildPath $destinationPath $folderYear $folderMonth
        }    
        "2" {
            #do nothing
        }
        "3" {
            #move to studio
            $destinationPath = "studio"
            $movePath = Join-Path -Path $localPathRoot -ChildPath $destinationPath $folderYear $folderMonth
        }
        Default {
            #do nothing
        }
    }
    #copy/move based on xmp Rating (i.e. stars)
    $movePath = Join-Path -Path $localPathRoot -ChildPath $destinationPath $folderYear $folderMonth

    foreach ($imageFile in $imageSet) {
        #move
        if (!(Test-Path (Join-Path -Path $movePath -ChildPath $imageFile.Name) )) {
            $j = Move-Item -Path $imageFile.FullName -Destination $movePath -PassThru
            # write move info to file
            $moveFiles += $j.FullName
            $backupFolders += $movePath.ToString()
        }
        else {
            $j = Move-Item -Path $imageFile.FullName -Destination $dupPath -PassThru
            $moveDupFiles += $imageFile.Name
        }
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

