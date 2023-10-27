<#
.SYNOPSIS
    Loop through \studio to create compressed jpgs for \album

.DESCRIPTION
    Originally, I didn't create jpgs for culled photos moved to \studio, so there was no jpg in \album until I edited them. Now, the original jpg will be added to \album by default.
    Uses imagemagick for compression

.PARAMETER Path
    Path to folder with images to be processed.

.INPUTS
    Path of photos to process.

.OUTPUTS
    

.EXAMPLE
    UtilCreateAlbumJpg

.LINK
    References: 
#>
#
$years = "2014", "2015", "2016", "2017", "2018", "2019", "2020", "2021", "2022"
#"2006", "2007", "2008", "2009", "2010", "2011", "2012", "2013"
#"2002", "2003", "2004", "2005"
#"2018", "2019", "2020", "2021", "2022"
$processRootPath = "P:\Data\Pictures\Studio"
$picturesRootPath = "P:\Data\Pictures"
$picturesAlbumPath = "P:\Data\Pictures\Album"
$currentDateTime = Get-Date -Format "yyyy-MM-dd-HHmm"
$logFilePath = Join-Path $processRootPath -ChildPath "$currentDateTime.txt"
$logCompressFiles = Join-Path $processRootPath -ChildPath "compressfiles $currentDateTime.txt"
$years >> $logFilePath

$magickPath = "C:\Program Files\ImageMagick-7.1.1-Q16-HDRI\magick.exe"
if (!(Test-Path -Path $magickPath)) {
    Write-Output "magick not found"
    Exit
}
$magickArgs = "-compress", "JPEG", "-quality", "70","-sampling-factor", "4:2:2"

$studioFolders = @()
$jpgFiles = @()

foreach ($year in $years) {
    Write-Output $year
    $processYearPath = Join-Path -Path $processRootPath $year
    $processMonthPaths = Get-ChildItem -Path $processYearPath -Directory
    foreach ($processPath in $processMonthPaths) {
        #debug specific month
        #$archivePath = "P:\Data\Pictures\Archive\2014\2014-07-July"
        $processPath.FullName >> $logFilePath
        $month = Split-Path -Path $processPath -Leaf
        $folderYear = $year
        $folderMonth = $month
        #if ($folderMonth -eq "2018-08-August") {
        #    Continue 
        #}
        $jpgFiles = @()
        $jpgFiles = Get-ChildItem $processPath -Filter *.jpg

        # loop through all image basenames
        foreach ($jpgFile in $jpgFiles) {
            #copy jpg to \album
            $jpgFilePath = $jpgFile.FullName
            $destinationPath = Join-Path -Path $picturesAlbumPath -ChildPath $folderYear $folderMonth 
            $destinationFilePath = Join-Path $destinationPath -ChildPath $jpgFile.Name

            if ((Test-Path -Path $destinationFilePath)) {
                Write-Output $destinationFilePath " already exists"
            }
            else {
                if ($jpgFile.Length -gt 2MB) {
                    #compress jpg
                    $destinationMagickPath = Join-Path -Path $destinationPath -ChildPath $jpgFile.Name
                    & $magickPath $jpgFilePath $magickArgs $destinationMagickPath
                    $jpgFilePath >> $logCompressFiles
                }
                <# Action when all if and elseif conditions are false #>
                else {
                    #copy jpg
                    Copy-Item -Path $jpgFilePath -Destination $destinationPath
                }
                Write-Output $jpgFilePath " added to album"
            }
        #files loop
        }
    # month loop
    }
# year loop
}

$studioFolders = $studioFolders | Sort-Object -Unique
Set-Content -path (Join-Path -Path $processRootPath -ChildPath "studiofolders $currentDateTime.txt") -Value $studioFolders