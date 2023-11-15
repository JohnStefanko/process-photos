<#
.SYNOPSIS
    Move photos in specified folder to Archive folder based on exif date

.DESCRIPTION
    Assumes Exiftool is installed via Chocolatey at "C:\ProgramData\chocolatey\bin\exiftool.exe."

.PARAMETER Path
    Path to folder with images to be processed.

.INPUTS
    Path of photos to process.

.OUTPUTS
    None

.EXAMPLE
    UtilMoveFiles-ToArchive -path C:\data\photos

.LINK
    References: 
    exiftool stay_open: https://exiftool.org/exiftool_pod.html#Advanced-options
    command to run while debugging: 
    taskkill /IM "exiftool.exe" /F
#>
# assume \studio, \album, \archive under same root
$picturesPath = "P:\Data\Pictures\ToCull"
$archivePath = "S:\Data\Pictures\Archive"


$currentDateTime = Get-Date -Format "yyyy-MM-dd-HHmm"
$logFilePath = Join-Path "C:\Data\Logs\Pictures" -ChildPath "CulledPhotos_$currentDateTime.txt"
#$rawFileExtensions = (".arw")
$rawFileExtensions = (".arw", ".srw")
#TODO: Rewrite so magick not version/path dependent
$exifToolPath = "C:\ProgramData\chocolatey\bin\exiftool.exe"
$images = @()

if (!(Test-Path -Path $exifToolPath)) {
    Write-Output "exiftool not found"
    Exit
}
#$jpg = Get-ChildItem $picturesPath -Filter *.jpg
#$dng = Get-ChildItem $picturesPath -Filter *.dng
$arw = Get-ChildItem $picturesPath -Filter *.arw
#$srw = Get-ChildItem $picturesPath -Filter *.srw
#$heic = Get-ChildItem $picturesPath -filter *.heic
$imageFiles = $arw
#$imageFiles = $jpg + $dng + $heic + $arw
#$rawFiles = $dng + $arw + $srw
#$images = $imageFiles.BaseName | Sort-Object | Get-Unique

# create Exiftool process
$psi = New-Object System.Diagnostics.ProcessStartInfo
$psi.FileName = $exifToolPath
$psi.Arguments = "-stay_open True -@ -"; # note the second hyphen
$psi.UseShellExecute = $false
$psi.RedirectStandardInput = $true
$psi.RedirectStandardOutput = $true
$psi.RedirectStandardError = $true

$exiftool = [System.Diagnostics.Process]::Start($psi)

foreach ($imageFile in $imageFiles) {
    # determine where to get EXIF rating from
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
    
    # for \archive
    #$movePath = Join-Path -Path $picturesPath -ChildPath "$image.*"
    $movePath = $imageFile.FullName
    $moveDestinationPath = Join-Path -Path $archivePath -ChildPath $folderYear $folderMonth
    Move-Item -Path $movePath -Destination $moveDestinationPath


# end imageFile loop
}

# send command to shutdown
$exiftool.StandardInput.WriteLine("-stay_open")
$exiftool.StandardInput.WriteLine("False")
$exiftool.WaitForExit()
$stdout = $exiftool.StandardError.ReadToEnd()
$stdout
#EXAMPLE: watching for modified folders
#$backupFolders = $backupFolders | Sort-Object -Unique
#Set-Content -path (Join-Path -Path $path -ChildPath "backupfolders.txt") -Value $backupFolders
#$backupFolders


