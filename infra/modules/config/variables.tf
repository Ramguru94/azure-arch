variable "resource_group_name" {}

variable "subscription_id" {
  type        = string
  description = "Azure Subscription ID"
}

variable "location" {
  type = string
}

variable "secondary_location" {
  type = string
}

variable "secondary_enabled" {
  type        = bool
  default     = true
  description = "Enable secondary region resources"
}

variable "infra_profile" {
  type        = string
  default     = "primary"
  description = "Infrastructure profile: 'primary', 'secondary', or 'dual'. Controls which AKS cluster(s) the Front Door routes traffic to. 'dual' enables load balancing between both clusters."

  validation {
    condition     = contains(["primary", "secondary", "dual"], var.infra_profile)
    error_message = "infra_profile must be 'primary', 'secondary', or 'dual'."
  }
}

# Networking Variables
variable "vnet_name" {
  type        = string
  description = "Name of the virtual network"
}

variable "address_space" {
  type        = list(string)
  description = "Address space for the virtual network"
}

variable "subnet_prefix" {
  type        = string
  description = "CIDR prefix for the AKS node subnet"
}

variable "vnet_cidr" {
  type = string
}

# AKS Variables
variable "aks_name" {
  type = string
}

variable "dns_prefix" {
  type = string
}

variable "aks_version" {
  type        = string
  description = "Kubernetes version"
}

variable "kubernetes_cluster_version" {
  type    = string
  default = "1.32"
}

variable "system_node_count" {
  type        = number
  description = "Number of system node pool nodes"
}

variable "system_vm_size" {
  type        = string
  description = "VM size for system node pool"
}

variable "memory_node_count" {
  type        = number
  description = "Number of memory-optimized node pool nodes"
}

variable "memory_node_vm_size" {
  type        = string
  description = "VM size for memory-optimized node pool"
}

variable "cpu_node_count" {
  type        = number
  description = "Number of CPU-optimized node pool nodes"
}

variable "cpu_node_vm_size" {
  type        = string
  description = "VM size for CPU-optimized node pool"
}

variable "node_min_count" {
  type    = number
  default = 3
}

# Redis Variables
variable "redis_capacity" {
  type        = number
  description = "Redis cache capacity"
}

variable "redis_family" {
  type        = string
  description = "Redis cache family (C, P, E)"
}

variable "redis_sku_name" {
  type        = string
  description = "Redis cache SKU name"
}

variable "redis_version" {
  type        = string
  description = "Redis version"
}

variable "redis_minimum_tls_version" {
  type        = string
  description = "Minimum TLS version for Redis"
}

# PostgreSQL Variables
variable "postgres_version" {
  type        = string
  description = "PostgreSQL version"
}

variable "postgres_sku_name" {
  type        = string
  description = "PostgreSQL SKU name"
}

variable "postgres_storage_mb" {
  type        = number
  description = "PostgreSQL storage in MB"
}

variable "postgres_admin_login" {
  type        = string
  description = "PostgreSQL admin username"
}

# Storage Variables
variable "storage_account_name" {
  type        = string
  description = "Name of the storage account"
}

variable "storage_account_tier" {
  type        = string
  description = "Storage account tier"
}

variable "storage_replication_type" {
  type        = string
  description = "Storage account replication type"
}

variable "storage_index_document" {
  type        = string
  description = "Index document for static website"
}

variable "storage_error_document" {
  type        = string
  description = "Error 404 document for static website"
}

# Front Door Variables
variable "frontdoor_profile_name" {
  type        = string
  description = "Front Door profile name"
}

variable "frontdoor_endpoint_name" {
  type        = string
  description = "Front Door endpoint name"
}

variable "frontdoor_sku_name" {
  type        = string
  description = "Front Door SKU name"
}

variable "aks_private_link_service_name" {
  type        = string
  description = "Private Link Service name for AKS"
}

variable "azurerm_resource_group" {
  type        = string
  description = "azurerm_resource_group"
}
