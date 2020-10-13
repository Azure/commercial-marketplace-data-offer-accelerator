# Data Publisher - Deploy Resources to Azure

## Deploy to your Azure subscription

There are 4 ways to deploy the data publisher resources from this repository to your Azure subscription. You only need to choose one of these options.

1. [Use the "Deploy to Azure" button to deploy using the Azure portal](#option-1---deploy-using-azure-portal-and-github). 
**Note** this is the preferred way to deploy the required publisher resources to Azure. 

  >The following options should only be used by those familiar with technical aspects of Azure and are comfortable modifying and running scripts in PowerShell or the az CLI.

2. [Use PowerShell](#option-2---deploy-using-powershell)
3. [Use Azure CLI](#option-3---deploy-using-azure-az-cli)
4. [Clone this repo and deploy the template from your system](#option-4---clone-the-repo-and-deploy-from-your-machine)

<a href="https://youtu.be/FM9NlWo6eqk"><img src="./images/Video.png" width="50" style="float:left;align:left;" align="left" target="_blank"></a> <a href="https://youtu.be/FM9NlWo6eqk">Watch this video</a> showing of all of these technics to decide which is best for you. The installation techniques are further documented below. 

Pause at any time to work along with the video.

## What will be deployed to Azure

The following resources will be deployed to Azure when installing the data publisher environment.

1. A Resource Group to contain the needed services and resources
1. An Azure Data Share account
1. An Azure Function
    - A Storage account ued by the Azure Function - You should not need to interact with this Storage account.
    - An App Service to host the Azure Function.

## Option 1 - Deploy using Azure portal and GitHub

> **Note:** This is the preferred option for deplying the publisher resources to Azure and will be simplest for those not familiar with working with Azure through wither PowerShell or through the az CLI.

Deploy Data Publisher resources directly your Azure tenant. Sign in using the Azure subscription to be used to host the Data Share resources.

[![Deploy to Azure](https://azuredeploy.net/deploybutton.png)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FAzure%2Fcommercial-marketplace-data-offers%2Fmain%2Finstall%2Fpublisher-azure%2Fazuredeploy.json)

## Option 2 - Deploy using PowerShell

1. Copy the following code into a new __.ps1__ PowerShell script.
1. Make the changes to the script as indicated in the notes.
1. Run the script using the PowerShell

```powershell
$rgName="<your resource group name>"
$location="<region with Azure Data Share availability in the long format, such as - East US>"
$templateFile="./azuredeploy.json"

$resourceNamePrefix="<prefix for resources>"
$appServicePlan="B1"

# Create a resource group
New-AzResourceGroup -Name "$rgName" -Location "$location"

# Deploy the template
New-AzResourceGroupDeployment -ResourceGroupName "$rgName" -TemplateFile "$templateFile" -ResourceNamePrefix "$resourceNamePrefix" -ResourceLocation "$location" -AppServicePlan "$appServicePlan"
```

## Option 3 - Deploy using Azure az CLI

1. Copy the following code into a new __.sh__ shell script.
1. Make the changes to the script as indicated in the notes.
1. Run the script using the az CLI

```bash
rgName="<your resource group name>"
location="<region with Azure Data Share availability in the long format, such as - East US>"
templateFile="./azuredeploy.json"

resourceNamePrefix="<prefix for resources>"
appServicePlan="B1" # May be changed as suits your needs or upgraded later.

# Create a resource group
az group create --name "$rgName" --location "$location"

# Deploy the template
az deployment group create \
  --name ExampleDeployment \
  --resource-group "$rgName" \
  --template-file "$templateFile" \
  --parameters ResourceNamePrefix="$resourceNamePrefix" ResourceLocation="$location" AppServicePlan="$appServicePlan"
```
## Option 4 - Clone the repo and deploy from your machine

This template deploys the source code available at [/powershell-data-function](https://github.com/Azure/commercial-marketplace-data-offers/tree/main/powershell-data-function) using ZipDeploy. The zip file is located at https://github.com/Azure/commercial-marketplace-data-offers/tree/main/install/publisher-azure/functionapp

> In most cases, you can leave the *PackageURI* variable in the ARM template unchanged. However, if you are making any changes to the function app source code, please ensure that you are create a zip package that contains those changes and update the *PackageURI*  variable to point to the zip file where it can be accessed over the Internet. You can use SAS tokens if you are storing them in a storage account.

> **Note:** This applies to the PowerShell and Azure CLI deployments as well.

### The deployment files

Below if an illustration of the artifacts used to create the Azure services in your Azure tenant as a data publisher.

```
/install/publish-azure/
|
|─── azuredeploy.json ──> This ARM template deploys all services to share your data with consumers 
|─── azuredeploy.parameters.json ──> This ARM template parameter file is used if you want to automate the deployment process as part of your DevOps pipeline.
|─── functionapp/
    └─ functionapp.zip - this zip file contains the source code for a function app that is part of the solution
```
