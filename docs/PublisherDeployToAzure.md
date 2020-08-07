# Data Publisher - Deploy Resources to Azure

This folder contains the technical artifacts that you can use to create the Azure services in your Azure tenant as a publisher.

### The dployment files
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

This deployment is based on ARM templates. This ARM template requires designating a resource name prefix and a location where Azure Data Share accounts is available. The resource name prefix is used in constructing a name for each resource created as part of the depployment. 

### Deploy this to your Azure subscription

There are 3 ways to deploy this ARM tempalte to your Azure subscription. Use the "Deploy 
to Azure" button to deploy using the Azure portal. You may also use PowerShell or the Azure CLI.

#### Deploy using Azure portal

Deploy Data Publisher resources directly your Azure.

[![Deploy to Azure](https://azuredeploy.net/deploybutton.png)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FAzure%2Fcommercial-marketplace-data-offers%2Fmain%2Finstall%2Fpublisher-azure%2Fazuredeploy.json)

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
