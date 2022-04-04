<#
.SYNOPSIS
    Check photos in specified directory to see if exist (by filename) in \archive, \album, or \studio
    
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
$checkPath = "P:\Data\Pictures\ToCheck"
$picturesRootPath = "P:\Data\Pictures"
#$NasRootPath = "X:\Data\Pictures"
$exiftoolPath = "C:\ProgramData\chocolatey\bin\exiftool.exe"
if (!(Test-Path -Path $exiftoolPath)) {
    "ERROR: exiftool not found" >> $logFilePath
    Exit
}
$checkInFolders = "album", "archive", "studio"
$images = @()
$backupFolders = @()

$jpg = Get-ChildItem $checkPath -Filter *.jpg
$dng = Get-ChildItem $checkPath -Filter *.dng
$arw = Get-ChildItem $checkPath -Filter *.arw
$srw = Get-ChildItem $checkPath -Filter *.srw
$heic = Get-ChildItem $checkPath -filter *.heic
$imageFiles = $jpg + $dng + $heic + $arw + $srw
$rawFiles = $dng + $arw + $srw

$psi = New-Object System.Diagnostics.ProcessStartInfo
$psi.FileName = $exiftoolPath
$psi.Arguments = "-stay_open True -@ -"; # note the second hyphen
$psi.UseShellExecute = $false
$psi.RedirectStandardInput = $true
$psi.RedirectStandardOutput = $true
$psi.RedirectStandardError = $true
$exiftool = [System.Diagnostics.Process]::Start($psi)


foreach ($imageFile in $imageFiles) {
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
    
    foreach ($checkInFolder in $checkInFolders) {
        $checkInPath = Join-Path -Path $picturesRootPath -ChildPath $checkInFolder $folderYear $folderMonth
        $checkFilePath = Join-Path -Path $checkInPath -ChildPath $imageFile.Name
        if (Test-Path -Path $checkFilePath) {
            $fileExists = $true
            
        }
        
    }
    $checkInPath = Join-Path -Path $checkPath -ChildPath "$image.*"
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
            $copyPath = Join-Path -Path $checkPath -ChildPath "$image.*"
            Copy-Item -Path $copyPath -Destination $destinationPath -Exclude "*.mie"
            # move to \archive
            Move-Item -Path $movePath -Destination $moveDestinationPath 
        }
        "reject" {
            # rejects; delete
            $removePath = Join-Path -Path $checkPath -ChildPath "$image.*"
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
            #$copyPath = Join-Path -Path $checkPath -ChildPath "$image.xmp"
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

$backupFolders = $backupFolders | Sort-Object -Unique
Set-Content -path (Join-Path -Path $path -ChildPath "backupfolders.txt") -Value $backupFolders
$backupFolders


