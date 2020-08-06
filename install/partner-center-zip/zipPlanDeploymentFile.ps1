# this script file creates the app.zip file to be uploaded for each Offer > Plan in Partner Center
# the output goes to the partner-cetner-config folder

$destinationPath = "../partner-center-config/app.zip"

Remove-Item -Path $destinationPath

$compress = @{
    Path = "./*.json", "./nestedtemplates/"
    CompressionLevel = "Fastest"
    DestinationPath = $destinationPath
  }
  Compress-Archive @compress