# a script to zip the deployment package for a plan
# this script ensure no OS files are included from non-Windows systems
rm ../partner-center-config/app.zip
zip ../partner-center-config/app.zip createUiDefinition.json mainTemplate.json viewDefinition.json ./nestedtemplates/storageAccount.json