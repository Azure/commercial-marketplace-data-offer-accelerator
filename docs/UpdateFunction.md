# Update the Azure function code

The Azure Function you deployed into your publisher tenant may receive updates from time to time. Rather than redeploying all publisher resources, this page shows how to deploy just the Azure Function code.

## Notes

The Azure Function code was last published: **8/21/2020**

1. Download or clone the code to your local hard drive.
1. Locate the update scripts here 
    - PowerShell - `/install/util/UpdateFunctionApp.ps1`
    - az CLI - `/install/util/updateFunctionApp.sh`

## PowerShell Script

Set the 2 variables at the top of the script to values that match your environment.

```powershell
$resourceGroup = "<your resource group name>"
$functionAppName = "<your function name>"
```

After setting the variables in the script, execute it on the PowerShell command line.

## az CLI Shell Script

Set the 2 variables at the top of the script to values that match your environment.

```bash
resourceGroup="<your resource group>"
functionAppName="<your function app>"
```

After setting the variables in the script, execute it on the terminal command line.


