data "azurerm_key_vault" "kv" {
  name                = "kvcommon2026"
  resource_group_name = var.azurerm_resource_group
}
data "azurerm_key_vault_secret" "db_password" {
  name         = "database-password"
  key_vault_id = data.azurerm_key_vault.kv.id
}
