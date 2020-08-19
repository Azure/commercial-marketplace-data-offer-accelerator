zipFile='../install/publisher-azure/functionapp/functionapp.zip'
resourceGroup="<your resource group>"
functionAppName="<your function app>"

if [ -f $zipFile ]; then
    rm $zipFile
fi

cd ../../powershell-data-function

zip -r -D -n '.DS_Store' $zipFile .

if [ "$(which az)" = "" ]
then
    echo Azure CLI is required to update the functions app, installing now...
    curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
else
    echo Azure CLI found, continuing...
fi

az functionapp deployment source config-zip -g $resourceGroup -n $functionAppName --src $zipFile