<#
1. Remove dup .jpgs
2. Convert to .dng

https://wwwimages2.adobe.com/content/dam/acom/en/products/photoshop/pdfs/dng_commandline.pdf

"C:\Program Files (x86)\Adobe\Adobe DNG Converter.exe" -fl -d <directory> sourcepath

    2.1 Remove .srws
3. Rename using exiftool and stayopen option
C:\ProgramData\chocolatey\bin\exiftool.exe 'C:\Users\John\Pictures\From Camera' -json -r -EXT DNG JPG -Model > C:\Users\John\Pictures\From Camera\Temp\all_exif.json

# Load the exifdata to a variable for further manipulation
$exif = (get-content C:\temp\all_exif.json | ConvertFrom-Json)

4. Copy to NAS
5. Backup to Cloud
#>

# 1. REMOVE DUP JPGS
# Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy Unrestricted
#

$path = "C:\Users\John\Pictures\From Camera"
$dupPath = $path + "\" + "Dups"
$convertedPath = $path + "\" + "ConvertedToDNG"

$jpg = Get-ChildItem $path -Filter *.jpg
$srw = Get-ChildItem $path -Filter *.srw

$dups = Compare-Object $jpg.basename $srw.basename -ExcludeDifferent -IncludeEqual -PassThru
# | Where { $_.SideIndicator -eq '==' } 
$dups

foreach($i in $dups)
{    
    $dupName = $path + "\\" + $i + ".jpg"
    Move-Item -Path $dupName -Destination $dupPath
}

# 2. CONVERT TO DNG
# load DNG Converter GUI, wait for exit...
$dngConverter = Start-Process -FilePath "C:\Program Files (x86)\Adobe\Adobe DNG Converter.exe" -Wait -PassThru
$dngConverter.ExitCode

# 2.1. REMOVE SRWS
foreach($i in $srw)
{
    Move-Item $i.FullName -Destination $convertedPath
}

# 3. RENAME USING EXIFTOOLS
$jpg = Get-ChildItem $path -Filter *.jpg
$dng = Get-ChildItem $path -Filter *.dng
$images = $jpg + $dng

# create Exiftool process
$psi = New-Object System.Diagnostics.ProcessStartInfo;
$psi.FileName = "C:\ProgramData\chocolatey\bin\exiftool.exe"
$psi.Arguments = "-stay_open True -@ -"; # note the second hyphen
$psi.UseShellExecute = $false
$psi.RedirectStandardInput = $true
$psi.RedirectStandardOutput = $true
$psi.RedirectStandardError = $true
$exifTool = [System.Diagnostics.Process]::Start($psi)

foreach($i in $images)
{
$imageNumber = $i.Name.Substring(4,4)
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
$readyOut = $exiftool.StandardOutput.ReadLine()
$newName = $exifModel + "_" + $exifDTO.ToString("yyyy-MM-dd") + "_" + $exifDTO.ToString("HHmm") + "_" + $imageNumber + $i.Extension
#rename
$i = Rename-Item -path $i.FullName -NewName $newName -PassThru

#copy
$newPath = $NASpath + $exifDTO.ToString("yyyy") + "\" +$exifDTO.ToString("yyyy-MM-MMMM")
$j = Copy-Item -Path $i.FullName -Destination $newPath -PassThru
$j
}

# send command to shutdown
$exifTool.StandardInput.WriteLine("-stay_open")
$exifTool.StandardInput.WriteLine("False")

# wait for process to exit and output STDIN and STDOUT
#$exifTool.StandardError.ReadToEnd()
#$exifTool.StandardOutput.ReadToEnd()
$exifTool.WaitForExit()

