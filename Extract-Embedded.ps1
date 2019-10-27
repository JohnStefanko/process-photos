$path = "C:\Users\John\Pictures\NX300"
$images = @()
$images = Get-ChildItem $path -Filter *.srw

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
$jpgPath = Join-Path -Path $path -ChildPath ($i.BaseName + ".JPG")
$exiftool.StandardInput.WriteLine("-b")
$exiftool.StandardInput.WriteLine("-jpgfromraw")
$exiftool.StandardInput.WriteLine("-w")
$exiftool.StandardInput.WriteLine(".JPG")
$exiftool.StandardInput.WriteLine("$imagePath")
$exiftool.StandardInput.WriteLine("-execute")
$exiftool.StandardInput.WriteLine("-tagsfromfile")
$exiftool.StandardInput.WriteLine("$imagePath")
$exiftool.StandardInput.WriteLine("$jpgPath")
$exiftool.StandardInput.WriteLine("-execute")


$l = $exiftool.StandardOutput.ReadLine()
$l = $exiftool.StandardOutput.ReadLine()
# end image loop
}

# send command to shutdown
$exiftool.StandardInput.WriteLine("-stay_open")
$exiftool.StandardInput.WriteLine("False")

# wait for process to exit and output STDIN and STDOUT
#$exiftool.StandardError.ReadToEnd()
#$exiftool.StandardOutput.ReadToEnd()
$exiftool.WaitForExit()