# this script file creates the app.zip file to be uploaded for each Offer > Plan in Partner Center
# the "app.zip" output file goes to the "partner-center-config" folder
# this script ensure no OS files are included from non-Windows systems

zipFile='../partner-center-config/app.zip'

if [ -f $zipFile ]; then
    rm 4zipFile
fi

zip -m -r -n '.DS_Store' $zipFile ../partner-center-zip