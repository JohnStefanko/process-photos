$path = "X:\Data\Pictures\Raw\NX300"
$bothPath = "X:\Data\Pictures\Raw\NX300\both"

$images = @()

$jpg = Get-ChildItem $path -Filter *.jpg
$srw = Get-ChildItem $path -Filter *.srw
$both = Compare-Object $jpg.basename $srw.basename -ExcludeDifferent -IncludeEqual -PassThru | Where-Object { $_.SideIndicator -eq '==' } 
foreach($i in $both)
{
    $jpgName = Join-Path -Path $path -ChildPath ($i + ".JPG")
    $srwName = Join-Path -Path $path -ChildPath ($i + ".SRW")
    Move-Item -Path $jpgName -Destination $bothPath -PassThru
    Move-Item -Path $srwName -Destination $bothPath -PassThru
}
