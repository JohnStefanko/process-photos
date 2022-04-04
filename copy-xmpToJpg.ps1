<#
.SYNOPSIS
    Process culled photos in local \Archive folder based on star rating ("-Rating")
        Label = "Blue": copy all to \Studio
        1: do nothing
        2, 3, 4, 5: copy jpg to local \Album

.DESCRIPTION
    Assumes Exiftool is installed via Chocolatey at "C:\ProgramData\chocolatey\bin\exiftool.exe."

.PARAMETER Path
    Path to folder with images to be processed.

.INPUTS
    Path of photos to process.

.OUTPUTS
    Create movedfiles.txt, dupfiles.txt, and backupfiles.txt showing which NAS folders need to be backed up.

.EXAMPLE
    Process-Photos -path C:\data\photos

.LINK
    References: 
    exiftool stay_open: https://exiftool.org/exiftool_pod.html#Advanced-options
    command to run while debugging: 
    taskkill /IM "exiftool.exe" /F
#>
$years = "2018"
#$years =  "2001", "2002", "2003", "2004", "2005", "2006", "2007", "2008", "2009", "2010", "2011", "2012", "2013", "2014", "2015", "2016", "2017", "2018", "2019", "2021", "2022"
#$years =  "2013", "2014", "2015", "2016", "2017", "2018", "2019", "2021", "2022"
$stopWatch = [system.diagnostics.stopwatch]::StartNew()
$imagesParentFolder = "Album"
$imagesRootPath = "P:\Data\Pictures"
#$currentDateTime = Get-Date -Format "yyyy-MM-dd-HHmm"
$currentDateTime = Get-Date -Format "yyyy-MM-dd-HH"
$logFilePath = Join-Path $imagesRootPath -ChildPath "$currentDateTime.txt"
$years >> $logFilePath

$exiftoolPath = "C:\ProgramData\chocolatey\bin\exiftool.exe"
if (!(Test-Path -Path $exiftoolPath)) {
    Write-Output "exiftool not found"
    Exit
}

$images = @()
$imageFiles = @()
$imageNumbers = @()
$startTime = $stopWatch.Elapsed.TotalSeconds
foreach ($year in $years) {
    $year >> $logFilePath
    $imagesYearPath = Join-Path -Path $imagesRootPath -ChildPath $imagesParentFolder $year
    $imagesMonthPaths = Get-ChildItem -Path $imagesYearPath -Directory
    foreach ($imagesPath in $imagesMonthPaths) {
        #debug specific month
        #$imagesPath = "P:\Data\Pictures\Archive\2014\2014-07-July"
        $imagesPath.FullName >> $logFilePath
        $month = Split-Path -Path $imagesPath -Leaf
        $folderYear = $year
        $folderMonth = $month
        $xmpFiles = Get-ChildItem -Path $imagesPath -Filter "*.xmp"
        $images = $xmpFiles.BaseName | Sort-Object | Get-Unique
        $i = 0

# loop through all image basenames
foreach ($image in $images) {
    # debug
    #$image >> $logFilePath
    $xmpFilePath = "" # for rating, label
    $exifFilePath = "" # for date time
    $exifRating = ""
    $exifLabel = ""
    $xmpFilePath = Join-Path $imagesPath -ChildPath "$image.xmp"
    if (!(Test-Path -Path $xmpFilePath)) {
        "ERROR: $xmpFilePath not found" >> $logFilePath
        Continue  
    }
    $jpgFilePath = Join-Path -path $imagesPath -ChildPath "$image.jpg"
    if (Test-Path -Path $jpgFilePath) {
        $jpgFile = Get-ChildItem -Path $jpgFilePath
    }
    else {
        #"ERROR: $jpgFilePath not found" >> $logFilePath
        $jpgFilePath >> $logFilePath
        Continue 
    }
    # create Exiftool process
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $exiftoolPath
    $psi.Arguments = "-stay_open True -@ -"; # note the second hyphen
    $psi.UseShellExecute = $false
    $psi.RedirectStandardInput = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $exiftool = [System.Diagnostics.Process]::Start($psi)
    #$exifToolID = $exiftool.Id
    
    #get rating from xmp
    $exiftool.StandardInput.WriteLine("-Rating")
    $exiftool.StandardInput.WriteLine("-s3")
    $exiftool.StandardInput.WriteLine("$xmpFilePath")
    $exiftool.StandardInput.WriteLine("-execute")
    $exiftoolOut = $exiftool.StandardOutput.ReadLine()
    #$exiftoolOut >> $logFilePath
    while ($exiftoolOut -ne "{ready}") {
        $exifRating = $exiftoolOut
        $exiftoolOut = $exiftool.StandardOutput.ReadLine()
    }
    #get label from xmp
    $exiftool.StandardInput.WriteLine("-Label")
    $exiftool.StandardInput.WriteLine("-s3")
    $exiftool.StandardInput.WriteLine("$xmpFilePath")
    $exiftool.StandardInput.WriteLine("-execute")
    $exiftoolOut = $exiftool.StandardOutput.ReadLine()
    #$exiftoolOut >> $logFilePath
    while ($exiftoolOut -ne "{ready}") {
        $exifLabel = $exiftoolOut
        $exiftoolOut = $exiftool.StandardOutput.ReadLine()
    }
    #write to jpg
    $exiftool.StandardInput.WriteLine("-Rating=$exifRating")
    if ($exifLabel -ne "") {
        $exiftool.StandardInput.WriteLine("-Label=$exifLabel")
    }
    $exiftool.StandardInput.WriteLine("-overwrite_original")
    $exiftool.StandardInput.WriteLine("$jpgFilePath")
    $exiftool.StandardInput.WriteLine("-execute")
    $exiftoolOut = $exiftool.StandardOutput.ReadLine()
    #$exiftoolOut >> $logFilePath
    while ($exiftoolOut -ne "{ready}") {
        $exiftoolOut = $exiftool.StandardOutput.ReadLine()
    }
    Rename-Item -Path $xmpFilePath -NewName "$xmpFilePath.txt"
    # send command to shutdown
    $exiftool.StandardInput.WriteLine("-stay_open")
    $exiftool.StandardInput.WriteLine("False")

    # wait for process to exit and output STDIN and STDOUT
    #$exiftool.StandardError.ReadToEnd()
    #$exiftool.StandardOutput.ReadToEnd()
    while ($exited -ne $true) {
        $exited = $exiftool.WaitForExit(10)
    }
    $i++
    #debug
    #"$exifToolID exited" >> $logFilePath
    $exited = $false

    #$stdout = $exiftool.StandardError.ReadToEnd()
    #$stdout

#images loop
}
# month loop
$endTime = $stopWatch.Elapsed.TotalSeconds
$runTime = $endTime - $startTime
$currentDateTime = Get-Date -Format "yyyy-MM-dd-HHmm:ss"
"  [$currentDateTime] $i images in $runTime seconds ("  + 60 * ($i / $runTime) + " per minute)">> $logFilePath
$startTime = $stopWatch.Elapsed.TotalSeconds
}
# year loop
}



