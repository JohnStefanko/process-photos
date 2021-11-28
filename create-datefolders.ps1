<#


#>
$newyear = "2021"
#$path = "C:\Users\John\Pictures\Test\darktable"
$path = "X:\Data\Pictures"

$yearAlbumPath = Join-Path -Path $path -ChildPath "Album" -AdditionalChildPath $newyear
$yearArchivePath = Join-Path -Path $path -ChildPath "Archive" -AdditionalChildPath $newyear
$yearStudioPath = Join-Path -Path $path -ChildPath "Studio" -AdditionalChildPath $newyear
if(!(Test-Path $path))
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
