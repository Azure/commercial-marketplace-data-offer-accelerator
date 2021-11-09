using namespace System.Net

# Input bindings are passed in via param block.
param($Request, $TriggerMetadata)

$DebugPreference = 'Continue'
$ErrorActionPreference = 'Stop'
$writeInfoOutput = [bool]::Parse('True')

# suppress version warnings NEW
Set-Item Env:\SuppressAzurePowerShellBreakingChangeWarnings "true"

$provisioningState = $Request.Body.provisioningState

# ensure this a Reqeust we want to handle
if ($provisioningState -ne "Succeeded") {
    $message = "Request has '$provisioningState' instead of 'Succeeded' provisioning state. Exiting without any processing of Azure resources."
    Write-Host $message
    Stop-WithHttp  -Message $message
}

if ($writeInfoOutput) {
    Write-Host "----------------------------------------------------"
    Write-Host "REQUEST BODY"
    Write-Host ($Request.Body | ConvertTo-JSON)
    Write-Host "----------------------------------------------------"
}

$cAccessToken = Get-ClientAccessToken
Connect-AzAccount -AccessToken $cAccessToken -AccountId MSI@50342

# Fetching Consumer side details
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

# get the managed application information
$mApplication = $null
$mApplicationResource = $null

Try {
    # Sometimes this call fails because the managed application has not completed provisioninng 
    # by the time this function gets called. Flag for retry if it fails.
    $mApplication = Get-AzManagedApplication -ResourceGroupName $cResourceGroupName -Name $cManagedAppName
    $mApplicationResource = Get-AzResource -ResourceId $cApplicationId
}
Catch [Microsoft.WindowsAzure.Commands.Storage.Common.ResourceNotFoundException] {
    $message = "ERROR: Get-AzManagedApplication -ResourceGroupName $cResourceGroupName -Name $cManagedAppName Retry."
    Write-Host $message
    Stop-WithHttp -Message $message -StatusCode 425
}

if (!$mApplicationResource) {
    $message = "ERROR: mApplicationResource is null. Sending 503 for a retry later."
    Write-Host $message
    Stop-WithHttp -Message $message -StatusCode 503
}

if (!$mApplicationResource.Identity) {
    $message = "ERROR: mApplicationResource.Identity is null. Sending 503 for a retry later."
    Write-Host $message
    Stop-WithHttp -Message $message -StatusCode 503
}

$mIdentity = $mApplicationResource.Identity.PrincipalId
$mTenantId = $mApplicationResource.Identity.TenantId

$mResourceGroupId = $mApplication.Properties.managedResourceGroupId
$mResourceGroupName = ($mResourceGroupId -split '/')[4]

$mDataShareAccount = Get-AzDataShareAccount -ResourceGroupName $mResourceGroupName
$mStorageAccount = Get-AzStorageAccount -ResourceGroupName $mResourceGroupName

if (!$mStorageAccount) {
    $message = "ERROR: Cannot fetch information on consumer storage account. Sending 503 for a retry later."
    Write-Host $message
    Stop-WithHttp -Message $message -StatusCode 503
}

if (!$mDataShareAccount) {
    $message = "ERROR: Cannot fetch information on consumer Data Share account. Sending 503 for a retry later."
    Write-Host $message
    Stop-WithHttp -Message $message -StatusCode 503
}

# Assign roles for the Data Store onto the Storage account 
Add-RoleToStorage -RoleGuid "ba92f5b4-2d11-453d-a403-e96b0029c9fe" -RoleName "Storage Blob Data Contributor" -StorageAccountId $mStorageAccount.Id -DataShareAccount $mDataShareAccount



# ----------------------------------------------------
# Connect via publisher context
# ----------------------------------------------------
# Fetching Publisher-side subscription
$websiteOwnerName = (Get-Item -Path Env:WEBSITE_OWNER_NAME).Value
$pSubscriptionId = ($websiteOwnerName -split "\+")[0]

Set-AzContext -SubscriptionId $pSubscriptionId

# Fetching Publisher-side resource group
$envResourceGroupName = (Get-Item -Path Env:WEBSITE_RESOURCE_GROUP).Value
$pResourceGroupName = (Get-AzResourceGroup -Name $envResourceGroupName).ResourceGroupName 

$pDataShareAccount = Get-AzDataShareAccount -ResourceGroupName $pResourceGroupName

# Get the appropriate publisher Data Share
$pDataShare = Get-AzDataShare -Name $planName -ResourceGroupName $pResourceGroupName -AccountName $pDataShareAccount.Name -ErrorVariable errorInfo

if (!$pDataShare) {
    $message = "No Data Share '$pDataShare' found\n\n$errorInfo"
    Write-Host $message
    Stop-WithHttp -Message $message -StatusCode 503
}

if (!$pDataShare.Name) {
    $message = "No Data Share Name '$($pDataShare.Name)' found\n\n$errorInfo"
    Write-Host $message
    Stop-WithHttp -Message $message -StatusCode 503
}

# Get the Data Sets to synchronize
$pDataSets = Get-AzDataShareDataSet -AccountName $pDataShareAccount.Name -ResourceGroupName $pResourceGroupName -ShareName $pDataShare.Name

if ($pDataSets.Count -eq 0) {
    $message = "No Data Sets in publisher Data Share: $pDataShareAccount.Name : $($pDataShare.Name)"
    Write-Host $message
    Stop-WithHttp -Message $message -StatusCode 400
}

# get a current invitation
$invitation = Get-DataShareInvitation -DataShare $pDataShare -DataShareAccountName $pDataShareAccount.Name -Identity $mIdentity -ResourceGroupName $pResourceGroupName -TenantId $mTenantId -ManagedAppName $cManagedAppName

# Get the publisher side trigger
$pTrigger = Get-AzDataShareSynchronizationSetting -ResourceGroupName $pResourceGroupName -AccountName $pDataShareAccount.Name -ShareName $planName

# ----------------------------------------------------
# Connect via consumer context
# ----------------------------------------------------
Set-AzContext -SubscriptionId $cSubscriptionId

# Fetch token for managed identity and connect as the Managed Application
$headers = @{
    "Authorization" = "Bearer $cAccessToken"
    "client_id"     = $mIdentity
    "Content-Type"  = "application/json"
}
$body = @{ "authorizationAudience" = "https://management.azure.com/" } | ConvertTo-Json
$listTokenUri = "https://management.azure.com/$cApplicationId/listTokens?api-version=2018-09-01-preview"

Try {
    $response = Invoke-RestMethod -Uri $listTokenUri -ContentType "application/json" -Method POST -Body $body -Headers $headers
    $mAppToken = $response.value.access_token
} 
Catch [Microsoft.PowerShell.Commands.HttpResponseException] {
    
    if ($_.Exception.Response.StatusCode -eq 409) {
        $message = "WARNING: Data Share Subscription '$planName' already assigned."
        Write-Host $message
    }
    else {
        throw $_
    }
}

# ----------------------------------------------------
# Connect via managed identity
# ----------------------------------------------------
Connect-AzAccount -AccessToken $mAppToken -AccountId $mIdentity

# Create new Share Subscription
New-AzDataShareSubscription -ResourceGroupName $mResourceGroupName -AccountName $mDataShareAccount.Name -Name $planName -InvitationId $invitation.InvitationId -SourceShareLocation $pDataShareAccount.Location

Write-Host "MAPPING DATA SETS"
foreach ($dataSet in $pDataSets) {

    # Write-Host "DataSet.Id: $($dataSet.Id)"
    # Write-Host "DataSet.DataSetId: $($dataSet.DataSetId)"
    # Write-Host "DataSet.Name: $($dataSet.Name)"
    # Write-Host "DataSet.Type: $($dataSet.Type)"
    # Write-Host "DataSet.FileSystem: $($dataSet.FileSystem)"
    # Write-Host "DataSet.FilePath: $($dataSet.FilePath)"
    # Write-Host "DataSet.FolderPath: $($dataSet.FolderPath)"
    # Write-Host "DataSet.FileName: $($dataSet.FileName)"
    # Write-Host "+++++++++++++++"

    if ($dataSet.FolderPath) {
        New-AzDataShareDataSetMapping -ResourceGroupName $mResourceGroupName -AccountName $mDataShareAccount.Name -DataSetId $dataSet.DataSetId -Name $dataSet.Name -ShareSubscriptionName $planName -StorageAccountResourceId $mStorageAccount.Id -FileSystem $dataSet.Name -FolderPath $dataSet.FolderPath
    }
    elseif ($dataSet.FilePath) {
        New-AzDataShareDataSetMapping -ResourceGroupName $mResourceGroupName -AccountName $mDataShareAccount.Name -DataSetId $dataSet.DataSetId -Name $dataSet.Name -ShareSubscriptionName $planName -StorageAccountResourceId $mStorageAccount.Id -FileSystem $dataSet.Name -FilePath $dataSet.FilePath
    }
    else {
        New-AzDataShareDataSetMapping -ResourceGroupName $mResourceGroupName -AccountName $mDataShareAccount.Name -DataSetId $dataSet.DataSetId -Name $dataSet.Name -ShareSubscriptionName $planName -StorageAccountResourceId $mStorageAccount.Id -FileSystem $dataSet.Name
    }
}

# Enable Snapshot schedule
if ($pTrigger) {
    New-AzDataShareTrigger -ResourceGroupName $mResourceGroupName -AccountName $mDataShareAccount.Name -ShareSubscriptionName $planName -Name $pTrigger.Name -RecurrenceInterval $pTrigger.RecurrenceInterval -SynchronizationTime $pTrigger.SynchronizationTime
}

# Check for previously scheduled sync operations
# Start Synchronization
$synch = Get-AzDataShareSubscriptionSynchronization -ResourceGroupName $mResourceGroupName -AccountName $mDataShareAccount.Name -ShareSubscriptionName $planName
if(!$synch) {
    Write-Host "Start synch"
    Start-AzDataShareSubscriptionSynchronization -ResourceGroupName $mResourceGroupName -AccountName $mDataShareAccount.Name -ShareSubscriptionName $planName -SynchronizationMode Incremental
}

# Write final to calling client and Exit Successfully
$message = "REQUEST SUCCEEDED. DATA SYNC IN PROGRESS."
Write-Host $message
Stop-WithHttp -Message $message
