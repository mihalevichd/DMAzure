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
# Intentionally Vulnerable Storage Account for Backups
resource "azurerm_storage_account" "backup_account" {
  name                     = "wiztaskybackup" # <-- CHANGE THIS TO A UNIQUE NAME
  resource_group_name      = azurerm_resource_group.wiz_rg.name
  location                 = azurerm_resource_group.wiz_rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  # VULNERABILITY 1: Allowing public network access
  public_network_access_enabled = true

  # VULNERABILITY 2: Allowing public blob access (Anonymous access)
  allow_nested_items_to_be_public = true 
}

# The container inside the account to hold the "backups"
resource "azurerm_storage_container" "backup_container" {
  name                  = "db-backups"
  storage_account_name  = azurerm_storage_account.backup_account.name
  
  # VULNERABILITY 3: Setting the container to allow public anonymous read access
  container_access_type = "container" 
}
# 1. Public IP Address (VULNERABILITY: Giving the DB a public IP)
resource "azurerm_public_ip" "mongo_pip" {
  name                = "pip-wiz-mongo"
  resource_group_name = azurerm_resource_group.wiz_rg.name
  location            = azurerm_resource_group.wiz_rg.location
  allocation_method   = "Dynamic"
}

# 2. Network Security Group (VULNERABILITY: Exposing ports to the internet)
resource "azurerm_network_security_group" "mongo_nsg" {
  name                = "nsg-wiz-mongo"
  location            = azurerm_resource_group.wiz_rg.location
  resource_group_name = azurerm_resource_group.wiz_rg.name

  # Allow SSH from anywhere
  security_rule {
    name                       = "SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # Allow MongoDB from anywhere
  security_rule {
    name                       = "MongoDB"
    priority                   = 1002
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "27017"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# 3. Network Interface Card
resource "azurerm_network_interface" "mongo_nic" {
  name                = "nic-wiz-mongo"
  location            = azurerm_resource_group.wiz_rg.location
  resource_group_name = azurerm_resource_group.wiz_rg.name

  ip_configuration {
    name                          = "internal"
    # NOTE: Ensure the subnet name matches what is in your code from earlier!
    # If your subnet block is named differently (e.g., azurerm_subnet.public), update it here:
    subnet_id                     = azurerm_subnet.public_subnet.id 
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.mongo_pip.id
  }
}

# 4. Attach the NSG to the NIC
resource "azurerm_network_interface_security_group_association" "mongo_nsg_assoc" {
  network_interface_id      = azurerm_network_interface.mongo_nic.id
  network_security_group_id = azurerm_network_security_group.mongo_nsg.id
}

# 5. The Virtual Machine (VULNERABILITY: Weak passwords & unauthenticated DB)
resource "azurerm_linux_virtual_machine" "mongo_vm" {
  name                            = "vm-wiz-mongo"
  resource_group_name             = azurerm_resource_group.wiz_rg.name
  location                        = azurerm_resource_group.wiz_rg.location
  size                            = "Standard_B1s"
  admin_username                  = "wizadmin"
  
  # Using a weak, hardcoded password instead of SSH keys
  admin_password                  = "WizExercise123!"
  disable_password_authentication = false

  network_interface_ids = [
    azurerm_network_interface.mongo_nic.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }

  # This script runs on boot to install MongoDB and open it to the world
  custom_data = base64encode(<<-EOF
    #!/bin/bash
    apt-get update
    apt-get install -y mongodb
    sed -i 's/bind_ip = 127.0.0.1/bind_ip = 0.0.0.0/' /etc/mongodb.conf
    systemctl restart mongodb
  EOF
  )
}
