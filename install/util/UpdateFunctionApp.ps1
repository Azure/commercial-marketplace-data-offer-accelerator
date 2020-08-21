$destinationPath = "../publisher-azure/functionapp/functionapp.zip"
$resourceGroup = "<your resource group>"
$functionAppName = "<your function app>"

if (Test-Path "../publisher-azure/functionapp/functionapp.zip") {
  Remove-Item -Path $destinationPath
}

$compress = @{
  Path             = "../../powershell-data-function/*.json", "../../powershell-data-function/*.p*1", "../../powershell-data-function/resource"
  CompressionLevel = "Fastest"
  DestinationPath  = $destinationPath
}
Compress-Archive @compress

$updateApp = $false;
if (!(Get-Module -ListAvailable Az.Websites))
{
  Write-Host "Powershell module Az.Websites is required to update the function app. Please approve the UAC prompt in the next step."
  Read-Host -Prompt "Press enter to continue"
  $processInfo = Start-Process -FilePath "powershell.exe" -Args "Install-Module Az.Websites -MinimumVersion 1.11.0" -Verb runas -PassThru
  $processInfo.WaitForExit()
  $updateApp = $true
}
else {
  $updateApp = $true
}

if ($updateApp)
{
  Write-Host "Updating function app..."
  if ( "[environment]::OSVersion.Platform" -eq "Unix")
  {
    Start-Process -FilePath "pwsh" -Args "-Command Publish-AzWebapp -ResourceGroupName $resourceGroup -Name $functionAppName -ArchivePath (Resolve-Path $destinationPath).Path -Force"
  } else {
    Start-Process -FilePath "powershell.exe" -Args "Publish-AzWebapp -ResourceGroupName $resourceGroup -Name $functionAppName -ArchivePath (Resolve-Path $destinationPath).Path -Force"
  }
}



