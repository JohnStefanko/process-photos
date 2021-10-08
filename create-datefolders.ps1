<#


#>
$newyear = "2021"
#$NASpath = "P:\Data\Pictures"
$NASpath = "C:\Users\John\Pictures\Test\darktable"
$yearAlbumPath = Join-Path -Path $NASpath -ChildPath "Album" -AdditionalChildPath $newyear
$yearArchivePath = Join-Path -Path $NASpath -ChildPath "Archive" -AdditionalChildPath $newyear
if(!(Test-Path $NASpath))
{
    "NAS drive not mapped!"
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


for($m=1; $m -le 12; $m++)
{
    $month = ([datetime]"$m/1/$newyear").ToString("yyyy-MM-MMMM")
    $newAlbumMonth = Join-Path -Path $yearAlbumPath -ChildPath $month
    $newArchiveMonth = Join-Path -Path $yearArchivePath -ChildPath $month
    if(!(Test-Path -Path $newAlbumMonth ))
    {
        New-Item -ItemType directory -Path $newAlbumMonth
    }
    if(!(Test-Path -Path $newArchiveMonth ))
    {
        New-Item -ItemType directory -Path $newArchiveMonth
    }

}
