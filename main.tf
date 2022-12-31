# Configure the Azure provider and TF cloud
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0.2"
    }
  }

  required_version = ">= 1.1.0"
  /*
  cloud {
    organization = "Pines"
    workspaces {
      name = "development-workspace"
    }
  }
  */

}

provider "azurerm" {
  features {}
}

# Create a resource group
resource "azurerm_resource_group" "dev-rg" {
  name     = var.resource_group_name
  location = var.location_name

  tags = {
    Environment = "Dev"
    Team        = "DevOps"
  }
}

# Create a virtual network
resource "azurerm_virtual_network" "dev-vnet" {
  name                = "devTFVnet"
  address_space       = var.address_space_name
  location            = var.location_name
  resource_group_name = azurerm_resource_group.dev-rg.name
}

#creates subnets
resource "azurerm_subnet" "devTF-SN" {
  name                 = "devTF-pub-subnet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.dev-vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

#creates security group
resource "azurerm_network_security_group" "devTF-SG" {
  name                = "devTF-sg"
  location            = var.location_name
  resource_group_name = var.resource_group_name

  security_rule {
    name                       = "dev-rule-001"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = {
    Environment = "Dev"
  }
}

#creates subnet assosiation
resource "azurerm_subnet_network_security_group_association" "devTF-SGa" {
  subnet_id                 = azurerm_subnet.devTF-SN.id
  network_security_group_id = azurerm_network_security_group.devTF-SG.id
}

#creates public IP
resource "azurerm_public_ip" "devTF-ip" {
  name                = "devTF-public-ip"
  resource_group_name = var.resource_group_name
  location            = var.location_name
  allocation_method   = "Dynamic"

  tags = {
    Environment = "Dev"
  }
}

#creates network interface
resource "azurerm_network_interface" "devTF-nic" {
  name                = "devTF-nic"
  location            = var.location_name
  resource_group_name = var.resource_group_name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.devTF-SN.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.devTF-ip.id
  }

  tags = {
    "Environment" = "Dev"
  }
}

#creates a vitual machine
resource "azurerm_linux_virtual_machine" "devTF-VM" {
  name                  = "devTF-virtual-machine"
  resource_group_name   = var.resource_group_name
  location              = var.location_name
  size                  = "Standard_B1s"
  admin_username        = "adminuser"
  network_interface_ids = [azurerm_network_interface.devTF-nic.id]

  custom_data = filebase64("./custom_data.tpl")

  admin_ssh_key {
    username   = "adminuser"
    public_key = file("./devTFazurekey.pub")
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "18.04-LTS"
    version   = "latest"
  }


  /*provisioner "local-exec" {
    command = templatefile("${var.host_os}-ssh-script.tpl", {
      hostname     = self.public_ip_address,
      user         = "adminuser",
      identityfile = "~/.ssh/devTFazurekey"
    })
    interpreter = ["bash", "-c"]
  }*/

  tags = {
    "Environment" = "Dev"
  }
}

#data source pub ip
data "azurerm_public_ip" "devTF-ip-data" {
  name                = azurerm_public_ip.devTF-ip.name
  resource_group_name = var.resource_group_name
}
#create output
output "public_ip_address" {
  value = "${azurerm_linux_virtual_machine.devTF-VM.name}:${data.azurerm_public_ip.devTF-ip-data.ip_address}"

}