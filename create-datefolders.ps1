<#


#>
$newyear = "2014"
$NASpath = "X:\Data\Pictures"
$yearAlbumPath = Join-Path -Path $NASpath -ChildPath "Album" -AdditionalChildPath $newyear
$yearRawPath = Join-Path -Path $NASpath -ChildPath "Raw" -AdditionalChildPath $newyear
if(!(Test-Path $NASpath))
{
    "NAS drive not mapped!"
    Exit
}

if(!(Test-Path -Path $yearAlbumPath ))
{
    New-Item -ItemType directory -Path $yearAlbumPath
}

if(!(Test-Path -Path $yearRawPath ))
{
    New-Item -ItemType directory -Path $yearRawPath
}


for($m=1; $m -le 12; $m++)
{
    $month = ([datetime]"$m/1/$newyear").ToString("yyyy-MM-MMMM")
    $newAlbumMonth = Join-Path -Path $yearAlbumPath -ChildPath $month
    $newRawMonth = Join-Path -Path $yearRawPath -ChildPath $month
    if(!(Test-Path -Path $newAlbumMonth ))
    {
        New-Item -ItemType directory -Path $newAlbumMonth
    }
    if(!(Test-Path -Path $newRawMonth ))
    {
        New-Item -ItemType directory -Path $newRawMonth
    }

}
