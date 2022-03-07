<#
.SYNOPSIS
    Process culled photos in local \Album\2001-2013 folders (i.e. no raw files), based on star rating ("-Rating")
        label="Blue": move to \studio
        rating=1: remove--already in \archive
        rating>=2: already in \album; compress if larger than 2 MB

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
$years = "2002", "2003"
$pathRoot = "P:\Data\Pictures\Album"
$picturesRootPath = "P:\Data\Pictures"
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
$magickArgs = "mogrify", "-compress", "JPEG", "-quality", "70","-sampling-factor", "4:2:2"

# create Exiftool process
$psi = New-Object System.Diagnostics.ProcessStartInfo
$psi.FileName = "C:\ProgramData\chocolatey\bin\exiftool.exe"
$psi.Arguments = "-stay_open True -@ -"; # note the second hyphen
$psi.UseShellExecute = $false
$psi.RedirectStandardInput = $true
$psi.RedirectStandardOutput = $true
$psi.RedirectStandardError = $true

$exiftool = [System.Diagnostics.Process]::Start($psi)

foreach ($year in $years) {
    $pathYear = Join-Path -Path $pathRoot $year
    $pathMonths = Get-ChildItem -Path $pathYear -Directory
    foreach ($path in $pathMonths) {
        $path

        $month = Split-Path -Path $path -Leaf
        $folderYear = $year
        $folderMonth = $month
   
        $imageFiles = Get-ChildItem -Path $path -Filter *.jpg

#todo: make the below loop a function so it can be used for raw files first, then jpg files (that don't have matching raw files)
foreach ($imageFile in $imageFiles) {
    $imageFolderPath = $imageFile.Directory
    $jpgFile = $imageFile
    $imageFilePath = $imageFile.FullName
    $jpgFilePath = $imageFilePath
    $imageFileBaseName = $imageFile.BaseName
    $xmpFilePath = "$imageFilePath.xmp"
    if (Test-Path -Path $xmpFilePath) {
        $xmpFile = Rename-Item -Path $xmpFilePath -NewName "$imageFileBaseName.xmp" -PassThru
        $xmpFilePath = $xmpFile.FullName
    }
    else {
        $xmpFilePath = Join-Path -Path $imageFolderPath -ChildPath "$imageFileBaseName.xmp"
    }
    
    #get label for \studio; copy all image files if "Blue"
    $exiftool.StandardInput.WriteLine("-Label")
    $exiftool.StandardInput.WriteLine("-s3")
    $exiftool.StandardInput.WriteLine("$xmpFilePath")
    $exiftool.StandardInput.WriteLine("-execute")
    $exifLabel = $exiftool.StandardOutput.ReadLine()
    # if no Label, assume "" (i.e. no \Studio)
    if ($exifLabel -eq "{ready}") {
        $exifLabel = ""
    }
    else {
        $exiftool.StandardOutput.ReadLine()
    }
    if ($exifLabel -eq "Blue") {
        # move all to \studio
        $destination = "studio"
        $destinationPath = Join-Path -Path $picturesRootPath -ChildPath $destination $folderYear $folderMonth
        $movePath = Join-Path -Path $imageFolderPath -ChildPath "$imageFileBaseName.*"
        $imageFilesMove = Move-Item -Path $movePath -Destination $destinationPath -PassThru
    }
    else {
        #process by rating
        $exiftool.StandardInput.WriteLine("-Rating")
        $exiftool.StandardInput.WriteLine("-s3")
        $exiftool.StandardInput.WriteLine("$xmpFilePath")
        $exiftool.StandardInput.WriteLine("-execute")
        $exifRating = $exiftool.StandardOutput.ReadLine()
        # if no Rating, assume "1" (i.e. for \Archive)
        if ($exifRating -eq "{ready}") {
            $exifRating = "1"
        }
        $exiftool.StandardOutput.ReadLine()
        switch ($exifRating) {
            {"1", "{ready}"} { 
                #Delete; already in \archive 
                $removePath = Join-Path -Path $imageFolderPath -ChildPath "$imageFileBaseName.*"
                Remove-Item -Path $removePath
                $imageSet = @()
            }    
            {"2", "3", "4", "5"} {
                #compress if >=2MB; else do nothing
                if ($jpgFile.Length -gt 2MB) {
                    #compress jpg
                    #$destinationMagickPath = Join-Path -Path $destinationPath -ChildPath $jpgFile.Name
                    & $magickPath $magickArgs $imageFilePath
                }
            }
            Default {
                #do nothing
            }
        }
    }
# end image loop
}

}
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

