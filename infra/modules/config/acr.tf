resource "azurerm_container_registry" "acr" {
  name                = "myacr2026" # Must be globally unique
  resource_group_name = var.azurerm_resource_group
  location            = var.location
  sku                 = "Standard" # Options: Basic, Standard, Premium
  admin_enabled       = false      # Best practice: keep disabled and use Managed Identity

  # Optional: Enable public access (defaults to true)
  public_network_access_enabled = true
}
