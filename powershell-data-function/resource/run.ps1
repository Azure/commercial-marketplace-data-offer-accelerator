using namespace System.Net

# Input bindings are passed in via param block.
param($Request, $TriggerMetadata)

$DebugPreference = 'Continue'
$ErrorActionPreference = 'Stop'
$verboseOutput = $false

# Write-Request $Request 

$provisioningState = $Request.Body.provisioningState

# ensure this a Reqeust we want to handle
if ($provisioningState -ne "Succeeded") {
    
    $returnMessage = "Exiting without any processing of Azure resources. Request has '$provisioningState' instead of 'Succeeded' provisioning state."
    
    # log the call
    Write-Host $returnMessage
    
    Stop-WithHttpOK $returnMessage
}

$cAccessToken = Get-ClientAccessToken

Connect-AzAccount -AccessToken $cAccessToken -AccountId MSI@50342

#==================================================================================
# Fetching Consumer side details
#==================================================================================
$cApplicationId = $Request.Body.applicationId
$planName = $Request.Body.plan.name

$a = $cApplicationId -split '/'
$cSubscriptionId = $a[2]
$cResourceGroupName = $a[4]

# Write-Host Consumer Subscription ID: $cSubscriptionId
# Write-Host Consumer Resource Group: $cResourceGroupName
# Write-Host env:MSI_ENDPOINT: $env:MSI_ENDPOINT
# Write-Host env:MSI_SECRET: $env:MSI_SECRET


# get the managed application information

$mApplication = $null

Try {
    # Sometimes this call fails because the managed application has not completed provisioninng 
    # by the time this function gets called
    $mApplication = Get-AzManagedApplication -ResourceGroupName $cResourceGroupName
}
Catch [Microsoft.PowerShell.Commands.HttpResponseException] {
    
    $message = "WARNING: Get-AzManagedApplication -ResourceGroupName $cResourceGroupName FAILED"

    Write-Host $message

    # return an error so we get a retry call later
    Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
            StatusCode = 425
            Body       = $body
        })

    exit
}

$mApplicationResource = Get-AzResource -ResourceName $mApplication.Name
$mResourceGroupId = $mApplication.Properties.managedResourceGroupId
$mResourceGroupName = ($mResourceGroupId -split '/')[4]
$mIdentity = $mApplicationResource.Identity.PrincipalId
$mDataShareAccount = Get-AzDataShareAccount -ResourceGroupName $mResourceGroupName
$mStorageAccount = Get-AzStorageAccount -ResourceGroupName $mResourceGroupName
$mTenantId = $mApplicationResource.Identity.TenantId

if ($verboseOutput) { Write-ManagedAppVaraiables }

# Write-Host ==============================================================================================================
# Write-Host "on Data Storage account $($mStorageAccount.StorageAccountName)"
# Write-Host "Creating role assignment on Data Storage account: Storage Blob Data Contributor"
# Write-Host ==============================================================================================================

$restUri = "https://management.azure.com$($mStorageAccount.Id)/providers/Microsoft.Authorization/roleAssignments/$(New-Guid)?api-version=2019-04-01-preview"

$headers = @{
    'Authorization' = 'Bearer ' + $cAccessToken
    'Content-Type'  = 'application/json'
}

# Role assignment works with delegatedManagedIdentityResourceId
# Adding this role to the Data Storage account: Storage Blob Data Contributor 
$body = @{
    "properties" = @{
        "delegatedManagedIdentityResourceId" = "$($mDataShareAccount.Id)"
        "principalId"                        = "$($mDataShareAccount.Identity.PrincipalId)"
        "roleDefinitionId"                   = "$($mStorageAccount.Id)/providers/Microsoft.Authorization/roleAssignments/ba92f5b4-2d11-453d-a403-e96b0029c9fe"
    }
} | ConvertTo-Json

Try {
    
    Invoke-RestMethod -Method PUT -Uri $restUri -Headers $headers -Body $body

}
Catch [Microsoft.PowerShell.Commands.HttpResponseException] {

    if ($_.Exception.Response.StatusCode -eq 409) {
        Write-Host "WARNING: Role already assigned" -ForegroundColor Yellow
    }
    elseif ($_.Exception.Response.StatusCode -eq 403) {
        Write-Host "ERROR: Canot assign role - 'Forbidden'" -ForegroundColor Yellow
    }
    else {
        throw $_
    }
}

#==================================================================================
# Fetching Publisher-side details
#==================================================================================
$pResourceGroupName = (Get-Item -Path Env:WEBSITE_RESOURCE_GROUP).Value
$websiteOwnerName = (Get-Item -Path Env:WEBSITE_OWNER_NAME).Value
$pSubscriptionId = ($websiteOwnerName -split "\+")[0]


Write-Host "Publisher Resource Group Name: $pResourceGroupName"
Write-Host "Publisher Subscription ID: $pSubscriptionId"

# connecting to publisher side
Set-AzContext -SubscriptionId $pSubscriptionId

$pDataShareAccountName = (Get-AzDataShareAccount -ResourceGroupName $pResourceGroupName).Name
Write-Host "Publisher Data Share Account name: $pDataShareAccountName"

# Write-Host =======================================================================================
# Write-Host "Get the appropriate publisher Data Share"
# Write-Host =======================================================================================
$pDataShare = Get-AzDataShare -Name $planName -ResourceGroupName $pResourceGroupName -AccountName $pDataShareAccountName -ErrorVariable errorInfo

if (!$pDataShare) {
    
    $returnMessage = "No Data Share Account '$pDataShareAccountName' found\n\n$errorInfo"
    
    Write-Host $returnMessage
    
    $body = @{ "message" = $returnMessage } | ConvertTo-Json
    
    Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
            StatusCode = 404
            Body       = $body
        })
    
    exit
}

# Write-Host Send an invite if one hasn't already been sent
$invitation = Get-AzDataShareInvitation -AccountName $pDataShareAccountName -ResourceGroupName $pResourceGroupName -ShareName $pDataShare.Name
if ($invitation) {
    Remove-AzDataShareInvitation -AccountName $pDataShareAccountName -ResourceGroupName $pResourceGroupName -ShareName $pDataShare.Name -Name $invitation.Name
}
$invitationName = "$($pDataShare.Name)-Invitation"
$invitation = New-AzDataShareInvitation -AccountName $pDataShareAccountName -Name $invitationName -ResourceGroupName $pResourceGroupName -ShareName $pDataShare.Name -TargetObjectId $mIdentity -TargetTenantId $mTenantId

if($verboseOutput){
    Write-Invitation $invitation
}

# suppress version warnings
Set-Item Env:\SuppressAzurePowerShellBreakingChangeWarnings "true"

# Get the Data Sets before changing contexts
$shareDataSets = Get-AzDataShareDataSet -AccountName $pDataShareAccountName -ResourceGroupName $pResourceGroupName -ShareName $pDataShare.Name

if ($shareDataSets.Count -eq 0) {

    $body = "No Data Sets in publisher Data Share: $pDataShareAccountName => $($pDataShare.Name)"
    Write-Host $body

    Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
            StatusCode = 404
            Body       = $body
        })

    exit
}

# Write-Host =======================================================================================
# Write-Host "Get the publisher side sync trigger"
# Write-Host =======================================================================================

# $pTrigger = $null

# Try {
#     $pTrigger = Get-AzDataShareTrigger -ResourceGroupName $pResourceGroupName -AccountName $pDataShareAccountName -ShareSubscriptionName $pSubscriptionId
# }
# catch {
    
#     $body = "Failed to fetch Trigger from publisher"
    
#     Write-Host $body
#     Write-Host $_.Exception.Message
    
#     Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
#             StatusCode = 404
#             Body       = $body
#         })

#     exit
# }

# Write-Host pTrigger.Id $pTrigger.Id
# Write-Host pTrigger ($pTrigger | ConvertTo-Json)
# Write-Host =======================================================================================

    
Set-AzContext -SubscriptionId $cSubscriptionId

# Connect as the Managed Application
# fetching token for managed identity
$listTokenUri = "https://management.azure.com/$cApplicationId/listTokens?api-version=2018-09-01-preview"

$body = @{ "authorizationAudience" = "https://management.azure.com/" } | ConvertTo-Json

$headers = @{
    "Authorization" = "Bearer $cAccessToken"
    "client_id"     = $mIdentity 
}

$response = Invoke-RestMethod -Uri $listTokenUri -ContentType "application/json" -Method POST -Body $body -Headers $headers
$mAppToken = $response.value.access_token

Connect-AzAccount -AccessToken $mAppToken -AccountId MSI@50342

# Write-Host =======================================================================================
# Write-Host Create new Share Subscription
# Write-Host =======================================================================================

$restUri = "https://management.azure.com/subscriptions/$cSubscriptionId/resourceGroups/$mResourceGroupName/providers/Microsoft.DataShare/accounts/$($mDataShareAccount.Name)/shareSubscriptions/$planName/?api-version=2019-11-01"

$headers = @{
    'Authorization' = 'Bearer ' + $mAppToken
    'Content-Type'  = 'application/json'
}

$body = @{
    "properties" = @{
        "invitationId"        = $invitation.InvitationId
        "sourceShareLocation" = $mStorageAccount.Location
    }
} | ConvertTo-Json

Try {
    Invoke-RestMethod -Method PUT -Uri $restUri -Headers $headers -Body $body
}
Catch [Microsoft.PowerShell.Commands.HttpResponseException] {
    
    if ($_.Exception.Response.StatusCode -eq 409) {
        
        $message = "WARNING: Data Share Subscription '$planName' already assigned"
        
        Write-Host $message -ForegroundColor Yellow
        Write-Host "Exiting with HTTP Code 200" -ForegroundColor Yellow
        
        Stop-WithHttpOK $message
    
    }
    else {
        throw $_
    }
}

# Write-Host =======================================================================================
# Write-Host "Mapping Data Sets"
# Write-Host =======================================================================================

foreach ($dataSet in $shareDataSets) {
    
    Write-Host "Mapping Data Set: $($dataSet.Name)"

    # this handles the blob and container data sets
    $kind = $null
    if ($dataset.FilePath) {
        $kind = "Blob"
    }
    else {
        $kind = "Container"
    }

    $restUri = "https://management.azure.com/subscriptions/$cSubscriptionId/resourceGroups/$mResourceGroupName/providers/Microsoft.DataShare/accounts/$($mDataShareAccount.Name)/shareSubscriptions/$planName/dataSetMappings/$($dataSet.ContainerName)?api-version=2019-11-01"

    $body = @{
        "kind"       = $kind
        "properties" = @{
            "containerName"      = $dataSet.ContainerName
            "dataSetId"          = $dataSet.DataSetId
            "filePath"           = $dataset.FilePath
            "resourceGroup"      = $mResourceGroupName
            "storageAccountName" = $mStorageAccount.StorageAccountName
            "subscriptionId"     = $cSubscriptionId
        }
    } | ConvertTo-Json

    Invoke-RestMethod -Method PUT -Uri $restUri -Headers $headers -Body $body
}

if ($verboseOutput) {
    Write-Host =======================================================================================
    Write-Host "Start synchronization"
    Write-Host =======================================================================================
}

$restUri = "https://management.azure.com/subscriptions/$cSubscriptionId/resourceGroups/$mResourceGroupName/providers/Microsoft.DataShare/accounts/$($mDataShareAccount.Name)/shareSubscriptions/$planName/Synchronize?api-version=2019-11-01"
$body = @{"synchronizationMode" = "Incremental" } | ConvertTo-Json

Invoke-RestMethod -Method POST -Uri $restUri -Headers $headers -Body $body

if ($verboseOutput) {
    Write-Host =======================================================================================
    Write-Host "Creating client side Trigger"
    Write-Host =======================================================================================
}

Stop-WithHttpOK

# New-AzDataShareTrigger  -ResourceGroupName $mResourceGroupName `
#                         -AccountName $mDataShareAccount.Name `
#                         -ShareSubscriptionName $planName `
#                         -Name $pTrigger.Name `
#                         -RecurrenceInterval $pTrigger.RecurrenceInterval `
#                         -SynchronizationTime $pTrigger.SynchronizationTime



# 1. Create share subscription    
# 2. Create dataset mappings
# 3. Start the synch of data
# 4. Create a client trigger to update at the same time and interval as the publisher's trigger