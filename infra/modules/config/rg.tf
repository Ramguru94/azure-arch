# --- PRIMARY REGION (EAST US) ---
resource "azurerm_resource_group" "rg" {
  name     = "rg-aks-primary-eastus"
  location = var.location
}

# --- SECONDARY REGION (WEST US) ---
resource "azurerm_resource_group" "rg_secondary" {
  name     = "rg-aks-secondary-westus"
  location = var.secondary_location
}

# --- SHARED GLOBAL RESOURCES (FRONT DOOR, DNS, VNET PEERING) ---
resource "azurerm_resource_group" "rg_shared" {
  name     = "rg-aks-shared-global"
  location = var.location
}