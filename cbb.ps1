<#
Name: 'Backblaze-b2' 
ID: '13162194-d8a3-4f52-bc91-c2c09168c5a2'. 

cbb backup -aid 13162194-d8a3-4f52-bc91-c2c09168c5a2 -f "X:\Data\Pictures\Album\one.txt" -c yes -ea aes128 -ep XXXXXXXXXXX
-c = compress
-ep = password
-aid = cloudberry account ID

if backed up -> "No files for backup found"

CloudBerry Backup Desktop Edition Command Line Interface started
   Compress files: True
   Encryption algorithm is set to AES, key size 128
   Encryption password is set to '******'
>File to backup count: 1 (6 bytes)
'X:\Data\Pictures\Album\one.txt' copied
Uploaded 1 files
Failed to upload 0 files
Elapsed time: 00:00:00

CloudBerry Backup Desktop Edition Command Line Interface started
   Compress files: True
   Encryption algorithm is set to AES, key size 128
   Encryption password is set to '******'
>No files for backup found

cbb.exe list -a Backblaze-b2 -f X:\Data\Pictures\Album\2018\SAM_3606.JPG 

1CloudBerry Backup Desktop Edition Command Line Interface started
2   Connection settings is OK
3ERROR: File 'X:\Data\Pictures\Album\2018\2018-01-January\NX300_2018-01-29_3602.JPG' was not found


1CloudBerry Backup Desktop Edition Command Line Interface started
2   Connection settings is OK
3Versions of file X:\Data\Pictures\Album\2018\2018-01-January\NX300_2018-01-29_3603.JPG:
4   1/29/2018 8:41 PM            9062560 NX300_2018-01-29_3603.JPG (compressed, encrypted)

1 CloudBerry Backup Desktop Edition Command Line Interface started
2    Compress files: True
3    Encryption algorithm is set to AES, key size 128
4    Encryption password is set to '******'
5 File to backup count: 1 (6 bytes)
6 'X:\Data\Pictures\Album\three.txt' copied
7 Uploaded 1 files
8 Failed to upload 0 files
9 Elapsed time: 00:00:00

1 CloudBerry Backup Desktop Edition Command Line Interface started
2    Compress files: True
3    Encryption algorithm is set to AES, key size 128
4    Encryption password is set to '******'
5 No files for backup found
#>


#$psiCbb = New-Object System.Diagnostics.ProcessStartInfo
$psiCbb = New-Object System.Diagnostics.ProcessStartInfo("C:\Program Files\CloudBerryLab\CloudBerry Backup\cbb.exe")
#$psiCbb.FileName = "C:\Program Files\CloudBerryLab\CloudBerry Backup\cbb.exe"
$psiCbb.UseShellExecute = $false
$psiCbb.CreateNoWindow = $true
$psiCbb.RedirectStandardOutput = $true

$psiCbb.Arguments = "backup -aid 13162194-d8a3-4f52-bc91-c2c09168c5a2 -c yes -ea aes128 -ep XXXXXXXXXXXXXXXX -f X:\Data\Pictures\Album\2018\SAM_3606.JPG"
$cbb = [System.Diagnostics.Process]::Start($psiCbb)
$cbb.WaitForExit()
$cbb.StandardOutput.ReadLine()
$cbb.StandardOutput.ReadLine()
$cbb.StandardOutput.ReadLine()
$cbb.StandardOutput.ReadLine()
$cbb.StandardOutput.ReadLine()
$cbb.StandardOutput.ReadLine()
$cbb.StandardOutput.ReadLine()
Exit

$cbbOut = $cbb.StandardOutput.ReadLine()
if ($cbbOut = "No files for backup found") 
{
    $cbbOut
}
else 
{
    $cbbOut = $cbb.StandardOutput.ReadLine()
    $cbbOut
}
$cbb.StandardOutput.ReadToEnd()


