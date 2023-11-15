<#


#>

$newyear = "2024"
if ($newyear -eq "") {
    $newyear = (Get-Date).Year
}
#$path = "C:\Users\John\Pictures\Test\darktable"
#$path = "X:\Data\Pictures"
$albumPath = "P:\Data\Pictures\Album"
$studioPath = "P:\Data\Pictures\Studio"
$archivePath = "S:\Data\Pictures\Archive"

$yearAlbumPath = Join-Path -Path $albumPath -ChildPath $newyear
$yearArchivePath = Join-Path -Path $archivePath -ChildPath $newyear
$yearStudioPath = Join-Path -Path $studioPath -ChildPath $newyear
if(!(Test-Path $albumPath))
{
    "Drive not mapped!"
    Exit
}

if(!(Test-Path -Path $yearAlbumPath ))
{
    New-Item -ItemType directory -Path $yearAlbumPath
}

if(!(Test-Path -Path $yearArchivePath ))
{
    New-Item -ItemType directory -Path $yearArchivePath
}

if(!(Test-Path -Path $yearStudioPath ))
{
    New-Item -ItemType directory -Path $yearStudioPath
}


for($m=1; $m -le 12; $m++)
{
    $month = ([datetime]"$m/1/$newyear").ToString("yyyy-MM-MMMM")
    $newAlbumMonth = Join-Path -Path $yearAlbumPath -ChildPath $month
    $newArchiveMonth = Join-Path -Path $yearArchivePath -ChildPath $month
    $newStudioMonth = Join-Path -Path $yearStudioPath -ChildPath $month
    if(!(Test-Path -Path $newAlbumMonth ))
    {
        New-Item -ItemType directory -Path $newAlbumMonth
    }
    if(!(Test-Path -Path $newArchiveMonth ))
    {
        New-Item -ItemType directory -Path $newArchiveMonth
    }
    if(!(Test-Path -Path $newStudioMonth ))
    {
        New-Item -ItemType directory -Path $newStudioMonth
    }

}
