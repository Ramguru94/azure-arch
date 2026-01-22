# Data source: Get cluster infrastructure state
# This connects to the AKS cluster infrastructure created by infra module
data "terraform_remote_state" "cluster_infra" {
  backend = "local"
  config = {
    path = "../../infra/dv/terraform.tfstate"
  }
}

# Kubernetes data provider setup
provider "kubernetes" {
  host = var.cluster_endpoint

  cluster_ca_certificate = var.cluster_ca_certificate
  client_certificate     = var.client_certificate
  client_key             = var.client_key
}

provider "helm" {
  kubernetes = {
    host = var.cluster_endpoint

    cluster_ca_certificate = var.cluster_ca_certificate
    client_certificate     = var.client_certificate
    client_key             = var.client_key
  }
}

