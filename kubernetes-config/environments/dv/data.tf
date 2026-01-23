data "azurerm_client_config" "current" {}
data "azurerm_kubernetes_cluster" "primary" {
  name                = "aks-multiregion-cluster"
  resource_group_name = local.resource_group_name
}
data "azurerm_kubernetes_cluster" "secondary" {
  name                = "aks-multiregion-cluster-secondary"
  resource_group_name = local.resource_group_name
}
