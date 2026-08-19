# Create a Resource Group for the exercise
resource "azurerm_resource_group" "wiz_rg" {
  name     = "rg-wiz-exercise"
  location = "East US"
}

# Create the Virtual Network
resource "azurerm_virtual_network" "wiz_vnet" {
  name                = "vnet-wiz-exercise"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.wiz_rg.location
  resource_group_name = azurerm_resource_group.wiz_rg.name
}

# Create the Public Subnet (For the MongoDB VM)
resource "azurerm_subnet" "public_subnet" {
  name                 = "snet-public"
  resource_group_name  = azurerm_resource_group.wiz_rg.name
  virtual_network_name = azurerm_virtual_network.wiz_vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Create the Private Subnet (For the Kubernetes Cluster)
resource "azurerm_subnet" "private_subnet" {
  name                 = "snet-private"
  resource_group_name  = azurerm_resource_group.wiz_rg.name
  virtual_network_name = azurerm_virtual_network.wiz_vnet.name
  address_prefixes     = ["10.0.2.0/24"]
}
