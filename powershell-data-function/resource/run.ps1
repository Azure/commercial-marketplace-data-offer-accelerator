using namespace System.Net

# Input bindings are passed in via param block.
param($Request, $TriggerMetadata)

$DebugPreference = 'Continue'
$ErrorActionPreference = 'Stop'

# suppress version warnings NEW
Set-Item Env:\SuppressAzurePowerShellBreakingChangeWarnings "true"

$provisioningState = $Request.Body.provisioningState

# ensure this a Reqeust we want to handle
if ($provisioningState -ne "Succeeded") {
    
    $message = "Exiting without any processing of Azure resources. Request has '$provisioningState' instead of 'Succeeded' provisioning state."
    
    Write-Host $message
    
    Stop-WithHttp  -Message $message
}

$cAccessToken = Get-ClientAccessToken
Connect-AzAccount -AccessToken $cAccessToken -AccountId MSI@50342

# ----------------------------------------------------
# Fetching Consumer side details
# ----------------------------------------------------
$cApplicationId = $Request.Body.applicationId
$planName = $Request.Body.plan.name
$a = $cApplicationId -split '/'
$cSubscriptionId = $a[2]
$cResourceGroupName = $a[4]
$cManagedAppName = $a[8]

# ----------------------------------------------------
# set context to customer subscription
# ----------------------------------------------------
Set-AzContext -SubscriptionId $cSubscriptionId

# ----------------------------------------------------
# get the managed application information
# ----------------------------------------------------
$mApplication = $null
$mApplicationResource = $null

Try {
    # Sometimes this call fails because the managed application has not completed provisioninng 
    # by the time this function gets called
    $mApplication = Get-AzManagedApplication -ResourceGroupName $cResourceGroupName -Name $cManagedAppName
    $mApplicationResource = Get-AzResource -ResourceId $cApplicationId
}
Catch [Microsoft.WindowsAzure.Commands.Storage.Common.ResourceNotFoundException] {
    
    $message = "ERROR: Get-AzManagedApplication -ResourceGroupName $cResourceGroupName -Name $cManagedAppName Retry."
    
    Write-Host $message
    
    Stop-WithHttp -Message $message -StatusCode 425
}

$mResourceGroupId = $mApplication.Properties.managedResourceGroupId
$mResourceGroupName = ($mResourceGroupId -split '/')[4]
$mIdentity = $mApplicationResource.Identity.PrincipalId
Write-Host mIdentity: $mIdentity
$mTenantId = $mApplicationResource.Identity.TenantId
Write-Host mTenantId: $mTenantId
$mDataShareAccount = Get-AzDataShareAccount -ResourceGroupName $mResourceGroupName
$mStorageAccount = Get-AzStorageAccount -ResourceGroupName $mResourceGroupName

if (!$mDataShareAccount -or !$mStorageAccount) {
    $message = "ERROR: Cannot fetch information on publisher Data Share account or storage account. Sending 503 for a retry later."
    
    Write-Host $message
    
    Stop-WithHttp -Message $message -StatusCode 503
}


# ----------------------------------------------------
# assign roles for the Data Store onto the Storage account 
# ----------------------------------------------------
Add-RoleToStorage -RoleGuid "ba92f5b4-2d11-453d-a403-e96b0029c9fe" -RoleName "Storage Blob Data Contributor" -StorageAccountId $mStorageAccount.Id -DataShareAccount $mDataShareAccount

# Fetching Publisher-side details
$pResourceGroupName = (Get-Item -Path Env:WEBSITE_RESOURCE_GROUP).Value
$websiteOwnerName = (Get-Item -Path Env:WEBSITE_OWNER_NAME).Value
$pSubscriptionId = ($websiteOwnerName -split "\+")[0]

# connecting to publisher side
Set-AzContext -SubscriptionId $pSubscriptionId

$pDataShareAccount = Get-AzDataShareAccount -ResourceGroupName $pResourceGroupName
$pDataShareAccountName = $pDataShareAccount.Name
$shareSourceLocation = $pDataShareAccount.Location

# Get the appropriate publisher Data Share
$pDataShare = Get-AzDataShare -Name $planName -ResourceGroupName $pResourceGroupName -AccountName $pDataShareAccountName -ErrorVariable errorInfo

if (!$pDataShare) {
    
    $message = "No Data Share Account '$pDataShareAccountName' found\n\n$errorInfo"
    
    Write-Host $message
    
    Stop-WithHttp -Message $message -StatusCode 503
}

# Get the Data Sets before changing contexts
$shareDataSets = Get-AzDataShareDataSet -AccountName $pDataShareAccountName -ResourceGroupName $pResourceGroupName -ShareName $pDataShare.Name

if ($shareDataSets.Count -eq 0) {

    $message = "No Data Sets in publisher Data Share: $pDataShareAccountName : $($pDataShare.Name)"

    Write-Host $message

    Stop-WithHttp -Message $message -StatusCode 503

    exit
}

# get a current invite
$invitation = Get-DataShareInvitation -DataShare $pDataShare -DataShareAccountName $pDataShareAccountName -Identity $mIdentity -ResourceGroupName $pResourceGroupName -TenantId $mTenantId -ManagedAppName $cManagedAppName

# Get the pub side trigger here
$pTrigger = Get-AzDataShareSynchronizationSetting -ResourceGroupName $pResourceGroupName -AccountName $pDataShareAccountName -ShareName $planName

Set-AzContext -SubscriptionId $cSubscriptionId

# ----------------------------------------------------
# Fetch token for managed identity and
# connect as the Managed Application
# ----------------------------------------------------
$listTokenUri = "https://management.azure.com/$cApplicationId/listTokens?api-version=2018-09-01-preview"

$body = @{ "authorizationAudience" = "https://management.azure.com/" } | ConvertTo-Json

$headers = @{
    "Authorization" = "Bearer $cAccessToken"
    "client_id"     = $mIdentity
}

$response = Invoke-RestMethod -Uri $listTokenUri -ContentType "application/json" -Method POST -Body $body -Headers $headers
$mAppToken = $response.value.access_token

Connect-AzAccount -AccessToken $mAppToken -AccountId $mIdentity

# ----------------------------------------------------
# Create new Share Subscription
# ----------------------------------------------------
$restUri = "https://management.azure.com/subscriptions/$cSubscriptionId/resourceGroups/$mResourceGroupName/providers/Microsoft.DataShare/accounts/$($mDataShareAccount.Name)/shareSubscriptions/$($planName)?api-version=2019-11-01"

$headers = @{
    'Authorization' = 'Bearer ' + $mAppToken
    'Content-Type'  = 'application/json'
}

$body = @{
    "properties" = @{
        "invitationId"        = $invitation.InvitationId
        "sourceShareLocation" = $shareSourceLocation
    }
} | ConvertTo-Json

Try {
    Invoke-RestMethod -Method PUT -Uri $restUri -Headers $headers -Body $body
}
Catch [Microsoft.PowerShell.Commands.HttpResponseException] {
    
    if ($_.Exception.Response.StatusCode -eq 409) {
        
        $message = "WARNING: Data Share Subscription '$planName' already assigned. Exiting with HTTP 200 to stop retries."
        
        Write-Host $message
        
        Stop-WithHttp -Message $message -StatusCode 200
    
    }
    else {
        throw $_
    }
}

# ----------------------------------------------------
# Create Data Set Mappings
# ----------------------------------------------------
foreach ($dataSet in $shareDataSets) {

    $body = $null

    switch ($dataSet) {
        {$dataSet.Prefix} { 
            $body = New-FolderRestBody -DataSet $dataSet -ResourceGroupname $mResourceGroupName -StorageAccountName $mStorageAccount.StorageAccountName -SubscriptionId $cSubscriptionId
         }
         {$dataSet.FilePath} { 
            $body = New-BlobRestBody -DataSet $dataSet -ResourceGroupname $mResourceGroupName -StorageAccountName $mStorageAccount.StorageAccountName -SubscriptionId $cSubscriptionId
         }
        Default {
            $body = New-ContainerRestBody -DataSet $dataSet -ResourceGroupname $mResourceGroupName -StorageAccountName $mStorageAccount.StorageAccountName -SubscriptionId $cSubscriptionId
        }
    }

    $restUri = "https://management.azure.com/subscriptions/$cSubscriptionId/resourceGroups/$mResourceGroupName/providers/Microsoft.DataShare/accounts/$($mDataShareAccount.Name)/shareSubscriptions/$planName/dataSetMappings/$($dataSet.Name)?api-version=2019-11-01"
    
    Invoke-RestMethod -Method PUT -Uri $restUri -Headers $headers -Body $body
}

# ----------------------------------------------------
# Enable Snapshot schedule
# ----------------------------------------------------
if ($pTrigger) {
    
    $restUri = "https://management.azure.com/subscriptions/$cSubscriptionId/resourceGroups/$mResourceGroupName/providers/Microsoft.DataShare/accounts/$($mDataShareAccount.Name)/shareSubscriptions/$planName/triggers/$($pTrigger.Name)?api-version=2019-11-01"
    $body = @{
        "kind"       = "ScheduleBased"
        "properties" = @{
            "recurrenceInterval"  = "$($pTrigger.RecurrenceInterval)"
            "synchronizationMode" = "$($pTrigger.SynchronizationMode)"
            "synchronizationTime" = "$($pTrigger.SynchronizationTime)"
        }
    } | ConvertTo-Json

    Invoke-RestMethod -Method PUT -Uri $restUri -Headers $headers -Body $body
}


# ----------------------------------------------------
# Start Synchronization
# Check for previously scheduled sync operations
# ----------------------------------------------------
$restUri = "https://management.azure.com/subscriptions/$cSubscriptionId/resourceGroups/$mResourceGroupName/providers/Microsoft.DataShare/accounts/$($mDataShareAccount.Name)/shareSubscriptions/$planName/listSynchronizations?api-version=2019-11-01"

$synchronizations = Invoke-RestMethod -Method POST -Uri $restUri -Headers $headers

if ( !$synchronizations.value) {
    Write-Host "Start synchronization"
    $restUri = "https://management.azure.com/subscriptions/$cSubscriptionId/resourceGroups/$mResourceGroupName/providers/Microsoft.DataShare/accounts/$($mDataShareAccount.Name)/shareSubscriptions/$planName/Synchronize?api-version=2019-11-01"
    $body = @{"synchronizationMode" = "Incremental" } | ConvertTo-Json

    Invoke-RestMethod -Method POST -Uri $restUri -Headers $headers -Body $body
}
else {
    Write-Host "Found existing synchronization operatation. Skipping."
}

# ----------------------------------------------------
# Write final to calling client and Exit Successfully
# ----------------------------------------------------
$message = "Request succeeded. Data sync in progress."

Write-Host $message
Stop-WithHttp -Message $message
