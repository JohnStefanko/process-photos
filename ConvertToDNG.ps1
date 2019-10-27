<#
https://wwwimages2.adobe.com/content/dam/acom/en/products/photoshop/pdfs/dng_commandline.pdf

"C:\Program Files (x86)\Adobe\Adobe DNG Converter.exe" -fl -d <directory> sourcepath
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
