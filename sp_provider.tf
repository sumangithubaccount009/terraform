# an azure provider configuration, using service principal account.
# create a service principal by running the following command in azure cli
#az ad sp create-for-rbac --role="Contributor" --scopes="/subscriptions/SUBSCRIPTION_ID"
/* we will get following output after running the above command.
{
  "appId": "00000000-0000-0000-0000-000000000000",
  "displayName": "azure-cli-2017-06-05-10-41-15",
  "name": "http://azure-cli-2017-06-05-10-41-15",
  "password": "0000-0000-0000-0000-000000000000",
  "tenant": "00000000-0000-0000-0000-000000000000"
}
you can test these login details by running this command
az login --service-principal -u CLIENT_ID -p CLIENT_SECRET --tenant TENANT_ID
*/

# Please use terraform v12.29 to start with for all labs, I will use terraform v13 from lab 7.5 onwards
provider "azurerm" {
  # Whilst version is optional, we /strongly recommend/ using it to pin the version of the Provider being used
  version = "=2.4.0"

  subscription_id = "edde3a05-76ec-432c-839b-9a38e79a4668"
  client_id       = "c5edba68-968f-43d6-bed0-10f8e0f5ff21"
  client_secret   = "442e3cbb-d3f3-4207-b579-3ff6225f6fa2"
  tenant_id       = "aR1F0oTP4U~rp-A26shjkKt7lz7LK_~Ms_"

  features {}
}