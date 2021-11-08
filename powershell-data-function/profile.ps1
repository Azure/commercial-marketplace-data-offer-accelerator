# Authenticate with Azure PowerShell using MSI.
# Remove this if you are not planning on using MSI or Azure PowerShell.
# if ($env:MSI_SECRET -and (Get-Module -ListAvailable Az.Accounts)) {
#     Connect-AzAccount -Identity
# }

function New-BlobRestBody () {

    param(
        [Parameter(Mandatory = $true)]
        [Microsoft.Azure.PowerShell.Cmdlets.DataShare.Models.PSDataShareDataSet] $DataSet,

        [Parameter(Mandatory = $true)]
        [String] $StorageAccountName,

        [Parameter(Mandatory = $true)]
        [String] $ResourceGroupname,

        [Parameter(Mandatory = $true)]
        [String] $SubscriptionId
    )

    $body = @{
        "kind"       = "Blob"
        "properties" = @{
            "containerName"      = $DataSet.ContainerName
            "dataSetId"          = $DataSet.DataSetId
            "filePath"           = $DataSet.FilePath
            "resourceGroup"      = $ResourceGroupName
            "storageAccountName" = $StorageAccountName
            "subscriptionId"     = $SubscriptionId
        }
    } | ConvertTo-Json

    return $body
}

function New-ContainerRestBody () {

    param(
        [Parameter(Mandatory = $true)]
        [Microsoft.Azure.PowerShell.Cmdlets.DataShare.Models.PSDataShareDataSet] $DataSet,

        [Parameter(Mandatory = $true)]
        [String] $StorageAccountName,

        [Parameter(Mandatory = $true)]
        [String] $ResourceGroupname,

        [Parameter(Mandatory = $true)]
        [String] $SubscriptionId
    )

    $body = @{
        "kind"       = "Container"
        "properties" = @{
            "containerName"      = $DataSet.ContainerName
            "dataSetId"          = $DataSet.DataSetId
            "resourceGroup"      = $ResourceGroupName
            "storageAccountName" = $StorageAccountName
            "subscriptionId"     = $SubscriptionId
        }
    } | ConvertTo-Json

    return $body
}

function New-FolderRestBody () {

    param(
        [Parameter(Mandatory = $true)]
        [Microsoft.Azure.PowerShell.Cmdlets.DataShare.Models.PSDataShareDataSet] $DataSet,

        [Parameter(Mandatory = $true)]
        [String] $StorageAccountName,

        [Parameter(Mandatory = $true)]
        [String] $ResourceGroupname,

        [Parameter(Mandatory = $true)]
        [String] $SubscriptionId
    )

    $body = @{
        "kind"       = "BlobFolder"
        "properties" = @{
            "containerName"      = $DataSet.ContainerName
            "dataSetId"          = $DataSet.DataSetId
            "prefix"             = $DataSet.Prefix
            "resourceGroup"      = $ResourceGroupName
            "storageAccountName" = $StorageAccountName
            "subscriptionId"     = $SubscriptionId
        }
    } | ConvertTo-Json

    return $body
}

function Get-DataShareInvitation () {

    param(
        [Parameter(Mandatory = $true)]
        [Microsoft.Azure.PowerShell.Cmdlets.DataShare.Models.PSDataShare] $DataShare,

        [Parameter(Mandatory = $true)]
        [String] $DataShareAccountName,

        [Parameter(Mandatory = $true)]
        [String] $Identity,
        
        [Parameter(Mandatory = $true)]
        [String] $ResourceGroupName,

        [Parameter(Mandatory = $true)]
        [String] $TenantId,

        [Parameter(Mandatory = $true)]
        [String] $ManagedAppName
    )

    $DebugPreference = 'SilentlyContinue'

    $invitationName = "invite-$($Identity)"
    $invitation = $null
    $invitation = Get-AzDataShareInvitation -AccountName $DataShareAccountName -ResourceGroupName $ResourceGroupName -ShareName $DataShare.Name -Name $invitationName -ErrorAction SilentlyContinue

    if (!$invitation) {
        $invitation = New-AzDataShareInvitation -AccountName $DataShareAccountName -Name $invitationName -ResourceGroupName $ResourceGroupName -ShareName $DataShare.Name -TargetObjectId $Identity -TargetTenantId $TenantId
    }
    
    return $invitation
}


function Add-RoleToStorage() {

    param(
        
        [Parameter(Mandatory = $true)]
        [Microsoft.Azure.PowerShell.Cmdlets.DataShare.Models.PSDataShareAccount] $DataShareAccount,

        [Parameter(Mandatory = $true)]
        [String] $StorageAccountId,

        [Parameter(Mandatory = $true)]
        [String] $RoleGuid,

        [Parameter(Mandatory = $true)]
        [String] $RoleName

    )

    $accessToken = Get-ClientAccessToken

    $roleDefinition = "$StorageAccountId/providers/Microsoft.Authorization/roleAssignments/$RoleGuid"
    Write-Host "roleDefinition: $roleDefinition"

    $headers = @{
        'Authorization' = 'Bearer ' + $accessToken
        'Content-Type'  = 'application/json'
    }
    
    # Role assignment works with delegatedManagedIdentityResourceId
    # Adding this role to the Data Storage account: Storage Blob Data Contributor 
    $body = @{
        "properties" = @{
            "delegatedManagedIdentityResourceId" = "$($DataShareAccount.Id)"
            "principalId"                        = "$($DataShareAccount.Identity.PrincipalId)"
            "roleDefinitionId"                   = $roleDefinition
        }
    } | ConvertTo-Json

    # Creating role assignment on Data Storage account: Storage Blob Data Contributor
    $restUri = "https://management.azure.com/$StorageAccountId/providers/Microsoft.Authorization/roleAssignments/$(New-Guid)?api-version=2019-04-01-preview"

    
    Try {
        
        Invoke-RestMethod -Method PUT -Uri $restUri -Headers $headers -Body $body
        Write-Host "Applied role '$RoleName' to Storage"
    
    }
    Catch [Microsoft.PowerShell.Commands.HttpResponseException] {
    
        if ($_.Exception.Response.StatusCode -eq 409) {
            Write-Host "Role already assigned: $RoleName" -ForegroundColor Yellow
        }
        elseif ($_.Exception.Response.StatusCode -eq 403) {
            Write-Host "ERROR: Canot assign role '$RoleName' - 'Forbidden'" -ForegroundColor Yellow
        }
        else {
            throw $_
        }
    }

}


function Assert-ResourceGroupExists($resourceGroupName) {

    $rg = $null

    try {
        $rg = Get-AzResourceGroup -Name $resourceGroupName
    }
    catch {
        
        if (!$rg) {
            # would like to throw 404 here, but am throwing 202 'Accepted' to stop retries
            $message = "Resource Group $resourceGroupName not found. Returning 202 to stop retries"
        }
        
        $body = @{
            "message" = $message
        } | ConvertTo-Json
        
        Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
                StatusCode = [HttpStatusCode]::Accepted
                Body       = $body
            }
        )
        
        exit
    }
}

function Get-ClientAccessToken() {
    
    $resourceURI = "https://management.azure.com/"
    $tokenAuthURI = $env:MSI_ENDPOINT + "?resource=$resourceURI&api-version=2017-09-01"
    $tokenResponse = Invoke-RestMethod -Method Get -Headers @{"Secret" = "$env:MSI_SECRET" } -Uri $tokenAuthURI
    return $tokenResponse.access_token
}

function Stop-WithHttp() {

    param (
        # Default is "Request Succeeded"
        [Parameter(Mandatory = $false)]
        [String] $Message,

        #  Default is OK/200
        [Parameter(Mandatory = $false)]
        [HttpStatusCode] $StatusCode
    )

    if (!$Message) {
        $Message = "Request Suceeded"
        $StatusCode = [HttpStatusCode]::OK
    }

    if (!$StatusCode) {
        $StatusCode = [HttpStatusCode]::OK
    }

    $body = @{
        "message" = $Message
    } | ConvertTo-Json

    Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
            StatusCode = $StatusCode
            Body       = $body
        }
    )

    exit
}

function Write-ItemAsJson {
    param(
        [Parameter(Mandatory = $true)]
        [String] $HeaderMessage,

        [Parameter(Mandatory = $true)]
        [System.Object] $Item
    )
    
    Write-Host ==============================================================================================================
    Write-Host $HeaderMessage
    Write-Host --------------------------------------------------------------------------------------------------------------
    Write-Host ($Item | ConvertTo-Json)
    Write-Host ==============================================================================================================

}

function Write-ItemsAsJSON {
`
    
    param(
        [Parameter(Mandatory = $true)]
        [String] $HeaderMessage,

        [Parameter(Mandatory = $true)]
        [System.Collections.Hashtable] $Items
    )
    
    Write-Host ==============================================================================================================
    Write-Host $HeaderMessage
    Write-Host --------------------------------------------------------------------------------------------------------------
    Write-Host ($Items  | ConvertTo-Json)
    Write-Host ==============================================================================================================

}