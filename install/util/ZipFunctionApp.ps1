$destinationPath = "../publisher-azure/functionapp/functionapp.zip"

if (Test-Path "$destinationPath") {
  Remove-Item -Path $destinationPath
}

$compress = @{
  Path             = "../../powershell-data-function/*.json", "../../powershell-data-function/*.p*1", "../../powershell-data-function/resource"
  CompressionLevel = "Fastest"
  DestinationPath  = $destinationPath
}
Compress-Archive @compress