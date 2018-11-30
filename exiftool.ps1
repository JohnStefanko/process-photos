# takes jpgs and

$path = "c:\users\john\Pictures\From Camera\"
$NASpath = "X:\Data\Pictures\Album\"
$modelsPath = "X:\Data\_config\Pictures\EXIFmodels.txt"
if(!(Test-Path $NASpath))
{
    "NAS drive not mapped!"
    Exit
}

$models = Get-Content -Raw $modelsPath | ConvertFrom-StringData
$jpg = Get-ChildItem $path -Filter *.jpg
$dng = Get-ChildItem $path -Filter *.dng
$images = $jpg + $dng

# create Exiftool process
$psi = New-Object System.Diagnostics.ProcessStartInfo
$psi.FileName = "C:\ProgramData\chocolatey\bin\exiftool.exe"
$psi.Arguments = "-stay_open True -@ -"; # note the second hyphen
$psi.UseShellExecute = $false
$psi.RedirectStandardInput = $true
$psi.RedirectStandardOutput = $true
$psi.RedirectStandardError = $true

$exiftool = [System.Diagnostics.Process]::Start($psi)

$psiCbb = New-Object System.Diagnostics.ProcessStartInfo("C:\Program Files\CloudBerryLab\CloudBerry Backup\cbb.exe")
$psiCbb.UseShellExecute = $false
$psiCbb.CreateNoWindow = $true
$psiCbb.RedirectStandardOutput = $true

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
    Default {"0000"}
}
$newName = $model + "_" + $exifDTO.ToString("yyyy-MM-dd") + "_" + $exifDTO.ToString("HHmm") + "_" + $imageNumber + $i.Extension
#rename with EXIF data
$i = Rename-Item -path $i.FullName -NewName $newName -PassThru

# end image loop
}

# send command to shutdown
$exiftool.StandardInput.WriteLine("-stay_open")
$exiftool.StandardInput.WriteLine("False")

# wait for process to exit and output STDIN and STDOUT
#$exiftool.StandardError.ReadToEnd()
#$exiftool.StandardOutput.ReadToEnd()
$exiftool.WaitForExit()
