# # --- REDIS CACHE (PRIMARY + SECONDARY) ---
# resource "azurerm_redis_cache" "redis" {
#   for_each = toset(var.secondary_enabled ? ["primary", "secondary"] : ["primary"])

#   name                          = each.key == "primary" ? "primary-redis-2026" : "secondary-redis-2026"
#   location                      = each.key == "primary" ? var.location : var.secondary_location
#   resource_group_name           = var.azurerm_resource_group
#   capacity                      = var.redis_capacity
#   family                        = var.redis_family
#   sku_name                      = var.redis_sku_name
#   non_ssl_port_enabled          = false
#   public_network_access_enabled = false
#   minimum_tls_version           = var.redis_minimum_tls_version
#   redis_version                 = var.redis_version
# }

# # --- PRIVATE DNS ZONE FOR REDIS ---
# resource "azurerm_private_dns_zone" "redis_dns" {
#   name                = "privatelink.redis.cache.windows.net"
#   resource_group_name = var.azurerm_resource_group
# }

# # --- GEO-REPLICATION LINK (Only when secondary is enabled) ---
# resource "azurerm_redis_linked_server" "geo_link" {
#   count = var.secondary_enabled ? 1 : 0

#   target_redis_cache_name     = azurerm_redis_cache.redis["primary"].name
#   resource_group_name         = var.azurerm_resource_group
#   linked_redis_cache_id       = azurerm_redis_cache.redis["secondary"].id
#   linked_redis_cache_location = azurerm_redis_cache.redis["secondary"].location
#   server_role                 = "Secondary"
# }

# # --- PRIVATE ENDPOINTS FOR REDIS ---
# resource "azurerm_private_endpoint" "redis_pe" {
#   for_each = toset(var.secondary_enabled ? ["primary", "secondary"] : ["primary"])

#   name                = "${each.key}-redis-pe"
#   location            = each.key == "primary" ? var.location : var.secondary_location
#   resource_group_name = var.azurerm_resource_group
#   subnet_id           = azurerm_subnet.aks_nodes[each.key].id

#   private_service_connection {
#     name                           = "${each.key}-redis-link"
#     private_connection_resource_id = azurerm_redis_cache.redis[each.key].id
#     is_manual_connection           = false
#     subresource_names              = ["redisCache"]
#   }

#   private_dns_zone_group {
#     name                 = "dns-group"
#     private_dns_zone_ids = [azurerm_private_dns_zone.redis_dns.id]
#   }
# }
