<#
.SYNOPSIS
    Rename photos newly imported from camera to prepar for culling with FastRawViewer. Copy to second local disk drive for backup.

.DESCRIPTION
    Assumes Exiftool is installed via Chocolatey at "C:\ProgramData\chocolatey\bin\exiftool.exe."

.PARAMETER Path
    Path to folder with images to be renamed

.INPUTS
    Path of photos to process.  ### not implemented yet

.OUTPUTS
    None.

.EXAMPLE
    ExifRename-Files -path C:\data\photos 

.LINK
    References: 
    exiftool stay_open: https://exiftool.org/exiftool_pod.html#Advanced-options

#>
$path = "P:\Data\Pictures\From Camera\a6000"
$backupPath = "C:\Data\Backup\From Camera"
$cullPath = "P:\Data\Pictures\ToCull"
$exiftoolPath = "C:\ProgramData\chocolatey\bin\exiftool.exe"
if (!(Test-Path -Path $exiftoolPath)) {
    Write-Output "exiftool not found"
    Exit
}
# $modelsFile = "X:\Data\_config\Pictures\EXIFmodels.txt"
$modelsFile = "$PSScriptRoot\EXIFmodels.txt"
if (!(Test-Path -Path $modelsFile)) {
    Write-Output "model file not found"
    Exit
}
$images = @()
$imageNumbers = @()
# get exif model name > friendly model array
$models = Get-Content -Raw $modelsFile | ConvertFrom-StringData
$rawFileExtensions = (".arw")
# $rawFileExtensions = ('.srw', '.arw')
$jpg = Get-ChildItem $path -Filter *.jpg
$dng = Get-ChildItem $path -Filter *.dng
$arw = Get-ChildItem $path -Filter *.arw
$srw = Get-ChildItem $path -Filter *.srw
$heic = Get-ChildItem $path -filter *.heic
$imageFiles = $jpg + $dng + $heic + $arw
#$images = Get-ChildItem -Path $path -Exclude *.mie, *.xmp, *.tif, *.pp3, captureone
# $images = $imageFiles.BaseName | Sort-Object | Get-Unique

# create Exiftool process
$psi = New-Object System.Diagnostics.ProcessStartInfo
$psi.FileName = $exiftoolPath
$psi.Arguments = "-stay_open True -@ -"; # note the second hyphen
$psi.UseShellExecute = $false
$psi.RedirectStandardInput = $true
$psi.RedirectStandardOutput = $true
$psi.RedirectStandardError = $true
$exiftool = [System.Diagnostics.Process]::Start($psi)

foreach($imageFile in $imageFiles) {
    $imageFilePath = $imageFile.FullName
    # enter exiftool parameters
    $exiftool.StandardInput.WriteLine("-Model")
    $exiftool.StandardInput.WriteLine("-s3")
    $exiftool.StandardInput.WriteLine("-d")
    # get date in format to cast string as DateTime object
    $exiftool.StandardInput.WriteLine("%m/%d/%Y %H:%M")
    $exiftool.StandardInput.WriteLine("-DateTimeOriginal")
    $exiftool.StandardInput.WriteLine("$imageFilePath")
    # run exiftool
    $exiftool.StandardInput.WriteLine("-execute")
    # read first line of output
    $exifModel = $exiftool.StandardOutput.ReadLine()
    # if no EXIF Model ("{ready}"), skip i.e. continue to next photo in loop
    if ($exifModel -eq "{ready}") {
        continue
    }
    $exifDTO = [DateTime]$exiftool.StandardOutput.ReadLine()
    $exiftool.StandardOutput.ReadLine()

    $model = $models[$exifModel]
    # get original photo incremental number from original filename based on model type
    $imageNumber = switch ($model) {
        "NX300" {$imageFile.Name.Substring(4,4)}
        "a6000" {$imageFile.Name.Substring(4,4)}
        "iPhone7Plus" {$imageFile.Name.Substring(4,4)}
        "iPhone8Plus" {$imageFile.Name.Substring(4,4)}
        Default {(Get-Item $imageFile).Length}
    }
    $imageNumbers += $imageNumber

    # new file name with friendly model, exif date, and original number
    $newName = ($model, $exifDTO.ToString("yyyy-MM-dd"), $exifDTO.ToString("HHmm"), $imageNumber -join "_") + $imageFile.Extension
    # check if new name exists, if so add length string
    if (Test-Path (Join-Path -Path $path -ChildPath $newName)) {
        $newName = ($model, $exifDTO.ToString("yyyy-MM-dd"), $exifDTO.ToString("HHmm"), $imageNumber, (Get-Item $imageFile).Length -join "_") + $imageFile.Extension
    }
    #rename with EXIF data returning file with new name
    $renamedImageFile = Rename-Item -path $imageFile.FullName -NewName $newName -PassThru

    #copy to backup folder; defaults to replace if file exists
    $copyPath = Join-Path -Path $backupPath -ChildPath $newName
    if (!(Test-Path $copyPath)) {
        Copy-Item -Path $renamedImageFile.FullName -Destination $backupPath
    }
    else {
        Write-Host $copyPath " already exists"
    }
    # move to \ToCull
    $movePath = Join-Path -Path $cullPath -ChildPath $newName
    if (!(Test-Path $movePath)) {
        Move-Item -Path $renamedImageFile.FullName -Destination $cullPath
    }
    else {
        Write-Host $movePath " already exists"
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

