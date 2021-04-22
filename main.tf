# Please use terraform v12.29 to start with for all labs, I will use terraform v13 from lab 7.5 onwards

variable "refix" {
  default = "tfvmex"
}
resource "azurerm_resource_group" "main" {
  name     = "${var.refix}-resources"
  location = "West Europe"
}