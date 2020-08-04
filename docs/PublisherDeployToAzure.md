# Azure Data Share Service ARM Template

This folder contains the technical artifacts that you can use to create the Azure services in your Azure tenant as a publisher.

### Folder Structure
```
This folder
|
|─── azuredeploy.json ──> this ARM template deploys all services to share your data with external and internal consumers 
|
|─── azuredeploy.parameters.json ──> this is the ARM template parameter file to used if you want to automate this process as part of your DevOps pipeline
|
|─── functionapp
    |
    └─ functionapp.zip - this zip file contains the source code for the function app that configures the Azure Data Share services for your customers
```

### What Azure services will be created after this deployment?

This ARM template requires a resource name prefix and a location where Azure Data Share service is available. The resource name prefix is used to create a unique name for the resources that are created as part of the depployment. Following is a list of resources that are created -

1. Azure Data Share account
2. Function app using the source availble in the functionapp directory
3. Storage account for the function app
4. App Service plan for the function app

### Deploy this to your Azure subscription

#### Deploy using Azure portal -
[![Deploy to Azure](https://azuredeploy.net/deploybutton.png)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FAzure%2Fcommercial-marketplace-data-offers%2Fmain%2Finstall%2Fpublisher-azure%2Fazuredeploy.json)

#### Deploy using PowerShell


```
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

```
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
