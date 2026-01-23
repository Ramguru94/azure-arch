# output "environment" {
#   description = "Deployment environment"
#   value       = local.environment
# }

# output "project" {
#   description = "Project name"
#   value       = local.project
# }

# output "traefik_config" {
#   description = "Traefik configuration"
#   value = {
#     replicas     = local.traefik.replicas
#     service_type = local.traefik.service_type
#     image_tag    = local.traefik.image_tag
#     log_level    = local.traefik.log_level
#   }
# }

# output "traefik_ports" {
#   description = "Traefik port configuration"
#   value = {
#     web       = local.traefik.ports.web.exposedPort
#     websecure = local.traefik.ports.websecure.exposedPort
#   }
# }

# output "module_outputs" {
#   description = "Kubernetes config module outputs"xq
#   value       = module.kubernetes_config
#   sensitive   = true
# }
