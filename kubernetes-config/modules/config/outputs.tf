# # Traefik release outputs
# output "traefik_release_name" {
#   description = "Traefik Helm release name"
#   value       = helm_release.traefik.name
# }

# output "traefik_namespace" {
#   description = "Traefik namespace"
#   value       = kubernetes_namespace.traefik.metadata[0].name
# }

# output "traefik_status" {
#   description = "Traefik release status"
#   value       = helm_release.traefik.status
# }

# output "traefik_service_account" {
#   description = "Traefik service account name"
#   value       = kubernetes_service_account.traefik.metadata[0].name
# }

# output "ingress_class_name" {
#   description = "IngressClass name"
#   value       = kubernetes_ingress_class_v1.traefik.metadata[0].name
# }

# output "traefik_deployment_info" {
#   description = "Traefik deployment information"
#   value = {
#     name       = helm_release.traefik.name
#     namespace  = kubernetes_namespace.traefik.metadata[0].name
#     chart      = helm_release.traefik.chart
#     version    = helm_release.traefik.version
#     repository = helm_release.traefik.repository
#   }
# }

# output "environment" {
#   description = "Deployment environment"
#   value       = var.environment
# }

# output "project" {
#   description = "Project name"
#   value       = var.project
# }
