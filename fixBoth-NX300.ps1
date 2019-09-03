<#

ASSUMES:
1. have both .srw, .jpg

STEPS:
1. rename
2. move to location
3. delete .dng

#>
$rawPath = "X:\Data\Pictures\Raw\2018"
$albumPath = "X:\Data\Pictures\Album\2018"
$path = "X:\Data\Pictures\Raw\NX300\both"
$dupPath = "X:\Data\Pictures\Raw\NX300\both\dup"
$NASpath = "X:\Data\Pictures"
$moveFiles = @()
$images = @()
$backupFolders = @()
if(!(Test-Path $NASpath))
{
    "NAS drive not mapped!"
    Exit
}

$jpg = Get-ChildItem $path -Recurse -Filter *.jpg
$raw = Get-ChildItem $path -Recurse -Filter *.srw
$images = $jpg + $raw

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
    $model = "NX300"
    $imageNumber = $i.Name.Substring(4,4)
    $folderYear = $exifDTO.ToString("yyyy")
    $folderMonth = $exifDTO.ToString("yyyy-MM-MMMM")
    $newName = $model + "_" + $exifDTO.ToString("yyyy-MM-dd") + "_" + $exifDTO.ToString("HHmm") + "_" + $imageNumber + $i.Extension
    #rename with EXIF data
    $i = Rename-Item -path $i.FullName -NewName $newName -PassThru

    if ($i.Extension -eq ".srw") {
        $folderMain = "Raw" 
        $newPath = Join-Path -path $NASpath -ChildPath $folderMain $folderYear $folderMonth
        # Google Photos can't see .srw, so can't use in Picasa 
    }
    else {
        $folderMain = "Album"
        $newPath = Join-Path -path $NASpath -ChildPath $folderMain $folderYear $folderMonth
        $dngFile = Join-Path -Path $newPath -ChildPath ($i.BaseName + ".dng")
        Remove-Item -Path $dngFile
        $picasaIni = Join-Path -path $newPath -ChildPath ".picasa.ini"
        $section = "\[" + $i.BaseName + ".DNG\]"
        $newsection = "[" + $i.BaseName + ".JPG]"
        (Get-Content -Path $picasaIni) | ForEach-Object {$_ -replace "$section", "$newsection"} | Set-Content -Path $picasaIni
    }

    #check if exists, if so > dup
    if (!(Test-Path (Join-Path -Path $newPath -ChildPath $newName) ))
    {
        $j = Move-Item -Path $i.FullName -Destination $newPath -PassThru
        $moveFiles += $j.FullName
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
$backupFolders = $backupFolders | Sort-Object -Unique
Set-Content -path (Join-Path -Path $path -ChildPath "backupfolders.txt") -Value $backupFolders
$backupFolders
Set-Content -path (Join-Path -Path $path -ChildPath "movedfiles.txt") -Value $moveFiles.count
Add-Content -path (Join-Path -Path $path -ChildPath "movedfiles.txt") -Value $moveFiles
"Moved files - " + $moveFiles.count
Set-Content -path (Join-Path -Path $path -ChildPath "dupfiles.txt") -Value $dupfiles.count
Add-Content -path (Join-Path -Path $path -ChildPath "dupfiles.txt") -Value $dupFiles
"Duplicate files - " + $dupFiles.count
