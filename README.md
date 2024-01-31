# Azure Data Accelerator

The documentation for this project is currently under development.

**This project is currently in proof-of-concept stage.**

This PoC enables selling and purchasing of raw data within the Azure Marketplace.

## Publisher Install

Deploy Data Publisher resources directly your Azure tenant. When prompted, sign into Azure using the subscription to be used to host the Data Share resources.

[View the code](https://github.com/Azure/commercial-marketplace-data-offer-accelerator/tree/adls-gen-2)

[Deploy to Azure](https://portal.azure.com/#create/Microsoft.Template/uri/https%3A%2F%2Fraw.githubusercontent.com%2FAzure%2Fcommercial-marketplace-data-offer-accelerator%2Fadls-gen-2%2Finstall%2Fpublisher-azure%2Fazuredeploy.json)

---

## Instructions below this level are in development

Below are instructions, videos, and helpful resources to publish Data Offers on the Azure Marketplace and understand the purchase experience. We strongly recommend watching the Logical architecture overview first to get a picture of how the entire system works.

1. [Logical architecture overview](docs/Architecture.md)
1. [Deploy publisher Azure resources](docs/PublisherDeployToAzure.md)
1. [Assign Permissions for raw Data Storage accounts](docs/SetPermissionsOnRawData.md)
1. [Create a Data Share in your Data Share account](docs/CreateDataShare.md)
1. [Creating a Plan for your Azure Marketplace Offer in Partner Center](docs/CreatePlan.md)
1. [Purchasing a Data Offer as a consumer](docs/PurchaseDataOffer.md)

### Other actions

- [Publisher FAQ](./docs/PublisherFaq.md)
- [Setting Up Your Raw Data](docs/RawData.md)
- [Updating the Azure Function Code](docs/UpdateFunction.md)


## Other Marketplace Resources

Following are links to additional resources about the Azure Marketplace and the Partner Center portal. These resources are provided to help with the publishing process and other aspects of selling your solution in the Azure Marketplace.

- [Welcome to the Azure Marketplace](https://docs.microsoft.com/en-us/azure/marketplace/)
- [Working with the Partner Center Portal](https://docs.microsoft.com/en-us/azure/marketplace/partner-center-portal/commercial-marketplace-overview)
- [Creating an Azure Application Offer](https://docs.microsoft.com/en-us/azure/marketplace/partner-center-portal/create-new-azure-apps-offer)
