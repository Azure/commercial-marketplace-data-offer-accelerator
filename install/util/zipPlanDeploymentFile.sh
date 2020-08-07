# this script file creates the app.zip file to be uploaded for each Offer > Plan in Partner Center
# the output file goes to the "partner-center-config/app.zip" folder
# this script ensure no OS files are included from non-Windows systems

zipFile='../partner-center-config/app.zip'

if [ -f $zipFile ]; then
    rm $zipFile
fi

cd ../partner-center-zip

zip -r -D -n '.DS_Store' $zipFile .