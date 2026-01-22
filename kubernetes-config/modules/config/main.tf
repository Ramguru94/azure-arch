# Traefik Helm Release
resource "helm_release" "traefik" {
  name             = "traefik"
  repository       = "https://traefik.github.io"
  chart            = "traefik"
  version          = "24.0.0"
  namespace        = "traefik"
  create_namespace = true

  values = [
    file("${path.module}/../helm-charts/traefik/values.yaml")
  ]

  set {
    name  = "deployment.replicas"
    value = var.traefik_replicas
  }

  set {
    name  = "service.type"
    value = var.traefik_service_type
  }

  set {
    name  = "image.tag"
    value = var.traefik_image_tag
  }

  set {
    name  = "resources.requests.cpu"
    value = var.traefik_cpu_request
  }

  set {
    name  = "resources.requests.memory"
    value = var.traefik_memory_request
  }

  set {
    name  = "resources.limits.cpu"
    value = var.traefik_cpu_limit
  }

  set {
    name  = "resources.limits.memory"
    value = var.traefik_memory_limit
  }

  set {
    name  = "logs.general.level"
    value = var.log_level
  }

  depends_on = [
    var.cluster_ca_certificate,
    var.client_certificate,
    var.client_key
  ]

  lifecycle {
    ignore_changes = [version]
  }
}

# Traefik namespace
resource "kubernetes_namespace" "traefik" {
  metadata {
    name = "traefik"

    labels = {
      name        = "traefik"
      environment = var.environment
      managed_by  = "terraform"
    }
  }

  depends_on = [helm_release.traefik]
}

# IngressClass for Traefik
resource "kubernetes_ingress_class_v1" "traefik" {
  metadata {
    name = "traefik"

    labels = {
      app         = "traefik"
      environment = var.environment
      managed_by  = "terraform"
    }
  }

  spec {
    controller = "traefik.io/ingress-controller"
  }

  depends_on = [helm_release.traefik]
}
