<#
.SYNOPSIS
    Process culled photos in local \Archive folder based on star rating ("-Rating")
        Label = "Blue": copy all to \Studio
        1: do nothing
        2, 3, 4, 5: copy jpg to local \Album

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
$years = "2018", "2019", "2020", "2021", "2022"
$archiveRootPath = "P:\Data\Pictures\Archive"
$rejectRootPath = "P:\Data\Pictures\_Rejected"
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
$magickPath = "C:\Program Files\ImageMagick-7.1.0-Q16-HDRI\magick.exe"
if (!(Test-Path -Path $magickPath)) {
    Write-Output "magick not found"
    Exit
}
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
$rawFiles = @()
$rawFileExtensions = @()
$rawFileExtensions = ('.srw', '.arw')
$magickArgs = "-compress", "JPEG", "-quality", "70","-sampling-factor", "4:2:2"

# create Exiftool process
$psi = New-Object System.Diagnostics.ProcessStartInfo
$psi.FileName = $exiftoolPath
$psi.Arguments = "-stay_open True -@ -"; # note the second hyphen
$psi.UseShellExecute = $false
$psi.RedirectStandardInput = $true
$psi.RedirectStandardOutput = $true
$psi.RedirectStandardError = $true
$exiftool = [System.Diagnostics.Process]::Start($psi)

foreach ($year in $years) {
    $archiveYearPath = Join-Path -Path $archiveRootPath $year
    $archiveMonthPaths = Get-ChildItem -Path $archiveYearPath -Directory
    foreach ($archivePath in $archiveMonthPaths) {
        #debug specific month
        #$archivePath = "P:\Data\Pictures\Archive\2014\2014-07-July"
        $archivePath.FullName >> $logFilePath
        $month = Split-Path -Path $archivePath -Leaf
        $folderYear = $year
        $folderMonth = $month
        if ($folderMonth -eq "2018-08-August") {
            Continue 
        }
        $imageFiles = Get-ChildItem -Path $archivePath -Exclude *.mie, *.xmp, *.tif, *.pp3, *.txt, captureone, "Ellen Senior Pictures", "2018-08-August"
        $images = $imageFiles.BaseName | Sort-Object | Get-Unique

# loop through all image basenames
foreach ($image in $images) {
    # debug
    #$image >> $logFilePath
    $xmpFilePath = "" # for rating, label
    $exifFilePath = "" # for date time
    $exifRating = ""
    $exifLabel = ""
    $xmpFilePath = Join-Path $archivePath -ChildPath "$image.xmp"
    if (!(Test-Path -Path $xmpFilePath)) {
        "ERROR: $xmpFilePath not found" >> $logFilePath
        Continue  
    }
    $jpgFilePath = Join-Path -path $archivePath -ChildPath "$image.jpg"
    if (Test-Path -Path $jpgFilePath) {
        $jpgFile = Get-ChildItem -Path $jpgFilePath
    }
    else {
        "ERROR: $jpgFilePath not found" >> $logFilePath
        Continue 
    }

    #get label for \studio; copy all image files if "Blue"
    $exiftool.StandardInput.WriteLine("-Label")
    $exiftool.StandardInput.WriteLine("-s3")
    $exiftool.StandardInput.WriteLine("$xmpFilePath")
    $exiftool.StandardInput.WriteLine("-execute")
    $exiftoolOut = $exiftool.StandardOutput.ReadLine()
    while ($exiftoolOut -ne "{ready}") {
        $exifLabel = $exiftoolOut
        $exiftoolOut = $exiftool.StandardOutput.ReadLine()
    }    
    if ($exifLabel -eq "Blue") {
        # copy all to \studio
        $destination = "studio"
        $destinationPath = Join-Path -Path $picturesRootPath -ChildPath $destination $folderYear $folderMonth
        $copySourcePath = Join-Path -Path $archivePath -ChildPath "$image.*"
        $imageFilesCopy = Copy-Item -Path $copySourcePath -Destination $destinationPath -PassThru
        $copySourcePath >> $logStudioFiles
        $studioFolders += $destinationPath
    }
    else {
        #process by rating
        $exiftool.StandardInput.WriteLine("-Rating")
        $exiftool.StandardInput.WriteLine("-s3")
        $exiftool.StandardInput.WriteLine("$xmpFilePath")
        $exiftool.StandardInput.WriteLine("-execute")
        $exiftoolOut = $exiftool.StandardOutput.ReadLine()
        while ($exiftoolOut -ne "{ready}") {
            $exifRating = $exiftoolOut
            $exiftoolOut = $exiftool.StandardOutput.ReadLine()
        }
        switch ($exifRating) {
            "-1" {
                #move to \_Rejected
                $rejectSourcePath = Join-Path -Path $archivePath -ChildPath "$image.*"
                Move-Item -Path $rejectSourcePath -Destination $rejectRootPath
                $rejectSourcePath >> $logRemoveFiles
            }
            "1" {
                #do nothing; already in \archive
            }
            {($_ -eq "2") -or ($_ -eq "3") -or ($_ -eq "4") -or ($_ -eq "5")} {
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
                #copy xmp
                $copySourcePath = Join-Path -Path $archivePath -ChildPath "$image.xmp"
                Copy-Item -Path $copySourcePath -Destination $destinationPath
                }
            Default {
                #do nothing
            }
        # switch rating loop
        }
    #process rating loop
    }
#images loop
}
# month loop
}
# year loop
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

$studioFolders = $studioFolders | Sort-Object -Unique
Set-Content -path (Join-Path -Path $archiveRootPath -ChildPath "studiofolders $currentDateTime.txt") -Value $studioFolders

