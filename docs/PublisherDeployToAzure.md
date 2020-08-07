# Data Publisher - Deploy Resources to Azure

### Deploy this to your Azure subscription

There are 4 ways to deploy this ARM template from this repo to your Azure subscription as described below.

1. Use the "Deploy to Azure" button to deploy using the Azure portal
2. Clone this repo and deploy the template from your system
3. Use PowerShell
4. Use Azure CLI.

This folder contains the technical artifacts  you can use to create the Azure services in your Azure tenant as a publisher.

### The deployment files
```
This folder
|
|─── azuredeploy.json ──> this ARM template deploys all services to share your data with consumers 
|─── azuredeploy.parameters.json ──> this is the ARM template parameter file to use if you want to automate this process as part of your DevOps pipeline
|─── functionapp
    └─ functionapp.zip - this zip file contains the source code for a function app that is part of the solution
```

### What will be deployed to Azure

The following resources will be deployed to Azure when installing the Data Publisher environment.

1. A Resource Group to contain the other resources
1. An Azure Data Share account
1. A Azure Function whose source is located in the functionapp.zip referenced above
    - A Storage account ued by the Azure Function
    - An App Service to host the Azure Function

This deployment is based on ARM templates. This ARM template requires designating a resource name prefix and a location where Azure Data Share accounts is available. The resource name prefix is used in constructing a name for each resource created as part of the deployment. 

#### Deploy using Azure portal

Deploy Data Publisher resources directly your Azure.

[![Deploy to Azure](https://azuredeploy.net/deploybutton.png)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FAzure%2Fcommercial-marketplace-data-offers%2Fmain%2Finstall%2Fpublisher-azure%2Fazuredeploy.json)

#### Clone this repo and deploy the template from your system

This template deploys the source code available at [/powershell-data-function](https://github.com/Azure/commercial-marketplace-data-offers/tree/main/powershell-data-function) using ZipDeploy. The zip file is located at https://github.com/Azure/commercial-marketplace-data-offers/tree/main/install/publisher-azure/functionapp

In most cases, you can leave the *PackageURI* variable in the ARM template unchanged. However, if you are making any changes to the function app source code, please ensure that you are create a zip package that contains those changes and update the *PackageURI*  variable to point to the zip file where it can be accessed over the Internet. You can use SAS tokens if you are storing them in a storage account.

```
Note: This applies to the PowerShell and Azure CLI deployments as well.
```

#### Deploy using PowerShell

```powershell
$rgName="<your resource group name>"
$location="<region with Azure Data Share availability>"
$templateUri="https://raw.githubusercontent.com/Azure/commercial-marketplace-data-offers/main/install/publisher-azure/azuredeploy.json"

$resourceNamePrefix="<prefix for resources>"
$appServicePlan="B1"

# Create a resource group
New-AzResourceGroup -Name $rgName -Location $location

# Deploy the template
New-AzResourceGroupDeployment -ResourceGroupName $rgName -TemplateFile $templateUri -ResourceNamePrefix $resourceNamePrefix -ResourceLocation $location -AppServicePlan $appServicePlan
```

#### Deploy using Azure CLI

```bash
rgName="<your resource group name>"
location="<region with Azure Data Share availability>"
templateUri="https://raw.githubusercontent.com/Azure/commercial-marketplace-data-offers/main/install/publisher-azure/azuredeploy.json"

resourceNamePrefix="<prefix for resources>"
appServicePlan="B1"

# Create a resource group
az group create --name $rgName --location $location

# Deploy the template
az deployment group create \
  --name ExampleDeployment \
  --resource-group $rgName \
  --template-file $templateUri \
  --parameters ResourceNamePrefix=$resourceNamePrefix ResourceLocation=$location AppServicePlan=$appServicePlan
```
