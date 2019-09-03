<#

comment
#>
$year = "2019"
$path = $env:OneDrive
$rawPath = Join-Path -path "X:\Data\Pictures\Raw\" $year
$albumPath = Join-Path -path "X:\Data\Pictures\Album\" $year
$NASpath = "X:\Data\Pictures"
$moveFiles = @()
$images = @()
if(!(Test-Path $NASpath))
{
    "NAS drive not mapped!"
    Exit
}

$jpg = Get-ChildItem $rawPath -Recurse -Filter *.jpg
$raw = Get-ChildItem $albumPath -Recurse -Filter *.arw

foreach($i in $jpg)
{
    $lastPath = Split-Path $i.Directory -Leaf
    $newPath = Join-Path -Path $albumPath -ChildPath $lastPath
    $j = Move-Item -Path $i.FullName -Destination $newPath -PassThru
    $moveFiles += $j.FullName
    $backupFolders += $newPath.ToString()
    
# end image loop
}

foreach($i in $raw)
{
    $lastPath = Split-Path $i.Directory -Leaf
    $newPath = Join-Path -Path $rawPath -ChildPath $lastPath
    $j = Move-Item -Path $i.FullName -Destination $newPath -PassThru
    $moveFiles += $j.FullName
    $backupFolders += $newPath.ToString()
    
# end image loop
}

$backupFolders = $backupFolders | Sort-Object -Unique
Set-Content -path (Join-Path -Path $path -ChildPath "backupfolders.txt") -Value $backupFolders
$backupFolders
Set-Content -path (Join-Path -Path $path -ChildPath "movedfiles.txt") -Value $moveFiles.count
Add-Content -path (Join-Path -Path $path -ChildPath "movedfiles.txt") -Value $moveFiles
"Moved files - " + $moveFiles.count

