# ----------------------------------------------------------------------------------------------------
# Do not run this script until you have changed the pid-GUID as directed int the documentation
# ----------------------------------------------------------------------------------------------------
# this script file creates the app.zip file to be uploaded for each Offer > Plan in Partner Center
# the output file goes to the "partner-center-config/app.zip" folder
# this script ensure no OS files are included from non-Windows systems
# ----------------------------------------------------------------------------------------------------

$destinationPath = "../partner-center-config/app.zip"

if(Test-Path $destinationPath) {
  Remove-Item -Path $destinationPath
}

$compress = @{
    Path = "../partner-center-zip/*.json"
    CompressionLevel = "Fastest"
    DestinationPath = $destinationPath
  }
  Compress-Archive @compress