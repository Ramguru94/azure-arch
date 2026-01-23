resource "azurerm_key_vault" "main" {
  name                        = "kvcommon2026" # Must be globally unique
  location                    = var.location
  resource_group_name         = var.azurerm_resource_group
  enabled_for_disk_encryption = true
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  soft_delete_retention_days  = 7
  purge_protection_enabled    = false

  sku_name = "standard"

  # Recommended for 2026: Use RBAC instead of Access Policies
  enable_rbac_authorization = true

  network_acls {
    bypass         = "AzureServices"
    default_action = "Allow" # Set to 'Deny' in production for private access
  }
}

resource "azurerm_role_assignment" "terraform_kv_access" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = data.azurerm_client_config.current.object_id
}
