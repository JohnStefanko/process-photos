<#

Input: files

Add-Type -AssemblyName System.Windows.Forms
$browser = New-Object System.Windows.Forms.FolderBrowserDialog -Property @{
    #SelectedPath = 'X:\Data\Pictures\From Camera\NX300'
    SelectedPath = [Environment]::GetFolderPath("MyDocuments")
}
$browser.Description = "Select folder"
$null = $browser.ShowDialog()
$path = $browser.SelectedPath
#>
$path = "C:\Users\John\Pictures\Test-Script"

$dupPath = Join-Path -Path $path -ChildPath "dups"
$NASpath = "X:\Data\Pictures"
$modelsPath = "X:\Data\_config\Pictures\EXIFmodels.txt"
$backupFolders = @()
$moveFiles = @()
$images = @()
$dupFiles = @()
if(!(Test-Path $NASpath))
{
    "NAS drive not mapped!"
    Exit
}
if(!(Test-Path -Path $dupPath ))
{
    New-Item -ItemType directory -Path $dupPath
}
$models = Get-Content -Raw $modelsPath | ConvertFrom-StringData
$jpg = Get-ChildItem $path -Filter *.jpg
$dng = Get-ChildItem $path -Filter *.dng
$arw = Get-ChildItem $path -Filter *.arw
$srw = Get-ChildItem $path -Filter *.srw

$images = $jpg + $arw + $dng + $srw

# create Exiftool process
$psi = New-Object System.Diagnostics.ProcessStartInfo
$psi.FileName = "C:\ProgramData\chocolatey\bin\exiftool.exe"
$psi.Arguments = "-stay_open True -@ -"; # note the second hyphen
$psi.UseShellExecute = $false
$psi.RedirectStandardInput = $true
$psi.RedirectStandardOutput = $true
$psi.RedirectStandardError = $true

$exiftool = [System.Diagnostics.Process]::Start($psi)

foreach($i in $images)
{
$imagePath = $i.FullName
#$imagePath
$exiftool.StandardInput.WriteLine("-Model")
$exiftool.StandardInput.WriteLine("-s3")
$exiftool.StandardInput.WriteLine("-d")
# get date in format to cast string as DateTime object
$exiftool.StandardInput.WriteLine("%m/%d/%Y %H:%M")
$exiftool.StandardInput.WriteLine("-DateTimeOriginal")
$exiftool.StandardInput.WriteLine("$imagePath")
$exiftool.StandardInput.WriteLine("-execute")
$exifModel = $exiftool.StandardOutput.ReadLine()
$exifDTO = [DateTime]$exiftool.StandardOutput.ReadLine()
$exiftool.StandardOutput.ReadLine()

$model = $models[$exifModel]
$imageNumber = switch ($model) {
    "NX300" {$i.Name.Substring(4,4)}
    "a6000" {$i.Name.Substring(4,4)}
    "iPhone7Plus" {$i.Name.Substring(4,4)}
    "iPhone8Plus" {$i.Name.Substring(4,4)}
    Default {"0000"}
}

if(
    (
        # Google Photos can't see .srw, so can't use in Picasa
        ($model -eq "NX300") -and ($i.Extension -eq ".srw")
    ) -or 
    (
        #.arw files are ok, so put a6000 jpgs in Original
        ($model -eq "a6000") -and ($i.Extension -eq ".jpg")
    )
   )
{
    $newPath = Join-Path -path $NASpath -ChildPath "Original" $exifDTO.ToString("yyyy") $exifDTO.ToString("yyyy-MM-MMMM")
}
else
{
    $newPath = Join-Path -path $NASpath -ChildPath "Album" $exifDTO.ToString("yyyy") $exifDTO.ToString("yyyy-MM-MMMM")
}

$newName = $model + "_" + $exifDTO.ToString("yyyy-MM-dd") + "_" + $exifDTO.ToString("HHmm") + "_" + $imageNumber + $i.Extension
#rename with EXIF data
$i = Rename-Item -path $i.FullName -NewName $newName -PassThru
#copy

if(!(Test-Path (Join-Path -Path $newPath -ChildPath $newName) ))
{
    $j = Move-Item -Path $i.FullName -Destination $newPath -PassThru
    $moveFiles += $i.Name
    $backupFolders += $newPath.ToString()
}
else {
    $j = Move-Item -Path $i.FullName -Destination $dupPath -PassThru
    $dupFiles += $i.Name
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
$backupFolders = $backupFolders | Sort -Unique
$backupFolders
"Moved files - " + $moveFiles.count
"Duplicate files - " + $dupFiles.count