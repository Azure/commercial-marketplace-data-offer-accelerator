# -------------------------------------------------------------
# This script is used to test the Azure function once it is already deployed and in place.
# It is used primarily for development purposes
# -------------------------------------------------------------
# Make a copy of this file named 'InvokeFunctionTest.ps1'. 
# Use that file to fill out the variable values and to run in test of the Azure function.
# A file with this name will be ignored by Git.
# Use this file as a template
# -------------------------------------------------------------

# Fill out variables with real values
$cApplicationName = "<Name of the Managed Application in the client's tenant>"
$cResourceGroup = "<Name of the Managed Application's Resource Group in the client's tenant>"
$cSubscription = "<Client Subscription ID>"
$planName = "<ID of the Plan being purchased from Partner Center>"
$functionUri = "<Azure Function URL>/api/resource"
# Nothing else needs customization

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