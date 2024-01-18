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
    taskkill /IM "exiftool.exe" /F

#>
$path = "P:\Data\Pictures\From Camera\a6400m"
$archivePath = "S:\Data\Pictures\Archive"
$cullPath = "P:\Data\Pictures\ToCull"
$currentDateTime = Get-Date -Format "yyyy-MM-dd-HHmm"
$backupPath = "S:\Data\Pictures\Backup\$currentDateTime"
if(!(Test-Path -Path $backupPath ))
{
    New-Item -ItemType directory -Path $backupPath
}

#EXAMPLE: logfile
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
#TODO: use array of image extension types and loop $imageFiles += extension
$jpg = Get-ChildItem $path -Filter *.jpg
$dng = Get-ChildItem $path -Filter *.dng
$arw = Get-ChildItem $path -Filter *.arw
$srw = Get-ChildItem $path -Filter *.srw
$heic = Get-ChildItem $path -filter *.heic
$imageFiles = $jpg + $dng + $heic + $arw
$images = $imageFiles.BaseName
$images = $imageFiles.BaseName | Sort-Object | Get-Unique

# create Exiftool process
#EXAMPLE: use of System.Diagnostics.ProcessStartInfo and Process Start
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
    #EXAMPLE: exiftool process stayopen usage with improved {ready} handling
    $exiftool.StandardInput.WriteLine("-Model")
    $exiftool.StandardInput.WriteLine("-s3")
    $exiftool.StandardInput.WriteLine("$imageFilePath")
    $exiftool.StandardInput.WriteLine("-execute")
    $exiftoolOut = $exiftool.StandardOutput.ReadLine()
    while ($exiftoolOut -ne "{ready}") {
        $exifModel = $exiftoolOut
        $exiftoolOut = $exiftool.StandardOutput.ReadLine()
    }
    #EXAMPLE: use of array to set variable
    $model = $models[$exifModel]
    # get original photo incremental number from original filename based on model type
    #EXAMPLE: getting original photo number
    #TODO: make function to get original photo number
    $imageNumber = switch ($model) {
        "NX300" {$image.Substring(4,4)}
        "a6000" {$image.Substring(4,4)}
        "a6400m" {$image.Substring(4,4)}
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
    $exiftool.StandardInput.WriteLine("-s3")
    $exiftool.StandardInput.WriteLine("$imageFilePath")
    $exiftool.StandardInput.WriteLine("-execute")
    $exiftoolOut = $exiftool.StandardOutput.ReadLine()
    while ($exiftoolOut -ne "{ready}") {
        $exifDTO = [DateTime]$exiftoolOut
        $exiftoolOut = $exiftool.StandardOutput.ReadLine()
    }    
    $folderYear = $exifDTO.ToString("yyyy")
    $folderMonth = $exifDTO.ToString("yyyy-MM-MMMM")
    $newImageBaseName = ($model, $exifDTO.ToString("yyyy-MM-dd"), $exifDTO.ToString("HHmm"), $imageNumber -join "_")

    $imageFilesPath = Join-Path -Path $path -ChildPath "$image.*"
    $imageFiles = Get-ChildItem -Path $imageFilesPath

    foreach ($imageFile in $imageFiles) {
        $imageFileExtension = $imageFile.Extension # includes ".""
        if (Test-Path (Join-Path -Path $path -ChildPath "$newImageBaseName$imageFileExtension")) {
            $newImageBaseName = ($newImageBaseName, $imageFile.Length -join "_")
        }
        #rename with EXIF data returning file with new name
        $renamedImageFile = Rename-Item -path $imageFile.FullName -NewName "$newImageBaseName$imageFileExtension" -PassThru

        #copy to backup folder; defaults to replace if file exists
        $destinationFileCopyPath = Join-Path -Path $backupPath -ChildPath $renamedImageFile.Name
        if (!(Test-Path $destinationFileCopyPath)) {
            Copy-Item -Path $renamedImageFile.FullName -Destination $backupPath
        }
        else {
            "INFO: " + $renamedImageFile.FullName + " already exists in $backupPath" >> $logFilePath
        }
        # move to \ToCull or \Archive for monochrome ARW files
        if ($model -eq "a6400m" -and $imageFileExtension -eq ".arw") {
            <# Action to perform if the condition is true #>
            #arw monochrome files have crosshatch artifact and are not needed; move to archive
            $destinationFileMovePath = Join-Path -Path $archivePath -ChildPath $folderYear $folderMonth $renamedImageFile.Name
            $destinationFolderMovePath = Join-Path -Path $archivePath -ChildPath $folderYear $folderMonth 
        }
        else {
            <# Action when all if and elseif conditions are false #>
            $destinationFileMovePath = Join-Path -Path $cullPath -ChildPath $renamedImageFile.Name
            $destinationFolderMovePath = $cullPath
            
        }
        if (!(Test-Path $destinationFileMovePath)) {
            Move-Item -Path $renamedImageFile.FullName -Destination $destinationFolderMovePath
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

