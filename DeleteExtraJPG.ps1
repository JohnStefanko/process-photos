<#
1. Remove dup .jpgs

#>

# 1. REMOVE DUP JPGS
# Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy Unrestricted
#
Add-Type -AssemblyName System.Windows.Forms
$browser = New-Object System.Windows.Forms.FolderBrowserDialog -Property @{
    #SelectedPath = 'X:\Data\Pictures\From Camera\NX300'
    SelectedPath = 'c:\users\john\Pictures\From Camera'
}
$browser.Description = "Photos to process?"
$null = $browser.ShowDialog()
$path = $browser.SelectedPath
$dupPath = $path + "\" + "Dups"

$jpg = Get-ChildItem $path -Filter *.jpg
$srw = Get-ChildItem $path -Filter *.srw

$dups = Compare-Object $jpg.basename $srw.basename -ExcludeDifferent -IncludeEqual -PassThru
# | Where { $_.SideIndicator -eq '==' } 
$dups

foreach($i in $dups)
{
    $dupName = $path + "\\" + $i + ".jpg"
    Move-Item -Path $dupName -Destination $dupPath
}


