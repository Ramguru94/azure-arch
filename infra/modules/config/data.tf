data "azurerm_availability_zones" "available" {
  location = var.location
}

data "azurerm_availability_zones" "available_secondary" {
  location = var.secondary_location
}
