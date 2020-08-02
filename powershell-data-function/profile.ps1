# Azure Functions profile.ps1
#
# This profile.ps1 will get executed every "cold start" of your Function App.
# "cold start" occurs when:
#
# * A Function App starts up for the very first time
# * A Function App starts up after being de-allocated due to inactivity
#
# You can define helper functions, run commands, or specify environment variables
# NOTE: any variables defined that are not environment variables will get reset after the first execution

# Authenticate with Azure PowerShell using MSI.
# Remove this if you are not planning on using MSI or Azure PowerShell.
# if ($env:MSI_SECRET -and (Get-Module -ListAvailable Az.Accounts)) {
#     Connect-AzAccount -Identity
# }

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

function Stop-WithHttpOK ($message) {
    
    if (!$message) {
        $message = "Request Suceeded"
    }

    $body = @{
        "message" = $message
    } | ConvertTo-Json

    Push-OutputBinding -Name Response -Value ([HttpResponseContext]@{
            StatusCode = [HttpStatusCode]::OK
            Body       = $body
        }
    )

    exit
}

function Write-Request ($request) {
    Write-Host ==============================================================================================================
    Write-Host Showing Request
    Write-Host ($request | ConvertTo-Json)
    Write-Host ==============================================================================================================
}

function Write-ManagedAppVariables() {

    Write-Host ==============================================================================================================
    Write-Host mIdentity $global:mIdentity
    Write-Host --------------------------------------------------------------------------------------------------------------
    Write-Host JSON
    Write-Host --------------------------------------------------------------------------------------------------------------
    # Write-Host mApplication ($mApplication | ConvertTo-Json)
    Write-Host --------------------------------------------------------------------------------------------------------------
    Write-Host mApplicationResource ($global:mApplicationResource | ConvertTo-Json)
    Write-Host ==============================================================================================================
    Write-Host mDataShareAccount ($global:mDataShareAccount | ConvertTo-Json)
    Write-Host --------------------------------------------------------------------------------------------------------------
    Write-Host mStorageAccount ($globalmStorageAccount | ConvertTo-Json)
    Write-Host ==============================================================================================================
}
function Write-DataShare ($dataShare) {

    Write-Host ------------------------------------------------------
    Write-Host "Data Share"
    Write-Host ------------------------------------------------------
    Write-Host "dataShare.CreatedBy: $($dataShare.CreatedBy)"
    Write-Host "dataShare.Description: $($dataShare.Description)"
    Write-Host "dataShare.Id: $($dataShare.Id)"
    Write-Host "dataShare.Name: $($dataShare.Name)"
    Write-Host "dataShare.ProvisioningState: $($dataShare.ProvisioningState)"
    Write-Host "dataShare.ShareKind: $($dataShare.ShareKind)"
    Write-Host "dataShare.Type: $($dataShare.Type)"
    Write-Host ------------------------------------------------------

}

function Write-Invitation ($invitation) {
    
    Write-Host ------------------------------------------------------
    Write-Host "Invitation"
    Write-Host ------------------------------------------------------
    Write-Host "invitation.CreatedBy: $($invitation.CreatedBy)"
    Write-Host "invitation.Description: $($invitation.Description)"
    Write-Host "invitation.Id: $($invitation.Id)"
    Write-Host "invitation.InvitationId: $($invitation.InvitationId)"
    Write-Host "invitation.InvitationStatus: $($invitation.InvitationStatus)"
    Write-Host "invitation.Name: $($invitation.Name)"
    Write-Host "invitation.ProvisioningState: $($invitation.ProvisioningState)"
    Write-Host "invitation.ShareKind: $($invitation.ShareKind)"
    Write-Host "invitation.Type: $($invitation.Type)"
    Write-Host ------------------------------------------------------

}
