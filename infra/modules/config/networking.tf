resource "azurerm_virtual_network" "vnet" {
  for_each = toset(var.secondary_enabled ? ["primary", "secondary"] : ["primary"])

  name                = each.key == "primary" ? var.vnet_name : "${var.vnet_name}-secondary"
  location            = each.key == "primary" ? var.location : var.secondary_location
  resource_group_name = var.azurerm_resource_group
  address_space       = each.key == "primary" ? var.address_space : ["10.2.0.0/16"]
}

resource "azurerm_subnet" "aks_nodes" {
  for_each = toset(var.secondary_enabled ? ["primary", "secondary"] : ["primary"])

  name                 = each.key == "primary" ? "subnet-aks-nodes" : "subnet-secondary-nodes"
  resource_group_name  = var.azurerm_resource_group
  virtual_network_name = azurerm_virtual_network.vnet[each.key].name
  address_prefixes     = [each.key == "primary" ? var.subnet_prefix : "10.2.1.0/24"]
}

resource "azurerm_subnet" "private_endpoints" {
  for_each = toset(var.secondary_enabled ? ["primary", "secondary"] : ["primary"])

  name                 = each.key == "primary" ? "subnet-private-endpoints" : "subnet-secondary-pe"
  resource_group_name  = var.azurerm_resource_group
  virtual_network_name = azurerm_virtual_network.vnet[each.key].name
  address_prefixes     = [each.key == "primary" ? "10.1.2.0/24" : "10.2.2.0/24"]
}

# --- GLOBAL VNET PEERING (Only when secondary is enabled) ---
resource "azurerm_virtual_network_peering" "primary_to_secondary" {
  count = var.secondary_enabled ? 1 : 0

  name                      = "peering-primary-to-secondary"
  resource_group_name       = var.azurerm_resource_group
  virtual_network_name      = azurerm_virtual_network.vnet["primary"].name
  remote_virtual_network_id = azurerm_virtual_network.vnet["secondary"].id
}

resource "azurerm_virtual_network_peering" "secondary_to_primary" {
  count = var.secondary_enabled ? 1 : 0

  name                      = "peering-secondary-to-primary"
  resource_group_name       = var.azurerm_resource_group
  virtual_network_name      = azurerm_virtual_network.vnet["secondary"].name
  remote_virtual_network_id = azurerm_virtual_network.vnet["primary"].id
}
