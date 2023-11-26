<#
.SYNOPSIS
    Copy certain exif data from xmp files to jpg files    

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
$years = "2005", "2006", "2007", "2008", "2009", "2010", "2011", "2012", "2013", "2014", "2015", "2016", "2017", "2018", "2019", "2021", "2022"
$imagesParentFolder = "Album"
$imagesRootPath = "P:\Data\Pictures"
$currentDateTime = Get-Date -Format "yyyy-MM-dd-HHmm"
$logFilePath = Join-Path $imagesRootPath -ChildPath "$currentDateTime.txt"
$years >> $logFilePath

$exiftoolPath = "C:\ProgramData\chocolatey\bin\exiftool.exe"
if (!(Test-Path -Path $exiftoolPath)) {
    Write-Output "exiftool not found"
    Exit
}

$images = @()
$imageFiles = @()
$imageNumbers = @()



foreach ($year in $years) {
    $year >> $logFilePath
    $imagesYearPath = Join-Path -Path $imagesRootPath -ChildPath $imagesParentFolder $year
    $imagesMonthPaths = Get-ChildItem -Path $imagesYearPath -Directory
    foreach ($imagesPath in $imagesMonthPaths) {
        #debug specific month
        #$archivePath = "P:\Data\Pictures\Archive\2014\2014-07-July"
        $imagesPath.FullName >> $logFilePath
        $month = Split-Path -Path $imagesPath -Leaf
        $folderYear = $year
        $folderMonth = $month
        $xmpFiles = Get-ChildItem -Path $imagesPath -Filter "*.xmp"
        $images = $xmpFiles.BaseName | Sort-Object | Get-Unique

# loop through all image basenames
foreach ($image in $images) {
    # debug
    # create Exiftool process
    
    #$image >> $logFilePath
    $xmpFilePath = "" # for rating, label
    $exifFilePath = "" # for date time
    $exifRating = ""
    $exifLabel = ""
    $xmpFilePath = Join-Path $imagesPath -ChildPath "$image.xmp"
    if (!(Test-Path -Path $xmpFilePath)) {
        "ERROR: $xmpFilePath not found" >> $logFilePath
        Continue  
    }
    $jpgFilePath = Join-Path -path $imagesPath -ChildPath "$image.jpg"
    if (Test-Path -Path $jpgFilePath) {
        $jpgFile = Get-ChildItem -Path $jpgFilePath
    }
    else {
        "ERROR: $jpgFilePath not found" >> $logFilePath
        Continue 
    }
    $xmpFilePath = '"' + $xmpFilePath + '"'
    $jpgFilePath = '"' + $jpgFilePath + '"'
    $exifArgs = "-tagsfromfile", "$xmpFilePath", "-xmp:rating", "-xmp:label", "$jpgFilePath"
    & $exiftoolPath $exifArgs
    Rename-Item -Path $xmpFilePath -NewName "$xmpFilePath.txt"
    
#images loop
}
# month loop
}
# year loop
}
# send command to shutdown



