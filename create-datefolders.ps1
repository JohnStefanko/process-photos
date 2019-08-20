<#


#>
$newyear = "2016"
$NASpath = "X:\Data\Pictures"
$yearAlbumPath = Join-Path -Path $NASpath -ChildPath "Album" -AdditionalChildPath $newyear
$yearOriginalPath = Join-Path -Path $NASpath -ChildPath "Original" AdditionalChildPath $newyear
if(!(Test-Path $NASpath))
{
    "NAS drive not mapped!"
    Exit
}

if(!(Test-Path -Path $yearAlbumPath ))
{
    New-Item -ItemType directory -Path $yearAlbumPath
}

if(!(Test-Path -Path $yearOriginalPath ))
{
    New-Item -ItemType directory -Path $yearOriginalPath
}


for($m=1; $m -le 12; $m++)
{
    $month = ([datetime]"$m/1/$newyear").ToString("yyyy-MM-MMMM")
    $newAlbumMonth = Join-Path -Path $yearAlbumPath -ChildPath $month
    $newOriginalMonth = Join-Path -Path $yearOriginalPath -ChildPath $month
    if(!(Test-Path -Path $newAlbumMonth ))
    {
        New-Item -ItemType directory -Path $newAlbumMonth
    }
    if(!(Test-Path -Path $newOriginalMonth ))
    {
        New-Item -ItemType directory -Path $newOriginalMonth
    }

}
