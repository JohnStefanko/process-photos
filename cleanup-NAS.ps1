copy-Dng


function remove-CaptureOne {
    param (
        #OptionalParameters
    )
    $captureoneFolders = Get-ChildItem -Path X:\data\Pictures\Album -Recurse -Directory -Filter "captureone"
    $captureoneFolders
    foreach ($folder in $captureoneFolders) {
        Remove-Item -Path $folder -Recurse -Force
        $folder.FullName
    }

}
function remove-Srw {
    param (
        #OptionalParameters
    )
    #$srw-files = Get-ChildItem -Path X:\Data\Pictures\Album -Recurse -Filter *.srw
    Remove-Item -Path X:\Data\Pictures\Album -Filter *.srw -Recurse
}

function copy-Psd {
    param (
        #OptionalParameters
    )
    $psdFiles = Get-ChildItem -Path X:\Data\Pictures\Album -Filter *.psd -Recurse
    foreach ($psdFile in $psdFiles) {

        Copy-Item -Path $psdFile.FullName -Destination P:\Data\Pictures\Studio\psd
    }

}


function copy-Dng {
    param (
        #OptionalParameters
    )
    $files = Get-ChildItem -Path X:\Data\Pictures\Album -Filter *.dng -Recurse
    foreach ($file in $files) {
        $file.FullName
        Copy-Item -Path $file.FullName -Destination P:\Data\Pictures\Studio\psd
    }

}