terraform {
  required_version = ">= 1.3.0"

  required_providers {
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.0"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = "4ac35793-bcc5-4e0a-bf8e-dfcb46e26f5d"
}

provider "helm" {
  alias = "primary"
  kubernetes {
    host               = data.azurerm_kubernetes_cluster.primary.kube_config[0].host
    client_certificate = base64decode(data.azurerm_kubernetes_cluster.primary.kube_config[0].client_certificate)
    client_key         = base64decode(data.azurerm_kubernetes_cluster.primary.kube_config[0].client_key)
    cluster_ca_certificate = base64decode(
      data.azurerm_kubernetes_cluster.primary.kube_config[0].cluster_ca_certificate
    )
  }
}

provider "helm" {
  alias = "secondary"
  kubernetes {
    host               = data.azurerm_kubernetes_cluster.secondary.kube_config[0].host
    client_certificate = base64decode(data.azurerm_kubernetes_cluster.secondary.kube_config[0].client_certificate)
    client_key         = base64decode(data.azurerm_kubernetes_cluster.secondary.kube_config[0].client_key)
    cluster_ca_certificate = base64decode(
      data.azurerm_kubernetes_cluster.secondary.kube_config[0].cluster_ca_certificate
    )
  }
}

provider "kubernetes" {
  alias              = "primary"
  host               = data.azurerm_kubernetes_cluster.primary.kube_config[0].host
  client_certificate = base64decode(data.azurerm_kubernetes_cluster.primary.kube_config[0].client_certificate)
  client_key         = base64decode(data.azurerm_kubernetes_cluster.primary.kube_config[0].client_key)
  cluster_ca_certificate = base64decode(
    data.azurerm_kubernetes_cluster.primary.kube_config[0].cluster_ca_certificate
  )
}

provider "kubernetes" {
  alias = "secondary"

  host               = data.azurerm_kubernetes_cluster.secondary.kube_config[0].host
  client_certificate = base64decode(data.azurerm_kubernetes_cluster.secondary.kube_config[0].client_certificate)
  client_key         = base64decode(data.azurerm_kubernetes_cluster.secondary.kube_config[0].client_key)
  cluster_ca_certificate = base64decode(
    data.azurerm_kubernetes_cluster.secondary.kube_config[0].cluster_ca_certificate
  )
}

# Get cluster infrastructure state
# data "terraform_remote_state" "cluster_infra" {
#   backend = "local"
#   config = {
#     path = "../../infra/dv/infra.tfstate" # Adjust path if needed
#   }
# }
