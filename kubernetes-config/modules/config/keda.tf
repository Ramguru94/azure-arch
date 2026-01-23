# resource "helm_release" "keda" {
#   name             = "keda"
#   repository       = "https://kedacore.github.io" # Official Keda repo
#   chart            = "keda"
#   namespace        = "keda"
#   create_namespace = true
#   version          = "2.14.0" # Recommended stable version for 2026

#   # 1. Base configuration from local file
#   values = [
#     file("${path.module}/../helm-charts/keda/values.yaml")
#   ]

#   # 2. Specific overrides
#   set {
#     name  = "watchNamespace"
#     value = "" # Empty string allows Keda to watch all namespaces
#   }

#   set {
#     name  = "operator.replicaCount"
#     value = "2"
#   }

#   # Enable Prometheus metrics for autoscaling visibility
#   set {
#     name  = "prometheus.operator.enabled"
#     value = "true"
#   }

#   # Use set_string for any specific annotation or string-only values
#   set_string {
#     name  = "podAnnotations.deployedBy"
#     value = "terraform"
#   }
# }
