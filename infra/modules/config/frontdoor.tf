# 1. Upgrade to Premium SKU (Required for Private Link)
resource "azurerm_cdn_frontdoor_profile" "main" {
  name                = var.frontdoor_profile_name
  resource_group_name = azurerm_resource_group.rg_shared.name
  sku_name            = var.frontdoor_sku_name
}

resource "azurerm_cdn_frontdoor_endpoint" "main" {
  name                     = var.frontdoor_endpoint_name
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.main.id
}

# --- Static Website Origin with Private Link ---
resource "azurerm_cdn_frontdoor_origin_group" "static_site" {
  name                     = "static-site-group"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.main.id
  load_balancing {}
  health_probe {
    interval_in_seconds = 240
    path                = "/healthProbe"
    protocol            = "Https"
    request_type        = "HEAD"
  }
}

resource "azurerm_cdn_frontdoor_origin" "static_site" {
  name                           = "static-site-origin"
  cdn_frontdoor_origin_group_id  = azurerm_cdn_frontdoor_origin_group.static_site.id
  enabled                        = true
  host_name                      = azurerm_storage_account.static_site.primary_web_host
  origin_host_header             = azurerm_storage_account.static_site.primary_web_host
  certificate_name_check_enabled = true

  # Private Link for Storage Static Site
  private_link {
    request_message        = "Access from Front Door"
    target_type            = "web" # Must be 'web' for static sites
    location               = azurerm_storage_account.static_site.location
    private_link_target_id = azurerm_storage_account.static_site.id
  }
}

# --- AKS / Traefik Origin with Private Link ---
resource "azurerm_cdn_frontdoor_origin_group" "aks" {
  name                     = "aks-group"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.main.id
  load_balancing {}
  health_probe {
    protocol            = "Https"
    interval_in_seconds = 30
    path                = "/healthz"
  }
}

resource "azurerm_cdn_frontdoor_origin" "aks" {
  name                           = "aks-origin"
  cdn_frontdoor_origin_group_id  = azurerm_cdn_frontdoor_origin_group.aks.id
  enabled                        = true
  host_name                      = "api.your-aks-domain.com"
  origin_host_header             = "api.your-aks-domain.com"
  certificate_name_check_enabled = true

  # Private Link for AKS (via Private Link Service)
  private_link {
    request_message        = "Access from Front Door to Traefik"
    location               = var.location
    private_link_target_id = azurerm_private_link_service.traefik_pls.id
  }
}

# --- Routing Rules ---
resource "azurerm_cdn_frontdoor_route" "aks_route" {
  name                          = "aks-route"
  cdn_frontdoor_endpoint_id     = azurerm_cdn_frontdoor_endpoint.main.id
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.aks.id
  cdn_frontdoor_origin_ids      = [azurerm_cdn_frontdoor_origin.aks.id]

  patterns_to_match   = ["/api/*"]
  supported_protocols = ["Http", "Https"]
  forwarding_protocol = "HttpsOnly"
}

resource "azurerm_cdn_frontdoor_route" "static_route" {
  name                          = "static-route"
  cdn_frontdoor_endpoint_id     = azurerm_cdn_frontdoor_endpoint.main.id
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.static_site.id
  cdn_frontdoor_origin_ids      = [azurerm_cdn_frontdoor_origin.static_site.id]

  patterns_to_match   = ["/*"]
  supported_protocols = ["Http", "Https"]
  forwarding_protocol = "HttpsOnly"

  cache {
    query_string_caching_behavior = "IgnoreQueryString"
    compression_enabled           = true
  }
}

# --- Private Link Service (for Traefik Ingress) ---
resource "azurerm_private_link_service" "traefik_pls" {
  name                = var.aks_private_link_service_name
  resource_group_name = azurerm_resource_group.rg.name
  location            = var.location

  # Link to AKS internal load balancer (created automatically)
  # This will be updated post-AKS deployment with the actual LB IP config ID
  load_balancer_frontend_ip_configuration_ids = []

  nat_ip_configuration {
    name      = "primary"
    primary   = true
    subnet_id = azurerm_subnet.aks_nodes["primary"].id
  }
}
