# 1. Define the Kubernetes Namespace
resource "kubernetes_namespace" "ns" {
  metadata {
    name = "dv"

    labels = {
      environment = "dv"
      managed-by  = "terraform"
    }

    annotations = {
      "custom-annotation" = "allowed"
    }
  }
}

resource "helm_release" "local_app" {
  name = "app"

  # Path to the directory containing your Chart.yaml
  chart = "../../helm-charts/app"

  # Optional: specify namespace and automatic creation
  namespace        = kubernetes_namespace.ns.metadata[0].name
  create_namespace = false

  # Optional: pass custom values from a local YAML file
  values = [
    file("../../helm-charts/app/values.yaml")
  ]

  set {
    name  = "image.repository"
    value = "myacr2026.azurecr.io/samples/app"
  }

  set {
    name  = "image.tag"
    value = "v3"
  }


  set {
    name  = "database.activeProfile"
    value = var.app_profile
  }

  set {
    name  = "database.primaryHost"
    value = "primary-psql-2026-v2.postgres.database.azure.com"
  }

  set {
    name  = "database.secondaryHost"
    value = "secondary-psql-2026.postgres.database.azure.com"
  }

  set {
    name  = "database.dbUser"
    value = "psqladmin"
  }

  set {
    name  = "database.dbName"
    value = "postgres"
  }

  set {
    name  = "database.passwordSecretName"
    value = "db-secret"
  }

}

resource "kubernetes_secret" "db_password" {
  metadata {
    # This must match {{ .Values.database.passwordSecretName }}
    name      = "db-secret"
    namespace = "dv"
  }

  data = {
    # This key must match the 'key: password' in your secretKeyRef
    password = data.azurerm_key_vault_secret.db_password.value
  }

  type = "Opaque"
}
