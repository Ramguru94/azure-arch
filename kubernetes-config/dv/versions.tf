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

  # Uncomment for remote state
  # backend "azurerm" {
  #   resource_group_name  = "tfstate-rg"
  #   storage_account_name = "mystateaccount"
  #   container_name       = "tfstate"
  #   key                  = "kubernetes-config.terraform.tfstate"
  # }
}

provider "helm" {
  kubernetes = {
    host = data.terraform_remote_state.cluster_infra.outputs.cluster_endpoint

    cluster_ca_certificate = base64decode(
      data.terraform_remote_state.cluster_infra.outputs.cluster_ca_certificate
    )
    client_certificate = base64decode(
      data.terraform_remote_state.cluster_infra.outputs.client_certificate
    )
    client_key = base64decode(
      data.terraform_remote_state.cluster_infra.outputs.client_key
    )
  }
}

provider "kubernetes" {
  host = data.terraform_remote_state.cluster_infra.outputs.cluster_endpoint

  cluster_ca_certificate = base64decode(
    data.terraform_remote_state.cluster_infra.outputs.cluster_ca_certificate
  )
  client_certificate = base64decode(
    data.terraform_remote_state.cluster_infra.outputs.client_certificate
  )
  client_key = base64decode(
    data.terraform_remote_state.cluster_infra.outputs.client_key
  )
}

# Get cluster infrastructure state
data "terraform_remote_state" "cluster_infra" {
  backend = "local"
  config = {
    path = "../../infra/dv/terraform.tfstate" # Adjust path if needed
  }
}

# Call the kubernetes-config module
module "kubernetes_config" {
  source = "../modules/config"

  # Environment
  environment = local.environment
  project     = local.project

  # Kubernetes credentials
  cluster_endpoint       = data.terraform_remote_state.cluster_infra.outputs.cluster_endpoint
  cluster_ca_certificate = data.terraform_remote_state.cluster_infra.outputs.cluster_ca_certificate
  client_certificate     = data.terraform_remote_state.cluster_infra.outputs.client_certificate
  client_key             = data.terraform_remote_state.cluster_infra.outputs.client_key

  # Traefik configuration from locals
  traefik_name              = local.traefik.name
  traefik_namespace         = local.traefik.namespace
  traefik_version           = local.traefik.version
  traefik_replicas          = local.traefik.deployment.replicas
  traefik_service_type      = local.traefik.service.type
  traefik_image_repository  = "${local.traefik.image.registry}/${local.traefik.image.repository}"
  traefik_image_tag         = local.traefik.image.tag
  traefik_image_pull_policy = local.traefik.image.pullPolicy

  # Traefik ports
  traefik_web_port   = local.traefik.ports.web.port
  traefik_https_port = local.traefik.ports.websecure.port

  # Traefik resources
  traefik_cpu_request    = local.traefik.resources.requests.cpu
  traefik_memory_request = local.traefik.resources.requests.memory
  traefik_cpu_limit      = local.traefik.resources.limits.cpu
  traefik_memory_limit   = local.traefik.resources.limits.memory

  # Traefik security
  traefik_run_as_user = local.traefik.securityContext.runAsUser

  # Ingress configuration
  ingress_class   = local.traefik.ingress.className
  ingress_enabled = local.traefik.ingress.enabled

  # Logging
  log_level = local.traefik.logs.level

  # Tags
  tags = local.tags
}
