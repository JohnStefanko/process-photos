<#
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

$path = "C:\Users\John\Pictures\From Camera"
$convertedPath = $path + "\" + "ConvertedToDNG"

$jpg = Get-ChildItem $path -Filter *.jpg
$srw = Get-ChildItem $path -Filter *.srw

# 2. CONVERT TO DNG
# load DNG Converter GUI, wait for exit...
$dngConverter = Start-Process -FilePath "C:\Program Files (x86)\Adobe\Adobe DNG Converter.exe" -Wait -PassThru
$dngConverter.ExitCode

# 2.1. REMOVE SRWS
foreach($i in $srw)
{
    Move-Item $i.FullName -Destination $convertedPath
}
