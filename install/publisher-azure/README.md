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

### Deploy this to your Azure subscription

[![Deploy to Azure](https://azuredeploy.net/deploybutton.png)](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FAzure%2Fcommercial-marketplace-data-offers%2Fmain%2Finstall%2Fpublisher-azure%2Fazuredeploy.json)

You can also deploy this template using PowerShell or Azure CLI.