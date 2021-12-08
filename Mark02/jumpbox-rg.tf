provider "azurerm" {
  version="2.56.0"
  features {}
}

variable "prefix" {
  default = "frontend"
}

resource "azurerm_resource_group" "main" {
  name     = "${var.prefix}-resources"
  location = "West Europe"
}


resource "azurerm_virtual_network" "main" {
  name                = "${var.prefix}-network"
  address_space       = ["10.1.0.0/24"]
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
}

resource "azurerm_subnet" "external" {
  name                 = "external"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.1.0.0/26"]
}

resource "azurerm_subnet" "AzureFirewallSubnet" {
  name                 = "AzureFirewallSubnet"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.1.0.64/26"]
}

/*

resource "azurerm_lb" "main" {
  name                = "${var.prefix}-nic"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  ip_configuration {
    name                          = "testconfiguration1"
    subnet_id                     = azurerm_subnet.external.id
    private_ip_address_allocation = "static"

  }
}

*/
resource "azurerm_firewall" "fire" {
      name                = "${var.prefix}-firewall"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  ip_configuration {
    name                 = "configuration"
    subnet_id            = azurerm_subnet.AzureFirewallSubnet.id
    public_ip_address_id = azurerm_public_ip.pip.id
  }
  
}


resource "azurerm_firewall_nat_rule_collection" "main" {
  name                = "testcollection"
  azure_firewall_name = azurerm_firewall.fire.name
  resource_group_name = azurerm_resource_group.main.name
  priority            = 100
  action              = "Dnat"

  rule {
    name = "web-rule"
    source_addresses = [
      "*",
    ]
    destination_ports = [
      "80",
    ]
    destination_addresses = [
      azurerm_public_ip.pip.ip_address
    ]
    translated_port    = 80
    translated_address = "${azurerm_lb.main.private_ip_address}"

    protocols = [
      "TCP",
    ]
  }

  rule {
    name = "allowrdp"

    source_addresses = [
      "*",
    ]

    destination_ports = [
      "3389",
    ]

    destination_addresses = [
      azurerm_public_ip.pip.ip_address
    ]

    translated_port = 3389

    translated_address = "${azurerm_lb.main.private_ip_address}"

    protocols = [
      "TCP"
    ]
  }
}


#nsg

resource "azurerm_subnet_network_security_group_association" "main" {

  subnet_id                 = azurerm_subnet.external.id
  network_security_group_id = azurerm_network_security_group.main.id
}
resource "azurerm_network_security_group" "main" {
        name                = "${var.prefix}SecurityGroup1"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  security_rule {
    name                       = "rdp_allow"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  
}



resource "azurerm_public_ip" "pip" {
  name                = "${var.prefix}PublicIp1"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  allocation_method   = "Static"
  sku                 =  "standard"
  
}

resource "azurerm_lb" "main" {
  name                = "frntndlb"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  frontend_ip_configuration {
    name                 = "privateIPAddress"
    subnet_id                     = azurerm_subnet.internal.id
    private_ip_address_allocation = "Dynamic"
  }
}
resource "azurerm_lb_backend_address_pool" "main" {
  resource_group_name = azurerm_resource_group.main.name
  loadbalancer_id     = azurerm_lb.main.id
  name                = "BackEndAddressPool"
}
resource "azurerm_lb_nat_pool" "main" {
  resource_group_name            = azurerm_resource_group.main.name
  name                           = "rdp"
  loadbalancer_id                = azurerm_lb.main.id
  protocol                       = "Tcp"
  frontend_port_start            = 3389
  frontend_port_end              = 50119
  backend_port                   = 3389
  frontend_ip_configuration_name = "privateIPAddress"
}

resource "azurerm_lb_probe" "main" {
  resource_group_name = azurerm_resource_group.main.name
  loadbalancer_id     = azurerm_lb.main.id
  name                = "http-probe"
  protocol            = "Http"
  request_path        = "/health"
  port                = 8080
}
resource "azurerm_windows_virtual_machine_scale_set" "main" {
  name                = "jb-vmss"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  sku                 = "Standard_F2"
  instances           = 1
  admin_password      = "rd "
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
    name    = "backend-nic"
    primary = true

    ip_configuration {
      name                                   = "TestIPConfiguration"
      primary                                = true
      subnet_id                              = azurerm_subnet.internal.id
      load_balancer_backend_address_pool_ids = [azurerm_lb_backend_address_pool.main.id]
      load_balancer_inbound_nat_rules_ids    = [azurerm_lb_nat_pool.main.id]
    }
  }
 }