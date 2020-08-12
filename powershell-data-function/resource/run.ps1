using namespace System.Net

# Input bindings are passed in via param block.
param($Request, $TriggerMetadata)


$DebugPreference = 'Continue'
$ErrorActionPreference = 'Stop'

$provisioningState = $Request.Body.provisioningState

# ensure this a Reqeust we want to handle
if ($provisioningState -ne "Succeeded") {
    
    $returnMessage = "Exiting without any processing of Azure resources. Request has '$provisioningState' instead of 'Succeeded' provisioning state."
    
    Write-Host $returnMessage
    
    Stop-WithHttpOK $returnMessage
}

$cAccessToken = Get-ClientAccessToken
Connect-AzAccount -AccessToken $cAccessToken -AccountId MSI@50342

# Fetching Consumer side details
$cApplicationId = $Request.Body.applicationId
$planName = $Request.Body.plan.name
$a = $cApplicationId -split '/'
$cSubscriptionId = $a[2]
$cResourceGroupName = $a[4]

$items = [ordered]@{
    "env:MSI_ENDPOINT" = $env:MSI_ENDPOINT
    "env:MSI_SECRET"   = $env:MSI_SECRET
    cApplicationId     = $cApplicationId
    cResourceGroupName = $cResourceGroupName
    cSubscriptionId    = $cSubscriptionId
    planName           = $planName
}

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

$items = [ordered]@{
    mApplicationResource = $mApplicationResource
    mDataShareAccount    = $mDataShareAccount
    mIdentity            = $mIdentity
    mResourceGroupId     = $mResourceGroupId
    mResourceGroupName   = $mResourceGroupName
    mStorageAccount      = $mStorageAccount
    mTenantId            = $mTenantId
}


# assign roles for the Data Store onto the Storage account 
Add-RoleToStorage -RoleGuid "ba92f5b4-2d11-453d-a403-e96b0029c9fe" -RoleName "Storage Blob Data Contributor" -StorageAccountId $mStorageAccount.Id -DataShareAccount $mDataShareAccount
Add-RoleToStorage -RoleGuid "2a2b9908-6ea1-4ae2-8e65-a410df84e7d1" -RoleName "Storage Blob Data Reader" -StorageAccountId $mStorageAccount.Id -DataShareAccount $mDataShareAccount
# Add-RoleToStorage -RoleGuid "b7e6dc6d-f1e8-4753-8033-0f276bb0955b" -RoleName "Storage Blob Data Owner" -StorageAccountId $mStorageAccount.Id -DataShareAccount $mDataShareAccount

# Fetching Publisher-side details
$pResourceGroupName = (Get-Item -Path Env:WEBSITE_RESOURCE_GROUP).Value
$websiteOwnerName = (Get-Item -Path Env:WEBSITE_OWNER_NAME).Value
$pSubscriptionId = ($websiteOwnerName -split "\+")[0]

$items = @{
    "Env:WEBSITE_RESOURCE_GROUP" = $Env:WEBSITE_RESOURCE_GROUP
    "Env:WEBSITE_OWNER_NAME"     = $Env:WEBSITE_OWNER_NAME
    "websiteOwnerName"           = $websiteOwnerName
    "pSubscriptionId"            = $pSubscriptionId
}


# connecting to publisher side
Set-AzContext -SubscriptionId $pSubscriptionId

$pDataShareAccountName = (Get-AzDataShareAccount -ResourceGroupName $pResourceGroupName).Name

# Get the appropriate publisher Data Share
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


# get all current invites, kill them and issue one new one.
$invitation = Get-AzDataShareInvitation -AccountName $pDataShareAccountName -ResourceGroupName $pResourceGroupName -ShareName $pDataShare.Name

if ($invitation) {
    foreach ($invite in $invitation) {
        Remove-AzDataShareInvitation -AccountName $pDataShareAccountName -ResourceGroupName $pResourceGroupName -ShareName $pDataShare.Name -Name $invite.Name
    }
}
$invitationName = "$($pDataShare.Name)-Invitation"
$invitation = New-AzDataShareInvitation -AccountName $pDataShareAccountName -Name $invitationName -ResourceGroupName $pResourceGroupName -ShareName $pDataShare.Name -TargetObjectId $mIdentity -TargetTenantId $mTenantId


# suppress version warnings NEW
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

# TODO: get the pub side trigger here

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

# Create new Share Subscription
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
        
        $message = "WARNING: Data Share Subscription '$planName' already assigned. Existing with HTTP 200 to stop retries."
        
        Write-Host $message
        
        Stop-WithHttpOK $message
    
    }
    else {
        throw $_
    }
}

# Mapping Data Sets
foreach ($dataSet in $shareDataSets) {

    $body = $null

    if ($dataset.FilePath) {
        
        $body = @{
            "kind"       = "Blob"
            "name"       = $dataSet.DataSetId
            "properties" = @{
                "containerName"      = $dataSet.ContainerName
                "dataSetId"          = $dataSet.DataSetId
                "filePath"           = $dataSet.FilePath
                "resourceGroup"      = $mResourceGroupName
                "storageAccountName" = $mStorageAccount.StorageAccountName
                "subscriptionId"     = $cSubscriptionId
            }
        } | ConvertTo-Json
    }
    else {
        $body = @{
            "kind"       = "Container"
            "properties" = @{
                "containerName"      = $dataSet.ContainerName
                "dataSetId"          = $dataSet.DataSetId
                "resourceGroup"      = $mResourceGroupName
                "storageAccountName" = $mStorageAccount.StorageAccountName
                "subscriptionId"     = $cSubscriptionId
            }
        } | ConvertTo-Json
    }
    
    $restUri = "https://management.azure.com/subscriptions/$cSubscriptionId/resourceGroups/$mResourceGroupName/providers/Microsoft.DataShare/accounts/$($mDataShareAccount.Name)/shareSubscriptions/$planName/dataSetMappings/$($dataSet.DataSetId)?api-version=2019-11-01"
    
    Invoke-RestMethod -Method PUT -Uri $restUri -Headers $headers -Body $body
}


# Start Synchronization
Write-Host "Start synchronization"
$restUri = "https://management.azure.com/subscriptions/$cSubscriptionId/resourceGroups/$mResourceGroupName/providers/Microsoft.DataShare/accounts/$($mDataShareAccount.Name)/shareSubscriptions/$planName/Synchronize?api-version=2019-11-01"
$body = @{"synchronizationMode" = "Incremental" } | ConvertTo-Json

Invoke-RestMethod -Method POST -Uri $restUri -Headers $headers -Body $body

# TODO: New up the client side trigger here

$message = "Request succeeded. Data sync in progress."

Write-Host $message
Stop-WithHttpOK  $message


# 1. Create share subscription    
# 2. Create dataset mappings
# 3. Start the synch of data
# 4. Create a client trigger to update at the same time and interval as the publisher's trigger

# Write-Host "Creating client side Trigger"
# New-AzDataShareTrigger  -ResourceGroupName $mResourceGroupName `
#                         -AccountName $mDataShareAccount.Name `
#                         -ShareSubscriptionName $planName `
#                         -Name $pTrigger.Name `
#                         -RecurrenceInterval $pTrigger.RecurrenceInterval `
#                         -SynchronizationTime $pTrigger.SynchronizationTime


# Get the publisher side sync trigger
# $pTrigger = $null

# Try {

#     $pTrigger = Get-AzDataShareTrigger -ResourceGroupName $pResourceGroupName -AccountName $pDataShareAccountName -ShareSubscriptionName $planName
# }
# catch {
    
#     $body = "Failed to fetch Trigger from publisher"
    
#     Write-Host $body
#     Write-Host $_.Exception.Message
    
#     # Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
#     #         StatusCode = 404
#     #         Body       = $body
#     #     })

#     # exit
# }

Write-ItemAsJSON -MessageHeader "Trigger NEW infomration" -Item $pTrigger