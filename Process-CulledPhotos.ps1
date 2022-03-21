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
#$NasRootPath = "X:\Data\Pictures"
#$rawFileExtensions = (".arw")
$rawFileExtensions = (".arw", ".srw")
$magickArgs = "-compress", "JPEG", "-quality", "70","-sampling-factor", "4:2:2"
$exifToolPath = "C:\ProgramData\chocolatey\bin\exiftool.exe"
$magickPath = "C:\Program Files\ImageMagick-7.1.0-Q16-HDRI\magick.exe"
#$modelsFile = "X:\Data\_config\Pictures\EXIFmodels.txt"
#$modelsFile = "$PSScriptRoot\EXIFmodels.txt"
$images = @()
$backupFolders = @()

#if(!(Test-Path $NasRootPath)) {
#    "NAS drive not mapped!"
#    Exit
#}
if (!(Test-Path -Path $exifToolPath)) {
    Write-Output "exiftool not found"
    Exit
}
if (!(Test-Path -Path $magickPath)) {
    Write-Output "magick not found"
    Exit
}
#if (!(Test-Path -Path $modelsFile)) {
#    Write-Output "model file not found"
#    Exit
#}

# get exif model name > friendly model array
$models = Get-Content -Raw $modelsFile | ConvertFrom-StringData

$jpg = Get-ChildItem $cullPath -Filter *.jpg
$dng = Get-ChildItem $cullPath -Filter *.dng
$arw = Get-ChildItem $cullPath -Filter *.arw
$srw = Get-ChildItem $cullPath -Filter *.srw
$heic = Get-ChildItem $cullPath -filter *.heic
$imageFiles = $jpg + $dng + $heic + $arw
$rawFiles = $dng + $arw + $srw
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

#todo: make the below loop a function so it can be used for raw files first, then jpg files (that don't have matching raw files)
foreach ($image in $images) {
    #todo: check if $image*.xmp exists, if not skip to next file
    $xmpFilePath = "" # for rating, label
    $exifFilePath = "" # for date time
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
    
    #foreach ($fileExtension in $rawFileExtensions) {
    #    $filePath = Join-Path -path $path -ChildPath ($image + $fileExtension)
    #    if (Test-Path -Path $filePath) {
    #        $exifFilePath = $filePath
    #        $rawFilePath = $filePath
    #        $xmpFilePath = "$filePath.xmp"
    #    }
    #}
    #if (Test-Path -Path $xmpFilePath) {
    #    $xmpFile = Get-ChildItem -Path $xmpFilePath
    #}
    #else {
    #    Write-Host $xmpFilePath + " not found"
    #    continue
    #}
    # make backup mie file
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
    $exifRating = ""
    $exiftool.StandardInput.WriteLine("-Rating")
    $exiftool.StandardInput.WriteLine("-s3")
    $exiftool.StandardInput.WriteLine("$xmpFilePath")
    $exiftool.StandardInput.WriteLine("-execute")
    $exiftoolOut = $exiftool.StandardOutput.ReadLine()
    while ($exiftoolOut -ne "{ready}") {
        $exifRating = $exiftoolOut
        $exiftoolOut = $exiftool.StandardOutput.ReadLine()
    }
    
    #get label for \studio; copy all image files if "Blue"
    $exifLabel = ""
    $exiftool.StandardInput.WriteLine("-Label")
    $exiftool.StandardInput.WriteLine("-s3")
    $exiftool.StandardInput.WriteLine("$xmpFilePath")
    $exiftool.StandardInput.WriteLine("-execute")
    $exiftoolOut = $exiftool.StandardOutput.ReadLine()
    while ($exiftoolOut -ne "{ready}") {
        $exifLabel = $exiftoolOut
        $exiftoolOut = $exiftool.StandardOutput.ReadLine()
    }
    # if no Label, assume "" (i.e. no \Studio)
    
    # for \archive
    $movePath = Join-Path -Path $cullPath -ChildPath "$image.*"
    $moveDestinationPath = Join-Path -Path $picturesRootPath -ChildPath "archive" $folderYear $folderMonth
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
            Copy-Item -Path $copyPath -Destination $destinationPath
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
            #todo: find correct xmp to copy; for now copy all
            $copyPath = Join-Path -Path $cullPath -ChildPath "$image*.xmp"
            Copy-Item -Path $copyPath -Destination $destinationPath
            Move-Item -Path $movePath -Destination $moveDestinationPath
        }
        "none" {
            Write-Host $image " not rated"
        }
        Default {
            #do nothing
        }
    }
# end image loop
}

#process image files that don't have .xmp file

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
# Set-Content -path (Join-Path -Path $path -ChildPath "movedfiles.txt") -Value $moveFiles.count
# Add-Content -path (Join-Path -Path $path -ChildPath "movedfiles.txt") -Value $moveFiles
# "Moved files - " + $moveFiles.count
# Set-Content -path (Join-Path -Path $path -ChildPath "dupfiles.txt") -Value $dupfiles.count
# Add-Content -path (Join-Path -Path $path -ChildPath "dupfiles.txt") -Value $dupFiles
# "Duplicate files - " + $dupFiles.count

