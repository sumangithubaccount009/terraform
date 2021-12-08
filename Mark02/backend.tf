
variable "suffix" {
  default = "backend"
}

resource "azurerm_resource_group" "bkend" {
  name     = "${var.suffix}-resources"
  location = "West Europe"
}


resource "azurerm_virtual_network_peering" "fe-be" {
  name                      = "fe-be"
  resource_group_name       = azurerm_resource_group.bkend.name
  virtual_network_name      = azurerm_virtual_network.bkend.name
  remote_virtual_network_id = azurerm_virtual_network.main.id
}

resource "azurerm_virtual_network_peering" "be-fe" {
  name                      = "be-fe"
  resource_group_name       = azurerm_resource_group.main.name
  virtual_network_name      = azurerm_virtual_network.main.name
  remote_virtual_network_id = azurerm_virtual_network.bkend.id
}



resource "azurerm_virtual_network" "bkend" {
  name                = "${var.suffix}-network"
  address_space       = ["10.0.0.0/24"]
  location            = azurerm_resource_group.bkend.location
  resource_group_name = azurerm_resource_group.bkend.name
}

resource "azurerm_subnet" "internal" {
  name                 = "internal"
  resource_group_name  = azurerm_resource_group.bkend.name
  virtual_network_name = azurerm_virtual_network.bkend.name
  address_prefixes     = ["10.0.0.0/26"]
}

/*
resource "azurerm_lb" "bkend" {
  name                = "${var.prefix}-nic"
  location            = azurerm_resource_group.bkend.location
  resource_group_name = azurerm_resource_group.bkend.name

  ip_configuration {
    name                          = "testconfiguration1"
    subnet_id                     = azurerm_subnet.internal.id
    private_ip_address_allocation = "Dynamic"

  }
}
*/
#nsg

resource "azurerm_subnet_network_security_group_association" "bkend" {

  subnet_id                 = azurerm_subnet.internal.id
  network_security_group_id = azurerm_network_security_group.bkend.id
}
resource "azurerm_network_security_group" "bkend" {
        name                = "${var.suffix}SecurityGroup1"
  location            = azurerm_resource_group.bkend.location
  resource_group_name = azurerm_resource_group.bkend.name

  security_rule {
    name                       = "rdp_allow"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = "${azurerm_lb.main.private_ip_address}"
    destination_address_prefix = "${azurerm_lb.bkend.private_ip_address}"
  }

  
}


resource "azurerm_lb" "bkend" {
  name                = "bkndlb"
  location            = azurerm_resource_group.bkend.location
  resource_group_name = azurerm_resource_group.bkend.name

  frontend_ip_configuration {
    name                 = "privateIPAddress"
    subnet_id                     = azurerm_subnet.internal.id
    private_ip_address_allocation = "Dynamic"
  }
}
resource "azurerm_lb_backend_address_pool" "bkend" {
  resource_group_name = azurerm_resource_group.bkend.name
  loadbalancer_id     = azurerm_lb.bkend.id
  name                = "BackEndAddressPool"
}
resource "azurerm_lb_nat_pool" "bkend" {
  resource_group_name            = azurerm_resource_group.bkend.name
  name                           = "rdp"
  loadbalancer_id                = azurerm_lb.bkend.id
  protocol                       = "Tcp"
  frontend_port_start            = 3389
  frontend_port_end              = 50119
  backend_port                   = 3389
  frontend_ip_configuration_name = "privateIPAddress"
}

resource "azurerm_lb_probe" "bkend" {
  resource_group_name = azurerm_resource_group.bkend.name
  loadbalancer_id     = azurerm_lb.bkend.id
  name                = "http-probe"
  protocol            = "Http"
  request_path        = "/health"
  port                = 8080
}
resource "azurerm_windows_virtual_machine_scale_set" "bkend" {
  name                = "be-vmss"
  resource_group_name = azurerm_resource_group.bkend.name
  location            = azurerm_resource_group.bkend.location
  sku                 = "Standard_F2"
  instances           = 1
  admin_password      = "P@55w0rd1234!"
  admin_username      = "adminuser"

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2016-Datacenter-Server-Core"
    version   = "latest"
  }

  os_disk {
    storage_account_type = "Standard_LRS"
    caching              = "ReadWrite"
  }
  network_interface {
    name    = "frontend-nic"
    primary = true

    ip_configuration {
      name                                   = "TestIPConfiguration"
      primary                                = true
      subnet_id                              = azurerm_subnet.internal.id
      load_balancer_backend_address_pool_ids = [azurerm_lb_backend_address_pool.bkend.id]
      load_balancer_inbound_nat_rules_ids    = [azurerm_lb_nat_pool.bkend.id]
    }
  }
 }
  resource "azurerm_virtual_machine_scale_set_extension" "bkend" {
  name                         = "IIS-extension"
  virtual_machine_scale_set_id = azurerm_windows_virtual_machine_scale_set.bkend.id
  publisher                    = "Microsoft.Compute"
  type                         = "CustomScriptExtension"
  type_handler_version         = "1.10"
  settings                     = <<SETTINGS
    {
        "commandToExecute": "powershell Install-WindowsFeature -name Web-Server -IncludeManagementTools;"
    }
SETTINGS

}