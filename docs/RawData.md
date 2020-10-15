# Configuring Raw Data

Setting up your raw data resources is the first step in onboarding your Data Offer. We recommend you reach out to your Azure Marketplace onboarding team for a conversation about your raw data structure and information architecture, so that you can establish a sustainable structure and conventions for your raw data from the very beginning.

Although there are other ways to set up your raw data, we recommend the following configuration, as described in the [Logical Architecture documentation](./Architecture.md).

The below steps assume basic familiarity with Azure and creating Azure services.

1. Create an Azure AD tenant especially dedicated to hosting the resources and services of your Data Offer.
1. In your new AAD tenant, create a resource group dedicated to housing Azure Storage accounts that will contain your raw data.
1. Create an Azure Storage account within your raw data resource group.
1. Upload data into your new Azure Storage account.

> **Note:** Although this is the recommended approach to organizing your raw data, there are many ways to configure your raw data for storage within one or more Storage accounts. This is why we recommend you consult with your Data Offer onboarding team during this phase, especially for your first Data Marketplace Offer.