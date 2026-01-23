locals {
  # Define zones based on the specific limitations seen in your 2026 deployment
  region_supported_zones = {
    "eastus"  = ["1", "2"] # Error stated '3' is not supported
    "westus2" = ["1"]      # Error stated '2' is not supported
  }
}
# --- AKS CLUSTERS (PRIMARY + SECONDARY) ---
resource "azurerm_kubernetes_cluster" "aks" {
  for_each = toset(var.secondary_enabled ? ["primary", "secondary"] : ["primary"])

  name                = each.key == "primary" ? var.aks_name : "${var.aks_name}-secondary"
  location            = each.key == "primary" ? var.location : var.secondary_location
  resource_group_name = var.azurerm_resource_group
  dns_prefix          = each.key == "primary" ? var.dns_prefix : "${var.dns_prefix}-secondary"


  default_node_pool {
    name       = "systempool"
    node_count = var.system_node_count
    vm_size    = var.system_vm_size
    # zones = lookup(local.region_supported_zones, each.key == "primary" ? var.location : var.secondary_location,
    # ["1", "2", "3"])
    zones                       = ["1"]
    temporary_name_for_rotation = "sysrotation"
    vnet_subnet_id              = azurerm_subnet.aks_nodes[each.key].id

    node_labels = {
      "intent" = "control-plane"
    }
  }

  oidc_issuer_enabled       = true
  workload_identity_enabled = true

  network_profile {
    network_plugin     = "azure"
    network_policy     = "azure"
    network_data_plane = "azure"
    load_balancer_sku  = "standard"
  }

  identity {
    type = "SystemAssigned"
  }

  lifecycle {
    ignore_changes = [
      default_node_pool[0].upgrade_settings
    ]
  }
}

resource "azurerm_role_assignment" "aks_network_contributor" {
  for_each             = toset(var.secondary_enabled ? ["primary", "secondary"] : ["primary"])
  scope                = "/subscriptions/4ac35793-bcc5-4e0a-bf8e-dfcb46e26f5d/resourceGroups/sandbox"
  role_definition_name = "Network Contributor"
  principal_id         = azurerm_kubernetes_cluster.aks[each.key].identity[0].principal_id

  # Optional: Skip check for faster propagation if needed
  skip_service_principal_aad_check = true
}

resource "azurerm_role_assignment" "aks_acr_pull" {
  for_each             = toset(var.secondary_enabled ? ["primary", "secondary"] : ["primary"])
  scope                = azurerm_container_registry.acr.id
  role_definition_name = "AcrPull"

  principal_id = azurerm_kubernetes_cluster.aks[each.key].kubelet_identity[0].object_id

  skip_service_principal_aad_check = true
}


# --- Memory Optimized Node Pools ---
# resource "azurerm_kubernetes_cluster_node_pool" "memory_optimized" {
#   for_each = toset(var.secondary_enabled ? ["primary", "secondary"] : ["primary"])

#   name                  = "memopt"
#   kubernetes_cluster_id = azurerm_kubernetes_cluster.aks[each.key].id
#   node_count            = var.memory_node_count
#   vm_size               = var.memory_node_vm_size
#   zones                 = ["1", "2", "3"]
#   mode                  = "User"
#   vnet_subnet_id        = azurerm_subnet.aks_nodes[each.key].id
# }

# # --- CPU Optimized Node Pools ---
# resource "azurerm_kubernetes_cluster_node_pool" "cpu_optimized" {
#   for_each = toset(var.secondary_enabled ? ["primary", "secondary"] : ["primary"])

#   name                  = "cpuopt"
#   kubernetes_cluster_id = azurerm_kubernetes_cluster.aks[each.key].id
#   node_count            = var.cpu_node_count
#   vm_size               = var.cpu_node_vm_size
#   zones                 = ["1", "2", "3"]
#   mode                  = "User"
#   vnet_subnet_id        = azurerm_subnet.aks_nodes[each.key].id

#   node_labels = {
#     "workload-type" = "cpu-intensive"
#   }
# }

# 1. Define the NSG
# 1. Define the NSG
resource "azurerm_network_security_group" "aks_nsg" {
  for_each            = toset(var.secondary_enabled ? ["primary", "secondary"] : ["primary"])
  name                = "nsg-aks-${each.key}"
  location            = each.key == "primary" ? var.location : var.secondary_location
  resource_group_name = var.azurerm_resource_group

  # Rule: Allow Front Door on Port 80
  security_rule {
    name                       = "AllowFrontDoorInbound"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "AzureFrontDoor.Backend"
    destination_address_prefix = "*"
  }
}

# 2. Link the NSG to your AKS Subnet
# This assumes you have a resource named azurerm_subnet.aks_nodes
resource "azurerm_subnet_network_security_group_association" "aks" {
  for_each                  = toset(var.secondary_enabled ? ["primary", "secondary"] : ["primary"])
  subnet_id                 = azurerm_subnet.aks_nodes[each.key].id
  network_security_group_id = azurerm_network_security_group.aks_nsg[each.key].id
}

