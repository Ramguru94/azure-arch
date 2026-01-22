resource "helm_release" "traefik" {
  name             = "traefik"
  repository       = "https://traefik.github.io"
  chart            = "traefik"
  namespace        = "traefik"
  create_namespace = true

  # Override with local values.yaml
  values = [
    file("../helm-charts/traefik/values.yaml")
  ]
  set {
    name  = "deployment.replicas"
    value = "3"
  }

  set {
    name  = "service.type"
    value = "LoadBalancer"
  }

  # Use set_string for values that must remain strings (e.g. numeric IDs)
  set_string {
    name  = "ports.web.exposedPort"
    value = "80"
  }
}
