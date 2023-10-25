<#
.SYNOPSIS
    Process culled photos after import; 
    Delete Rejects
    Label="Blue": Copy all to \Studio; Make .mie; Move all to \Archive
    Rating="2", "3", "4", "5": Copy jpg to \Studio; Make .mie; Move all to \Archive

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
# assume \studio, \album, \archive under same root
$cullPath = "P:\Data\Pictures\ToCull"
$picturesRootPath = "P:\Data\Pictures"
$albumPath = Join-Path -Path $picturesRootPath -ChildPath "album"
$archivePath = Join-Path -Path $picturesRootPath -ChildPath "archive"
$studioPath = Join-Path -Path $picturesRootPath -ChildPath "studio"
$rejectPath= Join-Path -Path $picturesRootPath -ChildPath "reject"


$currentDateTime = Get-Date -Format "yyyy-MM-dd-HHmm"
$logFilePath = Join-Path "C:\Data\Logs\Pictures" -ChildPath "CulledPhotos_$currentDateTime.txt"
#$NasRootPath = "X:\Data\Pictures"
#$rawFileExtensions = (".arw")
$rawFileExtensions = (".arw", ".srw")
#TODO: Rewrite so magick not version/path dependent
$magickPath = "C:\Program Files\ImageMagick-7.1.1-Q16-HDRI\magick.exe"
$magickArgs = "-compress", "JPEG", "-quality", "70","-sampling-factor", "4:2:2"
$exifToolPath = "C:\ProgramData\chocolatey\bin\exiftool.exe"
$images = @()
$backupFolders = @()

if (!(Test-Path -Path $exifToolPath)) {
    Write-Output "exiftool not found"
    Exit
}
if (!(Test-Path -Path $magickPath)) {
    Write-Output "magick not found"
    Exit
}

$jpg = Get-ChildItem $cullPath -Filter *.jpg
$dng = Get-ChildItem $cullPath -Filter *.dng
$arw = Get-ChildItem $cullPath -Filter *.arw
$srw = Get-ChildItem $cullPath -Filter *.srw
$heic = Get-ChildItem $cullPath -filter *.heic
$imageFiles = $jpg + $dng + $heic + $arw
#$rawFiles = $dng + $arw + $srw
$images = $imageFiles.BaseName | Sort-Object | Get-Unique

# create Exiftool process
$psi = New-Object System.Diagnostics.ProcessStartInfo
$psi.FileName = $exifToolPath
$psi.Arguments = "-stay_open True -@ -"; # note the second hyphen
$psi.UseShellExecute = $false
$psi.RedirectStandardInput = $true
$psi.RedirectStandardOutput = $true
$psi.RedirectStandardError = $true

$exiftool = [System.Diagnostics.Process]::Start($psi)

foreach ($image in $images) {
    $jpgFilePath =  Join-Path -Path $cullPath -ChildPath "$image.jpg"
    $xmpFilePath = Join-Path -Path $cullPath -ChildPath "$image.xmp"
    $jpgFileExists = Test-Path -Path $jpgFilePath
    $xmpFileExists = Test-Path -Path $xmpFilePath
    if ($jpgFileExists) {
        $exifFilePath = $jpgFilePath
        $jpgFile = Get-ChildItem -Path $jpgFilePath
    }
    else {
        if ($xmpFileExists) {
            $exifFilePath = $xmpFilePath
        }
        else {
            "INFO: no EXIF info for $image" >> $logFilePath
            continue
        }
    }
    $miePath = Join-Path -Path $cullPath -ChildPath "$image.mie"
    if (!(Test-Path ($miePath))) {
        $exiftool.StandardInput.WriteLine("-tagsFromFile")
        $exiftool.StandardInput.WriteLine("$exifFilePath")
        $exiftool.StandardInput.WriteLine("-all:all")
        $exiftool.StandardInput.WriteLine("-icc_profile")
        $exiftool.StandardInput.WriteLine("$miePath")
        $exiftool.StandardInput.WriteLine("-execute")
        $exiftoolOut = $exiftool.StandardOutput.ReadLine()
        while ($exiftoolOut -ne "{ready}") {
            $exiftoolOut = $exiftool.StandardOutput.ReadLine()
        }
    }
    #get date/time
    # set datetime format to cast string as DateTime object
    $exifDTO = ""
    $exiftool.StandardInput.WriteLine("-s3") # output format
    $exiftool.StandardInput.WriteLine("-d") # date format
    $exiftool.StandardInput.WriteLine("%m/%d/%Y %H:%M")
    $exiftool.StandardInput.WriteLine("-DateTimeOriginal")
    $exiftool.StandardInput.WriteLine("$exifFilePath")
    $exiftool.StandardInput.WriteLine("-execute")
    # read first line of output
    $exiftoolOut = $exiftool.StandardOutput.ReadLine()
    while ($exiftoolOut -ne "{ready}") {
        $exifDTO = [DateTime]$exiftoolOut
        $exiftoolOut = $exiftool.StandardOutput.ReadLine()
    }

    $folderYear = $exifDTO.ToString("yyyy")
    $folderMonth = $exifDTO.ToString("yyyy-MM-MMMM")

    #get rating
    $exiftool.StandardInput.WriteLine("-Rating")
    $exiftool.StandardInput.WriteLine("-s3")
    $exiftool.StandardInput.WriteLine("$exifFilePath")
    $exiftool.StandardInput.WriteLine("-execute")
    $exiftoolOut = $exiftool.StandardOutput.ReadLine()
    while ($exiftoolOut -ne "{ready}") {
        $exifRating = $exiftoolOut
        $exiftoolOut = $exiftool.StandardOutput.ReadLine()
    }
    
    #get label for \studio; copy all image files if "Blue"
    $exiftool.StandardInput.WriteLine("-Label")
    $exiftool.StandardInput.WriteLine("-s3")
    $exiftool.StandardInput.WriteLine("$exifFilePath")
    $exiftool.StandardInput.WriteLine("-execute")
    $exiftoolOut = $exiftool.StandardOutput.ReadLine()
    while ($exiftoolOut -ne "{ready}") {
        $exifLabel = $exiftoolOut
        $exiftoolOut = $exiftool.StandardOutput.ReadLine()
    }
    
    # for \archive
    $movePath = Join-Path -Path $cullPath -ChildPath "$image.*"
    $moveDestinationPath = Join-Path -Path $archivePath -ChildPath $folderYear $folderMonth
    # for \studio
    $albumDestinationPath = Join-Path -Path $albumPath -ChildPath $folderYear $folderMonth
    if ($exifLabel -eq "Blue") {
        # copy all to \studio; move to \archive
        $destination = "studio"
    }
    else {
        # not Blue; copy compressed jpg to \Albums (local and NAS); move to \Archive
        $destination = switch ($exifRating) {
            "-1" {"reject"}
            "1" {"archive"}
            "2" {"album"}
            "3" {"album"}
            "4" {"album"}
            "5" {"album"}
            "{ready}" {"none"}
            Default {}
        }
    }
    $destinationPath = Join-Path -Path $picturesRootPath -ChildPath $destination $folderYear $folderMonth
    $backupFolders += $destinationPath.ToString()
    switch ($destination) {
        "studio" {
            $copyPath = Join-Path -Path $cullPath -ChildPath "$image.*"
            Copy-Item -Path $copyPath -Destination $destinationPath -Exclude "*.mie"
            #jpg to \album
            if ($jpgFileExists) {
                $destinationMagickPath = Join-Path -Path $albumDestinationPath -ChildPath $jpgFile.Name
                & $magickPath $jpgFilePath $magickArgs $destinationMagickPath
            }
            # move to \archive
            Move-Item -Path $movePath -Destination $moveDestinationPath 
        }
        "reject" {
            # rejects; delete
            $removePath = Join-Path -Path $cullPath -ChildPath "$image.*"
            Remove-Item -Path $removePath 
        }
        "archive" { 
            # move to \archive
            Move-Item -Path $movePath -Destination $moveDestinationPath
        }    
        "album" {
            #compress jpg, copy xmp to \album; move to \archive
            if ($jpgFileExists) {
                $destinationMagickPath = Join-Path -Path $destinationPath -ChildPath $jpgFile.Name
                & $magickPath $jpgFilePath $magickArgs $destinationMagickPath
            }
            #copy xmp
            #i don't need .xmp files in \album
            #$copyPath = Join-Path -Path $cullPath -ChildPath "$image.xmp"
            #Copy-Item -Path $copyPath -Destination $destinationPath
            Move-Item -Path $movePath -Destination $moveDestinationPath
        }
        "none" {
            Write-Host $image " not rated"
        }
        Default {
            #do nothing
        }
    }
$exifRating = ""
$exifLabel = ""
$xmpFilePath = "" # for rating, label
$exifFilePath = "" # for date time
$jpgFilePath = ""
# end image loop
}

# send command to shutdown
$exiftool.StandardInput.WriteLine("-stay_open")
$exiftool.StandardInput.WriteLine("False")
$exiftool.WaitForExit()
$stdout = $exiftool.StandardError.ReadToEnd()
$stdout
#EXAMPLE: watching for modified folders
$backupFolders = $backupFolders | Sort-Object -Unique
Set-Content -path (Join-Path -Path $path -ChildPath "backupfolders.txt") -Value $backupFolders
$backupFolders


