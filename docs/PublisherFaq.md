# Publisher Frequently Asked Questions

## 1. Can I add new DataSets to an existing DataShare?

Currently, this scenario is not supported. Consumers do not have ability to accept a new DataSet when it is added to a pre-existing DataShare. We highly recommend creating DataSets that map to Blob Storage Containers so any new data can be put into a pre-existing DataSet.

**Problem**

>Given I am a data publisher  
And I already published a DataShare  
When I add a new DataSet to the DataShare  
Then my customers cannot receive this new DataSet

**Solution**

>Given I am a data publisher  
And I creating a new DataShare to sell  
When I create the DataShare  
And I am adding DataSets to my DataShare  
Then each new DataSet should map to a Blob Container in my raw data Storage Account  
And then I can add new data to the container in the future  
And the customer will receive the new data (as long as my DataShare is set to sync periodically)

## 2. How should I name my DataShares?