<#
.SYNOPSIS
    Process culled photos after import; 
    Label="Blue": Copy all to \Studio; Make .mie; Move all to \Archive
    Rating="2", "3", "4", "5": Copy/compress jpg to \Album; Make .mie; Move all to \Archive
    Rating="1": Move to Archive
    Rating="-1": Delete Rejects

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
$archivePath = "S:\Data\Pictures\Archive"
#Join-Path -Path $picturesRootPath -ChildPath "archive"
$studioPath = Join-Path -Path $picturesRootPath -ChildPath "studio"
$rejectPath= Join-Path -Path $picturesRootPath -ChildPath "reject"

$currentDateTime = Get-Date -Format "yyyy-MM-dd-HHmm"
$logFilePath = Join-Path "C:\Data\Logs\Pictures" -ChildPath "CulledPhotos_$currentDateTime.txt"
#$NasRootPath = "X:\Data\Pictures"
#$rawFileExtensions = (".arw")
$rawFileExtensions = (".arw", ".srw")
$images = @()
$backupFolders = @()

#exiftool.exe is in PATH
#$exifToolPath = "C:\ProgramData\chocolatey\bin\exiftool.exe"
$exifToolPath = "exiftool.exe"
try {
    $exifToolOut = Get-Command exiftool.exe -ErrorAction Stop
}
catch {
    <#Do this if a terminating exception happens#>
    Write-Output "Exiftool not found"
    Exit
}
$output = "Exiftool: " + $exifToolOut.version + " (" + $exifToolOut.Source + ")"
Write-Output $output
<#
    if (!(Test-Path -Path $exifToolPath)) {
    Write-Output "exiftool not found"
    Exit
}
#>

#$magickPath = "C:\Program Files\ImageMagick-7.1.1-Q16-HDRI\magick.exe"
# magick.exe is in PATH
$magickPath = "magick.exe"
$magickArgs = "-compress", "JPEG", "-quality", "70","-sampling-factor", "4:2:2"
#$magickArgs = "-version"
try {
    $magickOut = Get-Command magick.exe -ErrorAction Stop
}
catch {
    <#Do this if a terminating exception happens#>
    Write-Output "Magick.exe not found"
}
$output = "Magick: " + $magickOut.version + " (" +$magickOut.Source + ")"
Write-Output $output
<#
$testout = & $magickPath $magickArgs
Write-Output $testout.split([Environment]::Newline)[0]
if ($testout.split([Environment]::Newline)[0].Substring(0,7) -ne "Version") {
    Write-Output "magick not found"
    Exit
}
#>

$jpg = Get-ChildItem $cullPath -Filter *.jpg
$dng = Get-ChildItem $cullPath -Filter *.dng
$arw = Get-ChildItem $cullPath -Filter *.arw
$srw = Get-ChildItem $cullPath -Filter *.srw
$heic = Get-ChildItem $cullPath -filter *.heic
$imageFiles = $jpg + $dng + $heic + $arw
#$rawFiles = $dng + $arw + $srw
$images = $imageFiles.BaseName | Sort-Object | Get-Unique
$intNumImages = $images.length
Write-Host "Processing $intNumImages images"

# create Exiftool process
$psi = New-Object System.Diagnostics.ProcessStartInfo
$psi.FileName = $exifToolPath
$psi.Arguments = "-stay_open True -@ -"; # note the second hyphen
$psi.UseShellExecute = $false
$psi.RedirectStandardInput = $true
$psi.RedirectStandardOutput = $true
$psi.RedirectStandardError = $true

$exiftool = [System.Diagnostics.Process]::Start($psi)
$count = 0
foreach ($image in $images) {
    $count = $count + 1
    $complete = [int](100 * ($count/$intNumImages))
    $stat = $count.ToString() + " of " + $intNumImages.ToString()
    Write-Progress -Activity "Processing photos" -Status $stat -PercentComplete $complete -CurrentOperation $image
    # FastRawViewer set to always create XMP sidecar for both RAW and JPG files
    # Ratings will always be in XMP
    $xmpFilePath = Join-Path -Path $cullPath -ChildPath "$image.xmp"
    $xmpFileExists = Test-Path -Path $xmpFilePath
    if (!($xmpFileExists)) {
        "INFO: no XMP info for $image" >> $logFilePath
        continue
    }
    # DateTimeOriginal has to come from JPG or RAW file; does NOT exist in XMP file
    $jpgFilePath = Join-Path -Path $cullPath -ChildPath "$image.jpg"
    $jpgFileExists = Test-Path -Path $jpgFilePath
    if ($jpgFileExists) {
        # can get DTO from JPG if either only JPG or both RAW + JPG
        $exifFilePath = $jpgFilePath
        $jpgFile = Get-ChildItem -Path $jpgFilePath
    }
    else {
        # No JPG, check for RAW
        $arwFilePath = Join-Path -Path $cullPath -ChildPath "$image.arw"
        $arwFileExists = Test-Path -Path $arwFilePath
        if ($arwFileExists) {
            $exifFilePath = $arwFilePath
        }
        $dngFilePath = Join-Path -Path $cullPath -ChildPath "$image.dng"
        $dngFileExists = Test-Path -Path $dngFilePath
        if ($dngFileExists) {
            $exifFilePath = $dngFilePath
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
    $exiftool.StandardInput.WriteLine("$xmpFilePath")
    $exiftool.StandardInput.WriteLine("-execute")
    $exiftoolOut = $exiftool.StandardOutput.ReadLine()
    while ($exiftoolOut -ne "{ready}") {
        $xmpRating = $exiftoolOut
        $exiftoolOut = $exiftool.StandardOutput.ReadLine()
    }
    
    #get label for \studio; copy all image files if "Blue"
    $exiftool.StandardInput.WriteLine("-Label")
    $exiftool.StandardInput.WriteLine("-s3")
    $exiftool.StandardInput.WriteLine("$xmpFilePath")
    $exiftool.StandardInput.WriteLine("-execute")
    $exiftoolOut = $exiftool.StandardOutput.ReadLine()
    while ($exiftoolOut -ne "{ready}") {
        $xmpLabel = $exiftoolOut
        $exiftoolOut = $exiftool.StandardOutput.ReadLine()
    }
    
    # for \archive
    $movePath = Join-Path -Path $cullPath -ChildPath "$image.*"
    $moveDestinationPath = Join-Path -Path $archivePath -ChildPath $folderYear $folderMonth
    # for \studio
    $albumDestinationPath = Join-Path -Path $albumPath -ChildPath $folderYear $folderMonth
    if ($xmpLabel -eq "Blue") {
        # copy all to \studio; move to \archive
        $destination = "studio"
    }
    else {
        # not Blue; create compressed jpg in \Albums (local and NAS); move all image files to \Archive
        $destination = switch ($xmpRating) {
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
            #create compressed jpg in \album
            if ($jpgFileExists) {
                $destinationMagickPath = Join-Path -Path $albumDestinationPath -ChildPath $jpgFile.Name
                & $magickPath $jpgFilePath $magickArgs $destinationMagickPath
            }
            # move all image files to \archive
            Move-Item -Path $movePath -Destination $moveDestinationPath 
        }
        "reject" {
            # rejects; delete
            $removePath = Join-Path -Path $cullPath -ChildPath "$image.*"
            Remove-Item -Path $removePath 
        }
        "archive" { 
            # move all image files to \archive
            Move-Item -Path $movePath -Destination $moveDestinationPath
        }    
        "album" {
            #create compressed jpg in \album, move all image files to \archive
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
$exiftoolOut = ""
$xmpRating = ""
$xmpLabel = ""
$exifFilePath = "" # for date time
$jpgFile = ""
$jpgFilePath = ""
$jpgFileExists = $false
$xmpFilePath = "" # for rating, label
$xmpFileExists = $false
$arwFilePath = ""
$arwFileExists = $false
$dngFilePath = ""
$dngFileExists = $false
$copyPath = ""
$destination = ""
$destinationPath = ""
$destinationMagickPath = ""
$movePath = ""
$moveDestinationPath = ""
$removePath = ""
$albumDestinationPath = ""

#Write-Host "$image complete"
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
Set-Content -path (Join-Path -Path $cullPath -ChildPath "backupfolders_$currentDateTime.txt") -Value $backupFolders
$backupFolders


