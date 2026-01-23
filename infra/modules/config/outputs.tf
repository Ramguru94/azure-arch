# output "aks_id" { value = azurerm_kubernetes_cluster.aks["primary"].id }
# output "aks_fqdn" { value = azurerm_kubernetes_cluster.aks["primary"].fqdn }

# output "aks_secondary_id" {
#   value       = var.secondary_enabled ? azurerm_kubernetes_cluster.aks["secondary"].id : null
#   description = "Secondary AKS cluster ID (null if secondary_enabled is false)"
# }
# output "aks_secondary_fqdn" {
#   value       = var.secondary_enabled ? azurerm_kubernetes_cluster.aks["secondary"].fqdn : null
#   description = "Secondary AKS cluster FQDN (null if secondary_enabled is false)"
# }

# output "storage_account_name" { value = azurerm_storage_account.static_site.name }
# output "storage_account_id" { value = azurerm_storage_account.static_site.id }
# output "primary_web_host" { value = azurerm_storage_account.static_site.primary_web_host }

# output "redis_primary_id" { value = azurerm_redis_cache.redis["primary"].id }
# output "redis_primary_hostname" { value = azurerm_redis_cache.redis["primary"].hostname }
# output "redis_secondary_id" {
#   value       = var.secondary_enabled ? azurerm_redis_cache.redis["secondary"].id : null
#   description = "Secondary Redis ID (null if secondary_enabled is false)"
# }
# output "redis_secondary_hostname" {
#   value       = var.secondary_enabled ? azurerm_redis_cache.redis["secondary"].hostname : null
#   description = "Secondary Redis hostname (null if secondary_enabled is false)"
# }

# output "postgres_primary_id" { value = azurerm_postgresql_flexible_server.pgsql["primary"].id }
# output "postgres_primary_fqdn" { value = azurerm_postgresql_flexible_server.pgsql["primary"].fqdn }
# output "postgres_secondary_id" {
#   value       = var.secondary_enabled ? azurerm_postgresql_flexible_server.pgsql["secondary"].id : null
#   description = "Secondary Postgres ID (null if secondary_enabled is false)"
# }
# output "postgres_secondary_fqdn" {
#   value       = var.secondary_enabled ? azurerm_postgresql_flexible_server.pgsql["secondary"].fqdn : null
#   description = "Secondary Postgres FQDN (null if secondary_enabled is false)"
# }

# output "frontdoor_id" { value = azurerm_cdn_frontdoor_profile.main.id }
# output "frontdoor_name" { value = azurerm_cdn_frontdoor_profile.main.name }
# output "frontdoor_endpoint" { value = azurerm_cdn_frontdoor_endpoint.main.host_name }

# output "vnet_primary_id" { value = azurerm_virtual_network.vnet["primary"].id }
# output "vnet_secondary_id" {
#   value       = var.secondary_enabled ? azurerm_virtual_network.vnet["secondary"].id : null
#   description = "Secondary VNet ID (null if secondary_enabled is false)"
# }
# output "subnet_aks_nodes_primary_id" { value = azurerm_subnet.aks_nodes["primary"].id }
# output "subnet_aks_nodes_secondary_id" {
#   value       = var.secondary_enabled ? azurerm_subnet.aks_nodes["secondary"].id : null
#   description = "Secondary AKS nodes subnet ID (null if secondary_enabled is false)"
# }

output "cluster_endpoint" {
  description = "Map of AKS cluster endpoints for all available clusters"
  value = {
    for cluster_key, cluster in azurerm_kubernetes_cluster.aks :
    cluster_key => cluster.kube_config[0].host
  }
  sensitive = true
}

output "cluster_ca_certificate" {
  description = "Map of AKS cluster CA certificates for all available clusters"
  value = {
    for cluster_key, cluster in azurerm_kubernetes_cluster.aks :
    cluster_key => cluster.kube_config[0].cluster_ca_certificate
  }
  sensitive = true
}

output "client_certificate" {
  description = "Map of client certificates for all available clusters"
  value = {
    for cluster_key, cluster in azurerm_kubernetes_cluster.aks :
    cluster_key => cluster.kube_config[0].client_certificate
  }
  sensitive = true
}

output "client_key" {
  description = "Map of client keys for all available clusters"
  value = {
    for cluster_key, cluster in azurerm_kubernetes_cluster.aks :
    cluster_key => cluster.kube_config[0].client_key
  }
  sensitive = true
}

output "aks_clusters" {
  description = "Map of all AKS cluster details"
  value = {
    for cluster_key, cluster in azurerm_kubernetes_cluster.aks :
    cluster_key => {
      id                 = cluster.id
      name               = cluster.name
      fqdn               = cluster.fqdn
      endpoint           = cluster.kube_config[0].host
      kubernetes_version = cluster.kubernetes_version
      location           = cluster.location
    }
  }
}

output "aks_ids" {
  description = "Map of AKS cluster IDs"
  value = {
    for cluster_key, cluster in azurerm_kubernetes_cluster.aks :
    cluster_key => cluster.id
  }
}

output "aks_fqdns" {
  description = "Map of AKS cluster FQDNs"
  value = {
    for cluster_key, cluster in azurerm_kubernetes_cluster.aks :
    cluster_key => cluster.fqdn
  }
}
