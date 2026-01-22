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

output "module_outputs" {
  value       = module.azure_infrastructure
  description = "All infrastructure module outputs"
}
