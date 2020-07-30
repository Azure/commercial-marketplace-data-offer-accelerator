
$cApplicationName = ""
$cResourceGroup = ""
$cSubscription = ""
$planName = ""
$functionUri = ""

$applicationId = "/subscriptions/$cSubscription/resourceGroups/$cResourceGroup/providers/Microsoft.Solutions/applications/$cApplicationName"

Write-Host "============================"
Write-Host "cApplicationName: $cApplicationName"
Write-Host "applicationId: $applicationId"
Write-Host "cResourceGroup: $cResourceGroup"
Write-Host "cSubscription: $cSubscription"
Write-Host "============================"

$body = @{
  "plan" = @{
    "name"      = $planName
    "publisher" = "elegantcodecom1583941477217"
    "product"   = "azure_app_sample-preview"
    "version"   = "1.0.8"
  }
  "eventType"         = "PUT"
  "applicationId"     = $applicationId
  "provisioningState" = "Succeeded"
  "eventTime"         = Get-Date
} | ConvertTo-Json

$response = Invoke-RestMethod -Method Post -Uri $functionUri -Body $body -ContentType "application/json" 

Write-Host "===== FUNCTION REPONSE ====="
Write-Host ($response | ConvertTo-Json)
Write-Host "===== FUNCTION REPONSE ====="