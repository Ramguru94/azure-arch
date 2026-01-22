locals {
  environment = "dev"
  project     = "aks-multiregion"

  traefik = {
    replicas     = 3
    image_tag    = "v2.11.0"
    service_type = "LoadBalancer"

    resources = {
      cpu_request    = "100m"
      memory_request = "256Mi"
      cpu_limit      = "500m"
      memory_limit   = "512Mi"
    }

    log_level = "INFO"
  }

  tags = {
    environment = local.environment
    project     = local.project
    managed_by  = "terraform"
  }
}

module "kubernetes_config" {
  source = "../modules/config"

  environment = local.environment
  project     = local.project

  cluster_endpoint       = data.terraform_remote_state.cluster_infra.outputs.cluster_endpoint
  cluster_ca_certificate = data.terraform_remote_state.cluster_infra.outputs.cluster_ca_certificate
  client_certificate     = data.terraform_remote_state.cluster_infra.outputs.client_certificate
  client_key             = data.terraform_remote_state.cluster_infra.outputs.client_key

  traefik_replicas       = local.traefik.replicas
  traefik_image_tag      = local.traefik.image_tag
  traefik_service_type   = local.traefik.service_type
  traefik_cpu_request    = local.traefik.resources.cpu_request
  traefik_memory_request = local.traefik.resources.memory_request
  traefik_cpu_limit      = local.traefik.resources.cpu_limit
  traefik_memory_limit   = local.traefik.resources.memory_limit
  log_level              = local.traefik.log_level

  tags = local.tags
}

data "terraform_remote_state" "cluster_infra" {
  backend = "local"

  config = {
    path = "${path.module}/../../infra/dv/terraform.tfstate"
  }
}
