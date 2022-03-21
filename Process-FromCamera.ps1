<#
.SYNOPSIS
    Rename photos newly imported from camera to prepare for culling with FastRawViewer. Copy to second local disk drive for backup.

.DESCRIPTION
    Assumes Exiftool is installed via Chocolatey at "C:\ProgramData\chocolatey\bin\exiftool.exe."

.PARAMETER Path
    Path to folder with images to be renamed

.INPUTS
    Path of photos to process.  ### not implemented yet

.OUTPUTS
    None.

.EXAMPLE
    Process-FromCamera -path C:\data\photos 

.LINK
    References: 
    exiftool stay_open: https://exiftool.org/exiftool_pod.html#Advanced-options

#>
$path = "P:\Data\Pictures\From Camera\a6000"
$backupPath = "C:\Data\Backup\From Camera"
$cullPath = "P:\Data\Pictures\ToCull"
$currentDateTime = Get-Date -Format "yyyy-MM-dd-HHmm"
$logFilePath = Join-Path "C:\Data\Logs\Pictures" -ChildPath "From-Camera_$currentDateTime.txt"

$exiftoolPath = "C:\ProgramData\chocolatey\bin\exiftool.exe"
if (!(Test-Path -Path $exiftoolPath)) {
    "ERROR: exiftool not found" >> $logFilePath
    Exit
}
# $modelsFile = "X:\Data\_config\Pictures\EXIFmodels.txt"
$modelsFile = "$PSScriptRoot\EXIFmodels.txt"
if (!(Test-Path -Path $modelsFile)) {
    "ERROR: model file not found" >> $logFilePath
    Exit
}
$images = @()
$imageNumbers = @()
# get exif model name > friendly model array
$models = Get-Content -Raw $modelsFile | ConvertFrom-StringData
#$rawFileExtensions = (".arw")
$rawFileExtensions = (".arw", ".srw", ".dng")
$jpg = Get-ChildItem $path -Filter *.jpg
$dng = Get-ChildItem $path -Filter *.dng
$arw = Get-ChildItem $path -Filter *.arw
$srw = Get-ChildItem $path -Filter *.srw
$heic = Get-ChildItem $path -filter *.heic
$imageFiles = $jpg + $dng + $heic + $arw
$images = $imageFiles.BaseName
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

foreach ($image in $images) {
    # get jpeg if exists, or raw if not, for exif info
    $imageFilePath = Join-Path -Path $path -ChildPath "$image.jpg"
    $imageFile = Get-ChildItem -Path $imageFilePath
    if (!(Test-Path -Path $imageFilePath)) {
        foreach ($fileExtension in $rawFileExtensions) {
            $imageFilePath = Join-Path -path $path -ChildPath "$image.$fileExtension"
            if (Test-Path -Path $imageFilePath) {
                continue
            }
        }
    }

    # get model from exiftool
    # -s3: print values only (no tag names)
    $exiftool.StandardInput.WriteLine("-Model")
    $exiftool.StandardInput.WriteLine("-s3")
    $exiftool.StandardInput.WriteLine("$imageFilePath")
    $exiftool.StandardInput.WriteLine("-execute")
    $exiftoolOut = $exiftool.StandardOutput.ReadLine()
    while ($exiftoolOut -ne "{ready}") {
        $exifModel = $exiftoolOut
        $exiftoolOut = $exiftool.StandardOutput.ReadLine()
    }    
    $model = $models[$exifModel]
    # get original photo incremental number from original filename based on model type
    $imageNumber = switch ($model) {
        "NX300" {$image.Substring(4,4)}
        "a6000" {$image.Substring(4,4)}
        "iPhone7Plus" {$image.Substring(4,4)}
        "iPhone8Plus" {$image.Substring(4,4)}
        Default {(Get-Item $imageFile).Length}
    }
    $imageNumbers += $imageNumber
    # get date from exiftool
    # -d: date format
    $exiftool.StandardInput.WriteLine("-d")
    $exiftool.StandardInput.WriteLine("%m/%d/%Y %H:%M")
    $exiftool.StandardInput.WriteLine("-DateTimeOriginal")
    $exiftool.StandardInput.WriteLine("$imageFilePath")
    $exiftool.StandardInput.WriteLine("-execute")
    $exiftoolOut = $exiftool.StandardOutput.ReadLine()
    while ($exiftoolOut -ne "{ready}") {
        $exifDTO = [DateTime]$exiftoolOut
        $exiftoolOut = $exiftool.StandardOutput.ReadLine()
    }    
    $imageFilesPath = Join-Path -Path $path -ChildPath "$image.*"
    $imageFiles = Get-ChildItem -Path $imageFilesPath
    $newImageBaseName = ($model, $exifDTO.ToString("yyyy-MM-dd"), $exifDTO.ToString("HHmm"), $imageNumber -join "_")
    foreach ($imageFile in $imageFiles) {
        $imageFileExtension = $imageFile.Extension # includes ".""
        if (Test-Path (Join-Path -Path $path -ChildPath "$newImageBaseName$imageFileExtension")) {
            $newImageBaseName = ($newImageBaseName, $imageFile.Length -join "_")
        }
        #rename with EXIF data returning file with new name
        $renamedImageFile = Rename-Item -path $imageFile.FullName -NewName "$newImageBaseName$imageFileExtension" -PassThru

        #copy to backup folder; defaults to replace if file exists
        $destinationCopyPath = Join-Path -Path $backupPath -ChildPath $renamedImageFile.Name
        if (!(Test-Path $destinationCopyPath)) {
            Copy-Item -Path $renamedImageFile.FullName -Destination $backupPath
        }
        else {
            "INFO: " + $renamedImageFile.FullName + " already exists in $backupPath" >> $logFilePath
        }
        # move to \ToCull
        $destinationMovePath = Join-Path -Path $cullPath -ChildPath $renamedImageFile.Name
        if (!(Test-Path $destinationMovePath)) {
            Move-Item -Path $renamedImageFile.FullName -Destination $cullPath
        }
        else {
            "INFO: " + $renamedImageFile.FullName + "  already exists in $cullPath" >> $logFilePath
        }
    # end image extensions loop
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

