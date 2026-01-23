resource "helm_release" "traefik" {
  name             = "traefik"
  repository       = "https://traefik.github.io/charts"
  chart            = "traefik"
  namespace        = "traefik"
  version          = "21.1.0"
  create_namespace = true

  values = [
    file("../../helm-charts/traefik/values.yaml")
  ]

  set {
    name  = "service.annotations.service\\.beta\\.kubernetes\\.io/azure-load-balancer-ipv4"
    value = var.traefik_lb_ip
    type  = "string"
  }
}
