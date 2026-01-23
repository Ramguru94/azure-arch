locals {
  environment         = "dev"
  project             = "aks-multiregion"
  resource_group_name = "sandbox"

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

module "primary_kubernetes_config" {
  providers = {
    helm       = helm.primary
    kubernetes = kubernetes.primary
  }
  source = "../../modules/config"

  environment = local.environment
  project     = local.project

  cluster_endpoint       = data.terraform_remote_state.cluster_infra.outputs.cluster_endpoint["primary"]
  cluster_ca_certificate = data.terraform_remote_state.cluster_infra.outputs.cluster_ca_certificate["primary"]
  client_certificate     = data.terraform_remote_state.cluster_infra.outputs.client_certificate["primary"]
  client_key             = data.terraform_remote_state.cluster_infra.outputs.client_key["primary"]

  traefik_replicas              = local.traefik.replicas
  traefik_image_tag             = local.traefik.image_tag
  traefik_service_type          = local.traefik.service_type
  traefik_cpu_request           = local.traefik.resources.cpu_request
  traefik_memory_request        = local.traefik.resources.memory_request
  traefik_cpu_limit             = local.traefik.resources.cpu_limit
  traefik_memory_limit          = local.traefik.resources.memory_limit
  log_level                     = local.traefik.log_level
  aks_private_link_service_name = "primary-traefik-frontdoor-pls"
  traefik_internal_lb_ip        = "10.1.1.33"
  traefik_lb_ip                 = "20.9.34.119"
  app_profile                   = "primary"
  azurerm_resource_group        = "sandbox"

  tags = local.tags
}

module "secondary_kubernetes_config" {

  providers = {
    helm       = helm.secondary
    kubernetes = kubernetes.secondary
  }
  source = "../../modules/config"

  environment = local.environment
  project     = local.project

  cluster_endpoint       = data.terraform_remote_state.cluster_infra.outputs.cluster_endpoint["secondary"]
  cluster_ca_certificate = data.terraform_remote_state.cluster_infra.outputs.cluster_ca_certificate["secondary"]
  client_certificate     = data.terraform_remote_state.cluster_infra.outputs.client_certificate["secondary"]
  client_key             = data.terraform_remote_state.cluster_infra.outputs.client_key["secondary"]

  traefik_replicas              = local.traefik.replicas
  traefik_image_tag             = local.traefik.image_tag
  traefik_service_type          = local.traefik.service_type
  traefik_cpu_request           = local.traefik.resources.cpu_request
  traefik_memory_request        = local.traefik.resources.memory_request
  traefik_cpu_limit             = local.traefik.resources.cpu_limit
  traefik_memory_limit          = local.traefik.resources.memory_limit
  log_level                     = local.traefik.log_level
  aks_private_link_service_name = "secondary-traefik-frontdoor-pls"
  traefik_internal_lb_ip        = "10.2.1.33"
  traefik_lb_ip                 = "4.155.17.25"
  app_profile                   = "secondary"
  azurerm_resource_group        = "sandbox"

  tags = local.tags
}
