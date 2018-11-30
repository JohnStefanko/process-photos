# takes jpgs and

$path = "c:\users\john\Pictures\From Camera"
$NASpath = "X:\Data\Pictures\Album\"
$modelsPath = "X:\Data\_config\Pictures\EXIFmodels.txt"
if(!(Test-Path $NASpath))
{
    "NAS drive not mapped!"
    Exit
}
if(!(Test-NetConnection -Port 80 -InformationLevel Quiet))
{
    "Internet connection failed!"
    Exit
}
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

#copy
$newPath = $NASpath + $exifDTO.ToString("yyyy") + "\" +$exifDTO.ToString("yyyy-MM-MMMM")
if ((Test-Path $newPath))
{
    $j = Copy-Item -Path $i.FullName -Destination $newPath -PassThru
    $j
    $counterFileCopied = $counterFileCopied + 1
    #backup
    $psiCbb.Arguments = "backup -aid 13162194-d8a3-4f52-bc91-c2c09168c5a2 -c yes -ea aes128 -ep RqEUtqNbFgk8AkvwMq7Yf48k -f " + $j
    $cbb = [System.Diagnostics.Process]::Start($psiCbb)
    $cbb.WaitForExit()
    $cbb.StandardOutput.ReadLine()
    $cbb.StandardOutput.ReadLine()
    $cbb.StandardOutput.ReadLine()
    $cbb.StandardOutput.ReadLine()
    $cbbOut = $cbb.StandardOutput.ReadLine()
    if ($cbbOut = "No files for backup found")
    {
        #backup failed, save local
        $j
        $cbbOut
        $cbb.StandardOutput.ReadToEnd()
        $cbb.WaitForExit()
    }
    else
    {
        #backup success, remove local
        $cbbOut = $cbb.StandardOutput.ReadLine()
        $cbbOut
        Remove-Item -path $i.FullName
        $cbb.StandardOutput.ReadToEnd()
        $cbb.WaitForExit()
    }
}
else {
    $counterFileExists = $counterFileExists + 1
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
