locals {
  # Environment
  environment = "dev"
  project     = "aks-multiregion"

  # Flags
  secondary_enabled = true
  infra_profile     = "dual" # Options: "primary" or "secondary" - determines which AKS cluster Front Door routes to

  subscription_id = "4ac35793-bcc5-4e0a-bf8e-dfcb46e26f5d"

  # Primary Region Configuration
  primary = {
    region              = "centralus"
    location            = "Central US"
    resource_group_name = "rg-aks-primary-eastus"
    vnet_name           = "vnet-eastus"
    vnet_cidr           = ["10.1.0.0/16"]
    node_subnet_cidr    = ["10.1.1.0/24"]
    pe_subnet_cidr      = ["10.1.2.0/24"]
    zones               = ["1", "2", "3"]
  }

  # Secondary Region Configuration
  secondary = {
    region              = "westus2"
    location            = "West US 2"
    resource_group_name = "rg-aks-secondary-westus"
    vnet_name           = "vnet-westus"
    vnet_cidr           = ["10.2.0.0/16"]
    node_subnet_cidr    = ["10.2.1.0/24"]
    pe_subnet_cidr      = ["10.2.2.0/24"]
    zones               = ["1", "2", "3"]
  }

  # AKS Configuration
  aks = {
    name       = "${local.project}-cluster"
    dns_prefix = "akscluster"
    version    = "1.32"
  }

  # Node Pool Configuration
  node_pools = {
    system = {
      name       = "systempool"
      node_count = 2
      vm_size    = "Standard_D2ds_v4"
      mode       = "System"
    }
    memory_optimized = {
      name       = "memopt"
      node_count = 1
      vm_size    = "Standard_E4s_v3"
      mode       = "User"
    }
    cpu_optimized = {
      name       = "cpuopt"
      node_count = 1
      vm_size    = "Standard_F8s_v2"
      mode       = "User"
    }
  }

  # Database Configuration
  database = {
    postgres = {
      version              = "16"
      sku_name             = "GP_Standard_D2s_v3"
      storage_mb           = 32768
      admin_user           = "psqladmin"
      enable_public_access = false
    }
    redis = {
      capacity             = 1
      family               = "P"
      sku_name             = "Premium"
      min_tls_version      = "1.2"
      enable_public_access = false
    }
  }

  # Storage Configuration
  storage = {
    account_tier             = "Standard"
    account_replication_type = "GRS"
    index_document           = "index.html"
    error_404_document       = "404.html"
  }

  # Common Tags
  tags = {
    environment = local.environment
    project     = local.project
    managed_by  = "terraform"
    created_at  = timestamp()
  }
}

module "azure_infrastructure" {
  source = "../../modules/config"

  # Environment & Flags
  secondary_enabled = local.secondary_enabled
  infra_profile     = local.infra_profile

  # Primary Region
  resource_group_name = local.primary.resource_group_name
  location            = local.primary.region
  vnet_name           = local.primary.vnet_name
  address_space       = local.primary.vnet_cidr
  subnet_prefix       = local.primary.node_subnet_cidr[0]

  # Secondary Region
  secondary_location = local.secondary.region

  # AKS Configuration
  aks_name            = local.aks.name
  dns_prefix          = local.aks.dns_prefix
  aks_version         = local.aks.version
  system_node_count   = local.node_pools.system.node_count
  system_vm_size      = local.node_pools.system.vm_size
  memory_node_count   = local.node_pools.memory_optimized.node_count
  memory_node_vm_size = local.node_pools.memory_optimized.vm_size
  cpu_node_count      = local.node_pools.cpu_optimized.node_count
  cpu_node_vm_size    = local.node_pools.cpu_optimized.vm_size

  # Network CIDR
  vnet_cidr = join("/", [
    split("/", local.primary.vnet_cidr[0])[0],
    "8"
  ])

  # Redis Configuration
  redis_capacity            = local.database.redis.capacity
  redis_family              = local.database.redis.family
  redis_sku_name            = local.database.redis.sku_name
  redis_version             = "6"
  redis_minimum_tls_version = local.database.redis.min_tls_version

  # PostgreSQL Configuration
  postgres_version     = local.database.postgres.version
  postgres_sku_name    = local.database.postgres.sku_name
  postgres_storage_mb  = local.database.postgres.storage_mb
  postgres_admin_login = local.database.postgres.admin_user

  # Storage Configuration
  storage_account_name     = "mystaticsite2026"
  storage_account_tier     = local.storage.account_tier
  storage_replication_type = local.storage.account_replication_type
  storage_index_document   = local.storage.index_document
  storage_error_document   = local.storage.error_404_document

  # Front Door Configuration
  frontdoor_profile_name        = "fd-profile-2026"
  frontdoor_endpoint_name       = "fd-endpoint-2026"
  frontdoor_sku_name            = "Premium_AzureFrontDoor"
  aks_private_link_service_name = "traefik-pls-2026"
  azurerm_resource_group        = "sandbox"
  subscription_id               = local.subscription_id
}
