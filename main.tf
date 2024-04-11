
# IDENTITY ###########
resource "azurerm_resource_group" "platform_identity_rg" {
  name     = "Identity"
  location = "East US"
}

resource "azurerm_key_vault" "project-keyvault78907" {
  name                        = "project-keyvault78907"
  location                    = azurerm_resource_group.platform_identity_rg.location
  resource_group_name         = azurerm_resource_group.platform_identity_rg.name
  enabled_for_disk_encryption = true
  tenant_id                   = var.tenant_id
  sku_name                    = "standard"
}

resource "azurerm_key_vault_access_policy" "project-keyvault-accesspolicy" {
  key_vault_id            = azurerm_key_vault.project-keyvault78907.id
  tenant_id               = var.tenant_id
  object_id               = var.object_id
  secret_permissions      = ["Get", "List"]
  certificate_permissions = ["Get", "List"]
  key_permissions         = ["Get", "List"]
  depends_on              = [azurerm_key_vault.project-keyvault78907]
}

resource "azurerm_security_center_workspace" "project-security" {
  scope        = "/subscriptions/${var.subscription_id}"
  workspace_id = azurerm_log_analytics_workspace.project-security-logs.id
  depends_on   = [azurerm_log_analytics_workspace.project-security-logs]
}

resource "azurerm_policy_definition" "vm_size_policy" {
  name         = "Restrict VM Sizes"
  display_name = "Restrict VM Sizes"
  description  = "Restrict virtual machine sizes in the specified resource groups"
  policy_type  = "Custom"
  mode         = "All"


  policy_rule = <<POLICY_RULE
{
  "if": {
    "allOf": [
      {
        "field": "type",
        "equals": "Microsoft.Compute/virtualMachines"
      },
      {
        "not": {
          "field": "Microsoft.Compute/virtualMachines/sku.name",
          "in": [
            "Standard_B1ls",
            "Standard_B1s",
            "Standard_B1ms"
          ]
        }
      }
    ]
  },
  "then": {
    "effect": "deny"
  }
}
POLICY_RULE
}

resource "azurerm_resource_group_policy_assignment" "platform_vm_size_policy" {
  name                 = "platform-vm-size-policy"
  resource_group_id    = azurerm_resource_group.platform_management_rg.id
  policy_definition_id = azurerm_policy_definition.vm_size_policy.id
}

resource "azurerm_resource_group_policy_assignment" "application_vm_size_policy" {
  name                 = "application-vm-size-policy"
  resource_group_id    = azurerm_resource_group.application_rg.id
  policy_definition_id = azurerm_policy_definition.vm_size_policy.id
}


# MANAGEMENT #################
resource "azurerm_resource_group" "platform_management_rg" {
  name     = "Management"
  location = "East US"
}

resource "azurerm_log_analytics_workspace" "project-general-logs" {
  name                = "project-general-logs"
  location            = azurerm_resource_group.platform_management_rg.location
  resource_group_name = azurerm_resource_group.platform_management_rg.name
  sku                 = "PerGB2018"
}

resource "azurerm_log_analytics_workspace" "project-security-logs" {
  name                = "project-security-logs"
  location            = azurerm_resource_group.platform_management_rg.location
  resource_group_name = azurerm_resource_group.platform_management_rg.name
  sku                 = "PerGB2018"
}

#NETWORK ####################
resource "azurerm_resource_group" "platform_network_rg" {
  name     = "Network"
  location = "East US"
}

resource "azurerm_virtual_network" "project-vnet" {
  name                = "project-vnet"
  address_space       = ["10.9.0.0/24"]
  location            = azurerm_resource_group.platform_network_rg.location
  resource_group_name = azurerm_resource_group.platform_network_rg.name
}

resource "azurerm_subnet" "AzureFirewallSubnet" {
  name                 = "AzureFirewallSubnet"
  resource_group_name  = azurerm_resource_group.platform_network_rg.name
  virtual_network_name = azurerm_virtual_network.project-vnet.name
  address_prefixes     = ["10.9.1.0/24"]
}

resource "azurerm_virtual_wan" "project-vwan" {
  name                = "project-vwan"
  location            = azurerm_resource_group.platform_network_rg.location
  resource_group_name = azurerm_resource_group.platform_network_rg.name
}

resource "azurerm_virtual_hub" "project-hub" {
  name                = "project-hub"
  resource_group_name = azurerm_resource_group.platform_network_rg.name
  location            = azurerm_resource_group.platform_network_rg.location
  virtual_wan_id      = azurerm_virtual_wan.project-vwan.id
  address_prefix      = "10.7.0.0/24"
}

resource "azurerm_virtual_hub_connection" "vnet-hub-connection" {
  name                      = "vnet-hub-connection"
  virtual_hub_id            = azurerm_virtual_hub.project-hub.id
  remote_virtual_network_id = azurerm_virtual_network.project-vnet.id
  depends_on                = [azurerm_virtual_network.project-vnet]
}

# Define resources
resource "azurerm_network_security_group" "platform_Nsg" {
  name                = "project-nsg"
  location            = azurerm_resource_group.platform_network_rg.location
  resource_group_name = azurerm_resource_group.platform_network_rg.name
}

resource "azurerm_application_security_group" "platform_Asg" {
  name                = "project-asg"
  location            = azurerm_resource_group.platform_network_rg.location
  resource_group_name = azurerm_resource_group.platform_network_rg.name
}

resource "azurerm_public_ip" "platform_public_ip" {
  name                = "project-public-ip"
  location            = azurerm_resource_group.platform_network_rg.location
  resource_group_name = azurerm_resource_group.platform_network_rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_firewall" "platform_firewall" {
  name                = "project-firewall"
  location            = azurerm_resource_group.platform_network_rg.location
  resource_group_name = azurerm_resource_group.platform_network_rg.name
  sku_tier            = "Standard"
  sku_name            = "AZFW_VNet"

  ip_configuration {
    name                 = "FirewallIpConfig"
    public_ip_address_id = azurerm_public_ip.platform_public_ip.id
    subnet_id            = azurerm_subnet.AzureFirewallSubnet.id
  }
}

resource "azurerm_firewall_network_rule_collection" "example" {
  name                = "Allow_HTTPS"
  resource_group_name = azurerm_resource_group.platform_network_rg.name
  azure_firewall_name = azurerm_firewall.platform_firewall.name
  priority            = 110
  action              = "Allow"

  rule {
    name                  = "Allow_HTTPS"
    source_addresses      = ["*"]
    destination_addresses = ["10.0.1.0/24"]
    destination_ports     = ["443"]
    protocols             = ["TCP"]
  }
}

resource "azurerm_dns_zone" "platform_dns_zone" {
  name                = "cloudhirsi.com"
  resource_group_name = azurerm_resource_group.platform_network_rg.name
}

resource "azurerm_dns_a_record" "dns_a_record" {
  name                = "project"
  zone_name           = azurerm_dns_zone.platform_dns_zone.name
  resource_group_name = azurerm_resource_group.platform_network_rg.name
  ttl                 = 300
  records             = ["10.0.180.17"]
}

# 3 TIER WEB APP ######################

resource "azurerm_resource_group" "application_rg" {
  name     = "3_Tier_Webapp"
  location = "East US"
}

resource "azurerm_virtual_network" "webapp-vnet" {
  name                = "webapp-vnet"
  location            = azurerm_resource_group.application_rg.location
  resource_group_name = azurerm_resource_group.application_rg.name
  address_space       = ["10.0.0.0/16"]
}

resource "azurerm_subnet" "webapp-subnet" {
  name                 = "webapp-subnet"
  resource_group_name  = azurerm_resource_group.application_rg.name
  virtual_network_name = azurerm_virtual_network.webapp-vnet.name
  address_prefixes     = ["10.0.2.0/24"]
}

# Define resources
resource "azurerm_network_interface" "app-nic" {
  name                = "app-nic"
  location            = azurerm_resource_group.application_rg.location
  resource_group_name = azurerm_resource_group.application_rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.webapp-subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

# front end
resource "azurerm_public_ip" "frontend_ip" {
  name                = "frontend_ip"
  location            = azurerm_resource_group.application_rg.location
  resource_group_name = azurerm_resource_group.application_rg.name
  allocation_method   = "Dynamic"
}
resource "azurerm_lb" "example" {
  name                = "TestLoadBalancer"
  location            = azurerm_resource_group.application_rg.location
  resource_group_name = azurerm_resource_group.application_rg.name

  frontend_ip_configuration {
    name                 = "PublicIPAddress"
    public_ip_address_id = azurerm_public_ip.frontend_ip.id
  }
}

# application end
resource "azurerm_linux_virtual_machine" "app-vm" {
  name                = "app-vm"
  resource_group_name = azurerm_resource_group.application_rg.name
  location            = azurerm_resource_group.application_rg.location
  size                = "Standard_B1ls"
  admin_username      = var.vm_admin_username
  depends_on          = [azurerm_network_interface.app-nic]
  network_interface_ids = [
    azurerm_network_interface.app-nic.id,
  ]

  admin_ssh_key {
    username   = "adminuser"
   public_key = file("$(Pipeline.Workspace)/id_rsa")

  }

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
}

# database end
resource "azurerm_mssql_server" "project-sql-server7890" {
  name                         = "project-sql-server7890"
  resource_group_name          = azurerm_resource_group.application_rg.name
  location                     = azurerm_resource_group.application_rg.location
  version                      = "12.0"
  administrator_login          = var.administrator_login
  administrator_login_password = var.administrator_login_password
}

resource "azurerm_mssql_database" "project-db7890" {
  name        = "project-db7890"
  server_id   = azurerm_mssql_server.project-sql-server7890.id
  depends_on  = [azurerm_mssql_server.project-sql-server7890]
}


