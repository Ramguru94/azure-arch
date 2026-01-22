# --- AKS CLUSTERS (PRIMARY + SECONDARY) ---
resource "azurerm_kubernetes_cluster" "aks" {
  for_each = toset(var.secondary_enabled ? ["primary", "secondary"] : ["primary"])

  name                = each.key == "primary" ? var.aks_name : "${var.aks_name}-secondary"
  location            = each.key == "primary" ? var.location : var.secondary_location
  resource_group_name = each.key == "primary" ? azurerm_resource_group.rg.name : azurerm_resource_group.rg_secondary.name
  dns_prefix          = each.key == "primary" ? var.dns_prefix : "${var.dns_prefix}-secondary"

  automatic_upgrade_channel = "patch"
  node_os_upgrade_channel   = "NodeImage"

  default_node_pool {
    name           = "systempool"
    node_count     = var.system_node_count
    vm_size        = var.system_vm_size
    zones          = each.key == "primary" ? data.azurerm_availability_zones.available.zones : data.azurerm_availability_zones.available_secondary.zones
    vnet_subnet_id = azurerm_subnet.aks_nodes[each.key].id

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
}

# --- Memory Optimized Node Pools ---
resource "azurerm_kubernetes_cluster_node_pool" "memory_optimized" {
  for_each = toset(var.secondary_enabled ? ["primary", "secondary"] : ["primary"])

  name                  = "memopt"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.aks[each.key].id
  node_count            = var.memory_node_count
  vm_size               = var.memory_node_vm_size
  zones                 = each.key == "primary" ? data.azurerm_availability_zones.available.zones : data.azurerm_availability_zones.available_secondary.zones
  mode                  = "User"
  vnet_subnet_id        = azurerm_subnet.aks_nodes[each.key].id
}

# --- CPU Optimized Node Pools ---
resource "azurerm_kubernetes_cluster_node_pool" "cpu_optimized" {
  for_each = toset(var.secondary_enabled ? ["primary", "secondary"] : ["primary"])

  name                  = "cpuopt"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.aks[each.key].id
  node_count            = var.cpu_node_count
  vm_size               = var.cpu_node_vm_size
  zones                 = each.key == "primary" ? data.azurerm_availability_zones.available.zones : data.azurerm_availability_zones.available_secondary.zones
  mode                  = "User"
  vnet_subnet_id        = azurerm_subnet.aks_nodes[each.key].id

  node_labels = {
    "workload-type" = "cpu-intensive"
  }
}
