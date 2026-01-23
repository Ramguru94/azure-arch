# 1. Generate a standard random password
# This resource persists in your state file (unlike ephemeral)
resource "random_password" "db_password" {
  length           = 20
  special          = true
  override_special = "()-_"
}

resource "azurerm_key_vault_secret" "db_password" {
  name         = "database-password"
  value        = random_password.db_password.result
  key_vault_id = azurerm_key_vault.main.id
  content_type = "password"
  depends_on   = [azurerm_role_assignment.terraform_kv_access]
}

# --- POSTGRESQL SERVERS (PRIMARY + SECONDARY) ---
resource "azurerm_postgresql_flexible_server" "pgsql" {
  for_each = toset(var.secondary_enabled ? ["primary", "secondary"] : ["primary"])

  name                = each.key == "primary" ? "primary-psql-2026-v2" : "secondary-psql-2026"
  resource_group_name = var.azurerm_resource_group
  location            = each.key == "primary" ? var.location : var.secondary_location
  version             = var.postgres_version
  administrator_login = var.postgres_admin_login

  # Reference the resource result
  administrator_password = random_password.db_password.result

  sku_name   = var.postgres_sku_name
  storage_mb = var.postgres_storage_mb

  # ENABLE PUBLIC ACCESS
  # Note: Must NOT include delegated_subnet_id when this is true
  public_network_access_enabled = true

  authentication {
    active_directory_auth_enabled = true
    password_auth_enabled         = true
  }

  # Lifecycle rules to handle Azure's automatic zone management
  lifecycle {
    ignore_changes = [
      zone,
      high_availability[0].standby_availability_zone,
      authentication[0].tenant_id
    ]
  }
}


# 3. Optional: Firewall Rule for your specific local IP (Required for local testing)
resource "azurerm_postgresql_flexible_server_firewall_rule" "allow_local" {
  for_each         = azurerm_postgresql_flexible_server.pgsql
  name             = "AllowLocalClient"
  server_id        = each.value.id
  start_ip_address = "49.206.112.185" # e.g., "1.2.3.4"
  end_ip_address   = "49.206.112.185"
}

resource "azurerm_postgresql_flexible_server_firewall_rule" "allow_azure_services" {
  for_each         = azurerm_postgresql_flexible_server.pgsql
  name             = "AllowAzureServices"
  server_id        = each.value.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}



# resource "azurerm_private_dns_zone" "psql_dns" {
#   name                = "privatelink.postgres.database.azure.com"
#   resource_group_name = var.azurerm_resource_group
# }

# # 3. Private Endpoints for PostgreSQL
# resource "azurerm_private_endpoint" "psql_pe" {
#   for_each = toset(var.secondary_enabled ? ["primary", "secondary"] : ["primary"])

#   name                = "${each.key}-psql-pe"
#   location            = each.key == "primary" ? var.location : var.secondary_location
#   resource_group_name = var.azurerm_resource_group
#   subnet_id           = azurerm_subnet.aks_nodes[each.key].id

#   private_service_connection {
#     name                           = "${each.key}-psql-link"
#     private_connection_resource_id = azurerm_postgresql_flexible_server.pgsql[each.key].id
#     subresource_names              = ["postgresqlServer"]
#     is_manual_connection           = false
#   }

#   private_dns_zone_group {
#     name                 = "psql-dns-group"
#     private_dns_zone_ids = [azurerm_private_dns_zone.psql_dns.id]
#   }
# }
