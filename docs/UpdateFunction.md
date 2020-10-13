# Updating the Azure Function code

The Azure Function you deployed into your publisher tenant may receive updates from time to time. Rather than redeploying all publisher resources, this page shows how to deploy just the Azure Function code.

**You will be notified by your Azure Marketplace team if you need to update your Azure Function.**.

There are 2 options for updating your funciton code, one using PowerShell and another using the Azure CLI. Both techniques will work on Mac, Linux, or Windows so long as you have the correct dependencies installed.

## Notes

1. Download the repo contents as a ZIP file or clone the code to your local hard drive. If you choose to download the ZIP file from this repository, unzip it to your local hard drive.

1. Locate the update scripts here 
    - PowerShell - `/install/util/UpdateFunctionApp.ps1`
    - az CLI - `/install/util/updateFunctionApp.sh`

## Option 1 - PowerShell Script

Set the 2 variables at the top of the script to values that match your environment.

```powershell
$resourceGroup = "<your resource group name>"
$functionAppName = "<your function name>"
```

After setting the variables in the script, execute it on the PowerShell command line.

## Option 2 - az CLI Shell Script

Set the 2 variables at the top of the script to values that match your environment.

```bash
resourceGroup="<your resource group>"
functionAppName="<your function app>"
```

After setting the variables in the script, execute it on the az CLI command line.


