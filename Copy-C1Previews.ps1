<#
.SYNOPSIS
    Copy Capture One preview files from Catalog to Session folders.

.DESCRIPTION
    Copy Capture One preview files from Catalog to Session folders.

.PARAMETER Path
    Path to folder with images to be renamed

.INPUTS
    None. You cannot pipe objects to Add-Extension.

.OUTPUTS
    None.

.EXAMPLE
    Copy-C1Previews -path C:\data\C1-Catalog

.LINK
    None.
#>
[CmdletBinding()]
param (
    [Parameter(Mandatory=$true,HelpMessage="Enter path for C1 catalog")]
    [string]
    $path
)
$moveFiles = @()
$nasPath = "X:\Data\Pictures\Album"
if(!(Test-Path $nasPath))
{
    "NAS drive not mapped!"
    Exit 0
}
$cachePath = Join-Path -Path $path -ChildPath "Cache" 
if (!(Test-Path $cachePath)) {
    "Path provided is not a C1 Catalog (path has no \Cache folder)."
    Exit 0
}

$previewFiles = @(Get-ChildItem -Path $cachePath -Filter *.cop -Recurse)
$filterFiles = @(Get-ChildItem -Path $cachePath -Filter *.cof -Recurse)
$copyfiles = $previewFiles + $filterFiles
$copyfiles | Measure-Object
foreach ($file in $copyFiles) {
    $year = (($file.name -split "_")[1] -split "-")[0]
    $month = (($file.name -split "_")[1] -split "-")[1]
    if ([INT]$year -ge 2000 -and [INT]$year -le 2099) {
        $monthFolder = ([datetime]"$month/1/$year").ToString("yyyy-MM-MMMM")
        $copyFolder = Join-Path -path $nasPath -ChildPath "$year\$monthFolder\CaptureOne\Cache\Proxies"
        if (!(Test-Path $copyfolder)) {
            $newFolder = New-Item -ItemType Directory $copyFolder
            $newFolder.FullName
        }
        if (Test-Path (Join-Path $copyFolder -ChildPath $file)) {
            continue            
        }
        Copy-Item -Path $file.FullName -Destination $copyFolder -PassThru
    }
}
