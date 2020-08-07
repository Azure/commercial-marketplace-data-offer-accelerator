# this script file creates the app.zip file to be uploaded for each Offer > Plan in Partner Center
# the "app.zip" output file goes to the "partner-center-config" folder

$destinationPath = "../partner-center-config/app.zip"

if(Test-Path "../partner-center-config/app.zip") {
  Remove-Item -Path $destinationPath
}

$compress = @{
    Path = "../partner-center-zip/*.json", "../partner-center-zip/nestedtemplates/"
    CompressionLevel = "Fastest"
    DestinationPath = $destinationPath
  }
  Compress-Archive @compress