
$cApplicationName = "<Client Managed Application Name>"
$cResourceGroup = "<Client Resource Group Name>"
$cSubscription = "<Client Subscription ID>"
$planName = "<ID of the Plan in Partner Center>"
$functionUri = "<function URL>/api/resource>"
$appVersion = "<Version of the .zip file from your Partner Center Plan>"
$publisher = "<Could be anything really>"
$applicationId = "/subscriptions/$cSubscription/resourceGroups/$cResourceGroup/providers/Microsoft.Solutions/applications/$cApplicationName"

$body = @{
  "plan" = @{
    "name"      = $planName
    "publisher" = $publisher
    "product"   = "azure_app_sample-preview"
    "version"   = $appVersion
  }
  "eventType"         = "PUT"
  "applicationId"     = $applicationId
  "provisioningState" = "Succeeded"
  "eventTime"         = Get-Date
} | ConvertTo-Json

Write-Host ===========================================================
Write-Host Request Body
Write-Host ===========================================================
Write-Host $body
Write-Host ===========================================================

$response = Invoke-RestMethod -Method Post -Uri $functionUri -Body $body -ContentType "application/json" 

Write-Host =======================RESPONSE============================
Write-Host ($response | ConvertTo-Json)
Write-Host =======================RESPONSE============================