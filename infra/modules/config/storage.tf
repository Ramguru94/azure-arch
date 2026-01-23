# resource "azurerm_storage_account" "static_site" {
#   name                = var.storage_account_name
#   resource_group_name = var.azurerm_resource_group
#   location            = var.location
#   account_tier        = var.storage_account_tier

#   # RAGRS provides geo-replication with read access to the secondary region
#   account_replication_type = var.storage_replication_type
#   account_kind             = "StorageV2"

#   tags = {
#     environment = "production"
#     year        = "2026"
#   }
# }

# resource "azurerm_storage_account_static_website" "static_site" {
#   storage_account_id = azurerm_storage_account.static_site.id
#   index_document     = var.storage_index_document
#   error_404_document = var.storage_error_document
# }
