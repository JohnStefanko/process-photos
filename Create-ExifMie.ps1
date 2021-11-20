<#
.SYNOPSIS
    Test exiftool mie sidecar creation

.DESCRIPTION
    Assumes Exiftool is installed via Chocolatey at "C:\ProgramData\chocolatey\bin\exiftool.exe."

.PARAMETER Path
    none

.INPUTS
    none

.OUTPUTS
    none

.EXAMPLE
    none

.LINK
    References: 
    exiftool stay_open: https://exiftool.org/exiftool_pod.html#Advanced-options

#>

$path = "P:\Data\Pictures\From Camera\a6000"
#"C:\Users\John\Pictures\iCloud Photos\Downloads"
#"C:\Users\John\Pictures\iCloud Photos\Downloads\dups"
#"P:\Data\Pictures\From Camera\a6000"
$images = @()

$jpg = Get-ChildItem $path -Filter *.jpg
$arw = Get-ChildItem $path -Filter *.arw
$images = $arw #+ $jpg

# create Exiftool process
$psi = New-Object System.Diagnostics.ProcessStartInfo
$psi.FileName = "C:\ProgramData\chocolatey\bin\exiftool.exe"
$psi.Arguments = "-stay_open True -@ -"; # note the second hyphen
$psi.UseShellExecute = $false
$psi.RedirectStandardInput = $true
$psi.RedirectStandardOutput = $true
$psi.RedirectStandardError = $true

$exiftool = [System.Diagnostics.Process]::Start($psi)

foreach($i in $images)
{
$imagePath = $i.FullName
$miePath = $imagePath + ".mie"
#$imagePath
# enter exiftool parameters
$exiftool.StandardInput.WriteLine("-tagsFromFile")
$exiftool.StandardInput.WriteLine("$imagepath")
$exiftool.StandardInput.WriteLine("-all:all")
$exiftool.StandardInput.WriteLine("-icc_profile")
$exiftool.StandardInput.WriteLine("$miePath")
$exiftool.StandardInput.WriteLine("-execute")
$exiftoolOut = $exiftool.StandardOutput.ReadLine()
$exiftoolOut

# end image loop
}

# send command to shutdown
$exiftool.StandardInput.WriteLine("-stay_open")
$exiftool.StandardInput.WriteLine("False")

# wait for process to exit and output STDIN and STDOUT
#$exiftool.StandardError.ReadToEnd()
#$exiftool.StandardOutput.ReadToEnd()
$exiftool.WaitForExit()