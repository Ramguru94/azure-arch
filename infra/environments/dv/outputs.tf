output "environment" {
  value       = local.environment
  description = "Deployment environment"
}

output "primary_region" {
  value = {
    region         = local.primary.region
    resource_group = local.primary.resource_group_name
    vnet_cidr      = local.primary.vnet_cidr
  }
  description = "Primary region configuration"
}

output "secondary_region" {
  value = local.secondary_enabled ? {
    region         = local.secondary.region
    resource_group = local.secondary.resource_group_name
    vnet_cidr      = local.secondary.vnet_cidr
  } : null
  description = "Secondary region configuration (null if disabled)"
}

output "aks_config" {
  value = {
    name       = local.aks.name
    dns_prefix = local.aks.dns_prefix
  }
  description = "AKS cluster configuration"
}

output "config" {
  value       = module.azure_infrastructure
  description = "All infrastructure module outputs"
  sensitive   = true
}

output "cluster_endpoint" {
  description = "Map of AKS cluster endpoints for all available clusters"
  value       = module.azure_infrastructure.cluster_endpoint
  sensitive   = true
}

output "cluster_ca_certificate" {
  description = "Map of AKS cluster CA certificates for all available clusters"
  value       = module.azure_infrastructure.cluster_ca_certificate
  sensitive   = true
}

output "client_certificate" {
  description = "Map of client certificates for all available clusters"
  value       = module.azure_infrastructure.client_certificate
  sensitive   = true
}

output "client_key" {
  description = "Map of client keys for all available clusters"
  value       = module.azure_infrastructure.client_key
  sensitive   = true
}
