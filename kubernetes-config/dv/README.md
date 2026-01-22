# Kubernetes Configuration - Dev Environment

This directory contains the Terraform configuration for deploying and managing Kubernetes cluster configurations, specifically Traefik ingress controller setup.

## Directory Structure

```
kubernetes-config/
├── dv/                                    # Dev environment configuration
│   ├── main.tf                           # Main config with locals for Traefik
│   ├── versions.tf                       # Provider versions and configuration
│   ├── outputs.tf                        # Environment outputs
│   └── README.md                         # This file
├── modules/
│   └── config/                           # Kubernetes configuration module
│       ├── main.tf                       # Traefik Helm release and K8s resources
│       ├── variables.tf                  # Module input variables
│       ├── outputs.tf                    # Module outputs
│       ├── data.tf                       # Data sources and provider setup
│       ├── versions.tf                   # Required providers
│       └── traefik.tf                    # (deprecated) See main.tf
└── helm-charts/
    └── traefik/
        └── values.yaml                   # Traefik Helm chart values
```

## Overview

The kubernetes-config module manages:

1. **Traefik Ingress Controller** - Deploy and configure Traefik for ingress routing
2. **Kubernetes Resources** - Namespaces, service accounts, RBAC, ingress classes
3. **Helm Releases** - Using Helm provider to deploy Traefik chart

## Configuration Flow

```
dv/main.tf (Environment Configuration)
    ↓ Contains locals for all Traefik settings
    ├─ traefik.name = "traefik"
    ├─ traefik.namespace = "traefik"
    ├─ traefik.replicas = 3
    ├─ traefik.image.tag = "v2.11.0"
    ├─ traefik.resources.requests.memory = "256Mi"
    └─ ... (20+ configuration values)
    │
    └─→ module "kubernetes_config" {
        ├─ traefik_name = local.traefik.name
        ├─ traefik_replicas = local.traefik.deployment.replicas
        ├─ traefik_cpu_request = local.traefik.resources.requests.cpu
        └─ ... (all variables from locals)
        }

modules/config/ (Implementation)
    ├─ helm_release.traefik        # Helm chart deployment
    ├─ kubernetes_namespace        # Traefik namespace
    ├─ kubernetes_service_account  # Service account
    ├─ kubernetes_cluster_role     # RBAC role
    ├─ kubernetes_cluster_role_binding  # RBAC binding
    └─ kubernetes_ingress_class    # IngressClass definition
```

## Prerequisites

### Required Software
- Terraform >= 1.3.0
- Helm 3.0+
- kubectl configured with AKS cluster access

### Required Providers
- `hashicorp/helm` >= 2.0
- `hashicorp/kubernetes` >= 2.0

### Cluster Dependency
This configuration requires an AKS cluster created by the infrastructure module:
- Path: `infra/dv/terraform.tfstate`
- Provides: Cluster endpoint, CA certificate, client credentials

## Traefik Configuration

All Traefik settings are defined as locals in `dv/main.tf`:

### Basic Settings
```hcl
traefik = {
  name      = "traefik"           # Release name
  namespace = "traefik"           # Kubernetes namespace
  version   = "24.0.0"            # Helm chart version
}
```

### Deployment
```hcl
deployment = {
  enabled  = true
  kind     = "Deployment"
  replicas = 3                    # Number of pods
}
```

### Networking
```hcl
ports = {
  web = {
    port        = 80
    exposedPort = 80
  }
  websecure = {
    port        = 443
    exposedPort = 443
  }
}

service = {
  type = "LoadBalancer"           # Azure LB
}
```

### Image
```hcl
image = {
  registry   = "docker.io"
  repository = "traefik"
  tag        = "v2.11.0"
  pullPolicy = "IfNotPresent"
}
```

### Resources
```hcl
resources = {
  requests = {
    cpu    = "100m"
    memory = "256Mi"
  }
  limits = {
    cpu    = "500m"
    memory = "512Mi"
  }
}
```

### Security
```hcl
securityContext = {
  runAsNonRoot = true
  runAsUser    = 65534             # nobody
  fsGroup      = 65534
}
```

## Usage

### Initialize Terraform
```bash
cd kubernetes-config/dv
terraform init
```

### Plan Deployment
```bash
terraform plan
```

### Apply Configuration
```bash
terraform apply
```

### Verify Deployment
```bash
# Check Traefik pods
kubectl -n traefik get pods

# Check Traefik service
kubectl -n traefik get svc

# Check logs
kubectl -n traefik logs -f deployment/traefik
```

### Destroy Resources
```bash
terraform destroy
```

## Customization

### Change Number of Replicas
Edit `dv/main.tf`:
```hcl
replicas = 5  # Increase from 3 to 5
```

### Change Traefik Image Version
```hcl
image = {
  tag = "v2.12.0"  # Update to new version
}
```

### Update Resource Limits
```hcl
resources = {
  requests = {
    cpu    = "200m"    # Increase CPU
    memory = "512Mi"   # Increase memory
  }
  limits = {
    cpu    = "1000m"
    memory = "1Gi"
  }
}
```

### Add Global Arguments
```hcl
globalArguments = [
  "--entrypoints.metrics.address=:8082",
  "--api.dashboard=true",
  "--metrics.prometheus=true",
]
```

### Disable LoadBalancer (use ClusterIP)
```hcl
service = {
  type = "ClusterIP"
}
```

## Module Variables

The module accepts these variables (all passed from dv/main.tf):

### Environment
- `environment` - Deployment environment (dev, staging, prod)
- `project` - Project name

### Cluster Authentication
- `cluster_endpoint` - Kubernetes API server endpoint
- `cluster_ca_certificate` - CA certificate (base64)
- `client_certificate` - Client cert (base64)
- `client_key` - Client key (base64)

### Traefik Configuration
- `traefik_name` - Release name (default: "traefik")
- `traefik_namespace` - Namespace (default: "traefik")
- `traefik_version` - Chart version (default: "24.0.0")
- `traefik_replicas` - Pod replicas (default: 1)
- `traefik_service_type` - Service type (default: "LoadBalancer")
- `traefik_image_repository` - Image repo (default: "docker.io/traefik")
- `traefik_image_tag` - Image tag (default: "v2.11.0")
- `traefik_image_pull_policy` - Pull policy (default: "IfNotPresent")

### Ports
- `traefik_web_port` - HTTP port (default: 80)
- `traefik_https_port` - HTTPS port (default: 443)

### Resources
- `traefik_cpu_request` - CPU request (default: "100m")
- `traefik_memory_request` - Memory request (default: "256Mi")
- `traefik_cpu_limit` - CPU limit (default: "500m")
- `traefik_memory_limit` - Memory limit (default: "512Mi")

### Other
- `traefik_run_as_user` - User ID (default: 65534)
- `ingress_class` - IngressClass name (default: "traefik")
- `ingress_enabled` - Enable ingress (default: true)
- `log_level` - Log level (default: "INFO")
- `tags` - Common tags

## Module Outputs

Key outputs from the module:

```hcl
traefik_release_name          # Helm release name
traefik_namespace             # Traefik namespace
traefik_status                # Release status
traefik_service_account       # Service account name
ingress_class_name            # IngressClass name
traefik_deployment_info       # Deployment metadata
environment                   # Environment name
project                       # Project name
```

## Traefik Helm Chart Values

The module uses a values.yaml from the Traefik Helm chart repository:
- Location: `helm-charts/traefik/values.yaml`
- This provides comprehensive Traefik configuration options
- Key settings are overridden by Terraform `set` blocks

## Troubleshooting

### Provider Configuration Failed
**Issue**: "Error: Error configuring provider"
**Solution**: 
- Verify AKS cluster is running
- Check kubeconfig has correct credentials
- Ensure cluster certificates are valid

### Helm Chart Not Found
**Issue**: "Error: failed to download chart"
**Solution**:
- Verify Helm repository is accessible: `helm repo add traefik https://traefik.github.io`
- Check version exists: `helm search repo traefik/traefik --versions`

### Service LoadBalancer Pending
**Issue**: External IP stuck on `<pending>`
**Solution**:
```bash
# Check service events
kubectl -n traefik describe svc traefik

# Check if Azure LB was created
az network lb list

# Verify subscription has quota for LB
```

### Pods Not Running
**Issue**: Traefik pods in CrashLoopBackOff
**Solution**:
```bash
# Check logs
kubectl -n traefik logs <pod-name>

# Check resource constraints
kubectl -n traefik top pod

# Verify resources exist
kubectl get nodes
kubectl top nodes
```

## Security Considerations

### Current Settings
- ✅ Runs as non-root user (UID 65534)
- ✅ Service account with minimal RBAC
- ✅ Resource limits to prevent resource exhaustion
- ✅ IngressClass to control ingress creation

### Recommended for Production
- Add Pod Security Policies
- Use cert-manager for certificate management
- Enable Traefik dashboard authentication
- Use Azure Key Vault for secrets
- Implement network policies
- Add log aggregation (Azure Monitor)

## Performance Tuning

### For High Traffic
```hcl
replicas = 5  # Increase replicas
resources = {
  requests = {
    cpu    = "250m"
    memory = "512Mi"
  }
  limits = {
    cpu    = "2000m"
    memory = "1Gi"
  }
}
```

### For Development
```hcl
replicas = 1  # Single replica
resources = {
  requests = {
    cpu    = "50m"
    memory = "128Mi"
  }
  limits = {
    cpu    = "200m"
    memory = "256Mi"
  }
}
```

## State Management

### Local State (Default)
```hcl
# Backend uses local state file
path = "../../infra/dv/terraform.tfstate"
```

### Remote State (Recommended for Production)
```hcl
backend "azurerm" {
  resource_group_name  = "tfstate-rg"
  storage_account_name = "mystateaccount"
  container_name       = "tfstate"
  key                  = "kubernetes-config.terraform.tfstate"
}
```

## Integration with Other Modules

### With Infrastructure Module
- Gets cluster credentials from `infra/dv/terraform.tfstate`
- Uses cluster endpoint and certificates for connectivity

### With Application Module
- Creates IngressClass for application ingress routes
- Applications use `ingressClassName: traefik` in their ingress definitions

## Next Steps

1. **Deploy Initial Configuration**
   ```bash
   terraform init
   terraform apply
   ```

2. **Configure Applications**
   - Create ingress resources with `ingressClassName: traefik`
   - Applications will route through Traefik

3. **Setup Monitoring**
   - Enable Prometheus metrics on Traefik
   - Configure Azure Monitor integration

4. **Add Cert Management**
   - Install cert-manager
   - Configure Let's Encrypt issuers

5. **Setup Logging**
   - Configure log aggregation
   - Monitor Traefik dashboards

## Additional Resources

- [Traefik Documentation](https://doc.traefik.io/)
- [Traefik Helm Chart](https://github.com/traefik/traefik-helm-chart)
- [Kubernetes Ingress Documentation](https://kubernetes.io/docs/concepts/services-networking/ingress/)
- [Azure AKS Documentation](https://docs.microsoft.com/en-us/azure/aks/)
