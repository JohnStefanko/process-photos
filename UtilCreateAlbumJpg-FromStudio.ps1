<#
.SYNOPSIS
    Loop through \studio to create compressed jpgs for \album

.DESCRIPTION
    Originally, I didn't create jpgs for culled photos moved to \studio, so there was no jpg in \album until I edited them. Now, the original jpg will be added to \album by default.
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
$years = "2018", "2019", "2020", "2021", "2022"
$processRootPath = "P:\Data\Pictures\Studio"
$picturesRootPath = "P:\Data\Pictures"
$currentDateTime = Get-Date -Format "yyyy-MM-dd-HHmm"
$logFilePath = Join-Path $archiveRootPath -ChildPath "$currentDateTime.txt"
$logStudioFiles = Join-Path $archiveRootPath -ChildPath "studiofiles $currentDateTime.txt"
$logRemoveFiles = Join-Path $archiveRootPath -ChildPath "removefiles $currentDateTime.txt"
$logCompressFiles = Join-Path $archiveRootPath -ChildPath "compressfiles $currentDateTime.txt"
$years >> $logFilePath

$exiftoolPath = "C:\ProgramData\chocolatey\bin\exiftool.exe"
if (!(Test-Path -Path $exiftoolPath)) {
    Write-Output "exiftool not found"
    Exit
}
$magickPath = "C:\Program Files\ImageMagick-7.1.1-Q16-HDRI\magick.exe"
if (!(Test-Path -Path $magickPath)) {
    Write-Output "magick not found"
    Exit
}
$magickArgs = "-compress", "JPEG", "-quality", "70","-sampling-factor", "4:2:2"

#$modelsFile = "X:\Data\_config\Pictures\EXIFmodels.txt"
$modelsFile = "$PSScriptRoot\EXIFmodels.txt"
if (!(Test-Path -Path $modelsFile)) {
    Write-Output "model file not found"
    Exit
}

$studioFolders = @()
$images = @()
$imageFiles = @()
$imageNumbers = @()

foreach ($year in $years) {
    $processYearPath = Join-Path -Path $processRootPath $year
    $processMonthPaths = Get-ChildItem -Path $processYearPath -Directory
    foreach ($processPath in $processMonthPaths) {
        #debug specific month
        #$archivePath = "P:\Data\Pictures\Archive\2014\2014-07-July"
        $processPath.FullName >> $logFilePath
        $month = Split-Path -Path $processPath -Leaf
        $folderYear = $year
        $folderMonth = $month
        #if ($folderMonth -eq "2018-08-August") {
        #    Continue 
        #}
        $jpg = Get-ChildItem $processPath -Filter *.jpg
        $imageFiles = $jpg # only processing jpg files
        #Get-ChildItem -Path $processPath -Exclude *.mie, *.xmp, *.tif, *.pp3, *.txt, captureone, "Ellen Senior Pictures", "2018-08-August"
        $images = $imageFiles.BaseName | Sort-Object | Get-Unique

        # loop through all image basenames
        foreach ($image in $imagesFiles) {
            # debug
            #$image >> $logFilePath
            $jpgFilePath = Join-Path -path $processPath -ChildPath "$image.jpg"
            if (Test-Path -Path $jpgFilePath) {
                $jpgFile = Get-ChildItem -Path $jpgFilePath
            }
            #copy jpg, xmp to \album
            $destination = "album"
            $destinationPath = Join-Path -Path $picturesRootPath -ChildPath $destination $folderYear $folderMonth 
            if ($jpgFile.Length -gt 2MB) {
                #compress jpg
                $destinationMagickPath = Join-Path -Path $destinationPath -ChildPath $jpgFile.Name
                & $magickPath $jpgFilePath $magickArgs $destinationMagickPath
                $jpgFilePath >> $logCompressFiles
            }
            else {
                #copy jpeg
                $copySourcePath = Join-Path -Path $archivePath -ChildPath "$image.jpg"
                Copy-Item -Path $copySourcePath -Destination $destinationPath
            }
        #images loop
        }
    # month loop
    }
# year loop
}


$studioFolders = $studioFolders | Sort-Object -Unique
Set-Content -path (Join-Path -Path $archiveRootPath -ChildPath "studiofolders $currentDateTime.txt") -Value $studioFolders

