# 1. Ephemeral Password (Terraform 1.11+)
ephemeral "random_password" "db_password" {
  length           = 20
  special          = true
  override_special = "()-_"
}

# --- POSTGRESQL SERVERS (PRIMARY + SECONDARY) ---
resource "azurerm_postgresql_flexible_server" "pgsql" {
  for_each = toset(var.secondary_enabled ? ["primary", "secondary"] : ["primary"])

  name                = each.key == "primary" ? "primary-psql-2026" : "secondary-psql-2026"
  resource_group_name = each.key == "primary" ? azurerm_resource_group.rg.name : azurerm_resource_group.rg_secondary.name
  location            = each.key == "primary" ? var.location : var.secondary_location
  version             = var.postgres_version
  administrator_login = var.postgres_admin_login

  administrator_password_wo = ephemeral.random_password.db_password.result

  sku_name   = var.postgres_sku_name
  storage_mb = var.postgres_storage_mb

  public_network_access_enabled = false

  authentication {
    active_directory_auth_enabled = true
    password_auth_enabled         = true
  }
}

# 2. Private DNS Zone for PostgreSQL (Mandatory for Private Link)
resource "azurerm_private_dns_zone" "psql_dns" {
  name                = "privatelink.postgres.database.azure.com"
  resource_group_name = azurerm_resource_group.rg.name
}

# 3. Private Endpoints for PostgreSQL
resource "azurerm_private_endpoint" "psql_pe" {
  for_each = toset(var.secondary_enabled ? ["primary", "secondary"] : ["primary"])

  name                = "${each.key}-psql-pe"
  location            = each.key == "primary" ? var.location : var.secondary_location
  resource_group_name = each.key == "primary" ? azurerm_resource_group.rg.name : azurerm_resource_group.rg_secondary.name
  subnet_id           = azurerm_subnet.aks_nodes[each.key].id

  private_service_connection {
    name                           = "${each.key}-psql-link"
    private_connection_resource_id = azurerm_postgresql_flexible_server.pgsql[each.key].id
    subresource_names              = ["postgresqlServer"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "psql-dns-group"
    private_dns_zone_ids = [azurerm_private_dns_zone.psql_dns.id]
  }
}
