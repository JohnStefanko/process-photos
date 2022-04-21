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
#$checkPath = "P:\Data\Pictures\ToCheck"
#$checkPath = "P:\Data\Pictures\Archive\2018\aug"
$checkPath = "P:\Data\Pictures\Archive\2002\Posted"
$picturesRootPath = "P:\Data\Pictures"
#$NasRootPath = "X:\Data\Pictures"
$currentDateTime = Get-Date -Format "yyyy-MM-dd-HHmm"
$logFilePath = Join-Path "C:\Data\Logs\Pictures" -ChildPath "Check-Photos_$currentDateTime.txt"
"INFO: Starting" >> $logFilePath

$exiftoolPath = "C:\ProgramData\chocolatey\bin\exiftool.exe"
if (!(Test-Path -Path $exiftoolPath)) {
    "ERROR: exiftool not found" >> $logFilePath
    Exit
}
$checkInFolders = "album", "archive", "studio"
$images = @()
$missingImageFiles = @()

$jpg = Get-ChildItem $checkPath -Filter *.jpg
$dng = Get-ChildItem $checkPath -Filter *.dng
$arw = Get-ChildItem $checkPath -Filter *.arw
$srw = Get-ChildItem $checkPath -Filter *.srw
$heic = Get-ChildItem $checkPath -filter *.heic
$imageFiles = $jpg + $dng + $heic + $arw + $srw

$psi = New-Object System.Diagnostics.ProcessStartInfo
$psi.FileName = $exiftoolPath
$psi.Arguments = "-stay_open True -@ -"; # note the second hyphen
$psi.UseShellExecute = $false
$psi.RedirectStandardInput = $true
$psi.RedirectStandardOutput = $true
$psi.RedirectStandardError = $true
$exiftool = [System.Diagnostics.Process]::Start($psi)

foreach ($imageFile in $imageFiles) {
    $exifFilePath = $imageFile.FullName
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
            "INFO: " + $imageFile.Name + " exists in " + $checkInPath >> $logFilePath
        }
    }
    if (!($fileExists)) {
        #"WARNING: " + $imageFile.Name + " NOT FOUND " >> $logFilePath
        $missingImageFiles += $imageFile.Name
    }

    $fileExists = $false
}

foreach ($missingImageFile in $missingImageFiles) {
    "WARNING: " + $missingImageFile + " NOT FOUND " >> $logFilePath
}
# end image loop

# send command to shutdown
$exiftool.StandardInput.WriteLine("-stay_open")
$exiftool.StandardInput.WriteLine("False")
$exiftool.WaitForExit()
$stdout = $exiftool.StandardError.ReadToEnd()
$stdout



