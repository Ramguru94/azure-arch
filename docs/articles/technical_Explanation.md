# Azure Architecture: Complete Technical Explanation

This document provides a deep dive into:
1. Infrastructure Setup & Configuration
2. Terraform as Infrastructure as Code (Best Practices)
3. Helm Release Deployment via Terraform
4. Application Build & Deployment Process

---

## Part 1: Infrastructure Setup (`/infra`)

### What is Infrastructure Setup?

Infrastructure refers to all the cloud resources your application needs to run:
- Compute resources (AKS clusters)
- Networking (VNets, subnets)
- Data services (PostgreSQL, Redis)
- Storage (Blob storage)
- Load balancing (Azure Front Door)

### Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                     AZURE CLOUD                            │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌─────────────────────────────────────────────────────┐  │
│  │          REGION 1: EAST US (PRIMARY)               │  │
│  │  ┌──────────────────────────────────────────────┐  │  │
│  │  │  Resource Group: rg-aks-primary-eastus      │  │  │
│  │  │                                              │  │  │
│  │  │  ┌────────────────────────────────────────┐ │  │  │
│  │  │  │  VNet: vnet-eastus (10.1.0.0/16)     │ │  │  │
│  │  │  │                                        │ │  │  │
│  │  │  │  ┌─────────────────────────────────┐ │ │  │  │
│  │  │  │  │ Node Subnet: 10.1.1.0/24       │ │ │  │  │
│  │  │  │  │  ┌──────────────────────────┐  │ │ │  │  │
│  │  │  │  │  │  AKS Cluster (1.32)     │  │ │ │  │  │
│  │  │  │  │  │  ├─ System Pool (3)     │  │ │ │  │  │
│  │  │  │  │  │  ├─ Memory Pool (2)     │  │ │ │  │  │
│  │  │  │  │  │  └─ CPU Pool (2)        │  │ │ │  │  │
│  │  │  │  │  └──────────────────────────┘  │ │ │  │  │
│  │  │  │  │                                 │ │ │  │  │
│  │  │  │  │ PE Subnet: 10.1.2.0/24         │ │ │  │  │
│  │  │  │  │  (Private Endpoints)           │ │ │  │  │
│  │  │  │  └─────────────────────────────────┘ │ │  │  │
│  │  │  │                                        │ │  │  │
│  │  │  └────────────────────────────────────────┘ │  │  │
│  │  │                                              │  │  │
│  │  │  ┌────────────────────────────────────────┐ │  │  │
│  │  │  │ Data Services (Private Endpoints)     │ │  │  │
│  │  │  │  ├─ PostgreSQL v16                   │ │  │  │
│  │  │  │  ├─ Redis Premium                    │ │  │  │
│  │  │  │  └─ Storage Account                  │ │  │  │
│  │  │  └────────────────────────────────────────┘ │  │  │
│  │  └──────────────────────────────────────────────┘  │  │
│  └─────────────────────────────────────────────────────┘  │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐  │
│  │        REGION 2: WEST US 2 (STANDBY)               │  │
│  │  (Identical to Region 1 for failover)              │  │
│  └─────────────────────────────────────────────────────┘  │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐  │
│  │  GLOBAL SERVICES                                   │  │
│  │  ├─ Azure Front Door (CDN + Load Balancing)       │  │
│  │  └─ Private DNS Zones (Service Discovery)         │  │
│  └─────────────────────────────────────────────────────┘  │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### Infrastructure Configuration Flow

**File: `infra/dv/main.tf`**

```terraform
# 1. ENVIRONMENT SETUP
locals {
  environment = "dev"           # Environment identifier
  project     = "aks-multiregion"  # Project name

  # 2. REGION CONFIGURATION
  primary = {
    region              = "eastus"              # Azure region
    location            = "East US"
    resource_group_name = "rg-aks-primary-eastus"
    vnet_name           = "vnet-eastus"
    vnet_cidr           = ["10.1.0.0/16"]      # Virtual Network CIDR
    node_subnet_cidr    = ["10.1.1.0/24"]      # Kubernetes nodes subnet
    pe_subnet_cidr      = ["10.1.2.0/24"]      # Private endpoints subnet
    zones               = ["1", "2", "3"]      # Availability zones
  }

  secondary = {
    # Standby region for failover
    region              = "westus2"
    location            = "West US 2"
    # ... same structure as primary
  }

  # 3. KUBERNETES CONFIGURATION
  aks = {
    name       = "aks-multiregion-cluster"     # Cluster name
    dns_prefix = "akscluster"
    version    = "1.32"                         # K8s version
  }

  # 4. NODE POOL CONFIGURATION
  node_pools = {
    system = {
      name       = "systempool"                 # System node pool (for cluster operations)
      node_count = 3                            # 3 nodes
      vm_size    = "Standard_D2s_v3"           # VM type: 2 vCPU, 8GB RAM
      mode       = "System"                     # System mode = required
    }
    memory_optimized = {
      name       = "memopt"                     # For memory-heavy workloads
      node_count = 2
      vm_size    = "Standard_E4s_v3"           # 4 vCPU, 32GB RAM
      mode       = "User"
    }
    cpu_optimized = {
      name       = "cpuopt"                     # For CPU-heavy workloads
      node_count = 2
      vm_size    = "Standard_F8s_v2"           # 8 vCPU, 16GB RAM
      mode       = "User"
    }
  }

  # 5. DATABASE CONFIGURATION
  database = {
    postgres = {
      version              = "16"               # PostgreSQL version
      sku_name             = "GP_Standard_D2s_v3"  # General Purpose tier
      storage_mb           = 32768              # 32GB storage
      enable_public_access = false              # Private only
    }
    redis = {
      capacity             = 1                  # Cache size (GB)
      family               = "P"                # Premium tier
      sku_name             = "Premium"
      min_tls_version      = "1.2"             # Security
      enable_public_access = false
    }
  }

  # 6. TAGS (Applied to all resources)
  tags = {
    environment = local.environment
    project     = local.project
    managed_by  = "terraform"
    created_at  = timestamp()
  }
}

# 7. CALL INFRASTRUCTURE MODULES
module "infrastructure" {
  source = "../modules"

  # Pass all locals to modules
  environment           = local.environment
  primary_region        = local.primary
  secondary_region      = local.secondary
  secondary_enabled     = local.secondary_enabled
  aks_config            = local.aks
  node_pools            = local.node_pools
  database_config       = local.database
  tags                  = local.tags
}
```

### What Each Component Does

| Component | Purpose | Example |
|-----------|---------|---------|
| **VNet** | Isolated network for resources | 10.1.0.0/16 |
| **Subnets** | Subdivisions of VNet | Node: 10.1.1.0/24, PE: 10.1.2.0/24 |
| **AKS Cluster** | Kubernetes orchestration | 3 node pools, 7 total nodes |
| **Node Pools** | Different workload types | System (3), Memory (2), CPU (2) |
| **PostgreSQL** | Relational database | v16, 32GB storage |
| **Redis** | Caching layer | Premium tier, geo-replicated |
| **Storage Account** | File storage | Blobs for static assets |
| **Private Endpoints** | Secure data access | Database accessible only within VNet |
| **DNS Zones** | Service discovery | postgres.database.azure.com resolves internally |

### Infrastructure Deployment Output

After running `terraform apply`, you get:

**File: `infra/dv/terraform.tfstate`** (State file containing):
```json
{
  "cluster_endpoint": "akscluster-eastus.hcp.eastus.azmk8s.io:443",
  "cluster_ca_certificate": "base64encodedcert...",
  "client_certificate": "base64encodedcert...",
  "client_key": "base64encodedkey...",
  "postgres_connection_string": "postgresql://psqladmin:pass@postgres.database.azure.com/testdb",
  "redis_connection_string": "redis-primary.redis.cache.windows.net:6380",
  "resource_group_ids": ["rg-aks-primary-eastus", "rg-aks-secondary-westus"],
  "...other_outputs": "..."
}
```

These outputs are critical for the next layers!

---

## Part 2: Terraform as Infrastructure as Code (Best Practices)

### What is Terraform?

Terraform is a tool for defining, provisioning, and managing cloud infrastructure using code.

### Key Principles We Follow

#### 1. **Separation of Concerns**

**Directory Structure:**
```
infra/
├── dv/                    # Environment-specific (CONFIGURATION)
│   ├── main.tf           # Locals + module calls
│   ├── versions.tf       # Provider setup
│   ├── outputs.tf        # What we expose
│   └── terraform.tfstate # Current state
└── modules/              # Reusable components (IMPLEMENTATION)
    ├── networking.tf     # VNets, subnets
    ├── aks.tf            # AKS resources
    ├── postgres.tf       # Databases
    ├── redis.tf          # Caching
    └── variables.tf      # Input declarations
```

**Philosophy:**
- **Environment Layer** (`dv/`) = "WHAT to deploy" (locals with values)
- **Module Layer** (`modules/`) = "HOW to deploy" (reusable templates)

This allows:
- ✅ Reuse modules for dev, staging, prod
- ✅ Keep sensitive data in environment configs
- ✅ Easy to update configurations without touching code

#### 2. **Single Source of Truth**

```terraform
# BAD: Hardcoded values everywhere
resource "azurerm_kubernetes_cluster" "primary" {
  name = "aks-multiregion"
  kubernetes_version = "1.32"
}
resource "azurerm_kubernetes_cluster" "secondary" {
  name = "aks-multiregion"
  kubernetes_version = "1.32"  # DUPLICATE!
}

# GOOD: Central configuration
locals {
  aks = {
    name = "aks-multiregion"
    version = "1.32"
  }
}

resource "azurerm_kubernetes_cluster" "primary" {
  name = local.aks.name
  kubernetes_version = local.aks.version
}

resource "azurerm_kubernetes_cluster" "secondary" {
  name = local.aks.name
  kubernetes_version = local.aks.version  # REFERENCES locals
}
```

#### 3. **Modules for Reusability**

**File: `infra/modules/aks.tf`** (Example)

```terraform
# Define a reusable AKS module
variable "cluster_name" {
  type = string
  description = "Name of AKS cluster"
}

variable "kubernetes_version" {
  type = string
  description = "Kubernetes version"
  default = "1.32"
}

variable "node_pools" {
  type = map(object({
    name = string
    node_count = number
    vm_size = string
  }))
}

# Resource definition using variables
resource "azurerm_kubernetes_cluster" "cluster" {
  name = var.cluster_name
  kubernetes_version = var.kubernetes_version
  
  # Loop through node pools
  dynamic "default_node_pool" {
    for_each = var.node_pools
    content = {
      name = default_node_pool.value.name
      node_count = default_node_pool.value.node_count
      vm_size = default_node_pool.value.vm_size
    }
  }
}

# Output what other modules need
output "cluster_endpoint" {
  value = azurerm_kubernetes_cluster.cluster.kube_config.0.host
  sensitive = true
}
```

#### 4. **For_Each for Multiple Resources**

```terraform
# Create multiple resources in different regions
# BEFORE: Repeat resource definitions (DRY violation)
resource "azurerm_resource_group" "primary" {
  name = "rg-aks-primary-eastus"
  location = "eastus"
}

resource "azurerm_resource_group" "secondary" {
  name = "rg-aks-secondary-westus"
  location = "westus2"
}

# AFTER: Use for_each (DRY principle)
locals {
  regions = {
    primary = {
      name = "rg-aks-primary-eastus"
      location = "eastus"
    }
    secondary = {
      name = "rg-aks-secondary-westus"
      location = "westus2"
    }
  }
}

resource "azurerm_resource_group" "regions" {
  for_each = local.secondary_enabled ? local.regions : { primary = local.regions.primary }
  
  name = each.value.name
  location = each.value.location
}
```

#### 5. **State Management (terraform.tfstate)**

**What is State?**

State file tracks what Terraform created and current resource status.

```bash
# State file location
infra/dv/terraform.tfstate

# Content example
{
  "resources": [
    {
      "type": "azurerm_kubernetes_cluster",
      "name": "primary",
      "instances": [
        {
          "attributes": {
            "id": "/subscriptions/.../resourcegroups/rg-aks/providers/Microsoft.ContainerService/managedClusters/aks",
            "kube_config": [...],
            "status": "Succeeded"
          }
        }
      ]
    }
  ]
}
```

**Why it matters:**
- Terraform reads state to know what exists
- Terraform compares desired (code) vs actual (state)
- Changes only what's different
- Without state, Terraform can't track resources

**Best Practices:**
```bash
# ✅ DO: Commit to git (with .gitignore for sensitive data)
git add terraform.tfstate
git commit -m "Update infrastructure state"

# ❌ DON'T: Commit secrets in state
# ✅ Use: Remote state backends (Azure Storage, Terraform Cloud)
```

#### 6. **Variable Validation**

```terraform
# Type safety
variable "environment" {
  type = string
  description = "Environment name"
  
  validation {
    condition = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod"
  }
}

# Default values
variable "replica_count" {
  type = number
  default = 3  # Falls back to 3 if not provided
}

# Sensitive data
variable "db_password" {
  type = string
  sensitive = true  # Won't print in logs
}
```

#### 7. **Output for State Sharing**

```terraform
# File: infra/dv/outputs.tf
output "cluster_endpoint" {
  description = "AKS API server endpoint"
  value = module.aks.cluster_endpoint
  sensitive = true  # Don't display in logs
}

output "cluster_ca_certificate" {
  description = "Base64 encoded cluster CA certificate"
  value = module.aks.ca_certificate
  sensitive = true
}

output "postgres_connection_string" {
  description = "PostgreSQL connection string"
  value = module.postgres.connection_string
  sensitive = true
}

# Access from command line
$ terraform output cluster_endpoint
"akscluster.hcp.eastus.azmk8s.io"

# Access programmatically (from other layers)
data "terraform_remote_state" "infra" {
  backend = "local"
  config = {
    path = "../../infra/dv/terraform.tfstate"
  }
}

# Use the output
resource "helm_release" "app" {
  # Connect using infra state
  provider = helm
  host = data.terraform_remote_state.infra.outputs.cluster_endpoint
}
```

#### 8. **Terraform Workflow**

```bash
# 1. WRITE: Create/update .tf files
vim infra/dv/main.tf

# 2. PLAN: Preview what will happen
terraform plan
# Output shows: + (create), ~ (modify), - (delete)

# 3. APPLY: Execute the plan
terraform apply
# Updates terraform.tfstate
# Creates/modifies resources on Azure

# 4. DESTROY: Cleanup
terraform destroy
# Removes all resources
# Updates terraform.tfstate
```

### Best Practices Summary

| Practice | Why | Example |
|----------|-----|---------|
| **Use Locals** | Single source of truth | `locals { env = "dev" }` |
| **Use Variables** | Parameterization | `variable "node_count"` |
| **Use Modules** | Reusability | `module "networking"` |
| **Use For_Each** | DRY code | `for_each = local.regions` |
| **Separate Concerns** | Easy maintenance | dv/ (config) vs modules/ (code) |
| **Output Values** | Share state | `output "endpoint"` |
| **Version Lock** | Reproducibility | `provider "azurerm" { version = "~> 3.0" }` |
| **Comments** | Documentation | `# This creates primary cluster` |

---

## Part 3: Helm Release Deployment via Terraform

### What is Helm?

Helm is the package manager for Kubernetes, like npm for Node.js or pip for Python.

- **Helm Chart** = package containing Kubernetes manifests (deployment, service, etc.)
- **Helm Release** = instance of a chart running in your cluster
- **Values** = configuration that customizes the chart

### Architecture

```
┌────────────────────────────────────────────────┐
│     HELM CHART (traefik)                       │
│  (Templates: deployment.yaml, service.yaml...) │
├────────────────────────────────────────────────┤
│          ↓ Apply values.yaml                   │
├────────────────────────────────────────────────┤
│  HELM RELEASE (Running in Kubernetes)          │
│  ├─ Deployment (3 replicas)                   │
│  ├─ Service (LoadBalancer)                    │
│  ├─ RBAC (ServiceAccount, ClusterRole)        │
│  └─ ConfigMap (configuration)                 │
└────────────────────────────────────────────────┘
```

### Traditional Helm Deployment

**Without Terraform:**
```bash
# Download values
curl https://traefik.github.io/traefik/values.yaml -o values.yaml

# Edit values
vim values.yaml
# Change: replicas: 3, image.tag: v2.11.0, etc

# Deploy manually
helm install traefik traefik/traefik -f values.yaml

# To update
vim values.yaml
helm upgrade traefik traefik/traefik -f values.yaml
```

**Problem:** Manual process, not version controlled, hard to reproduce

### Terraform Helm Deployment (Best Practice)

**File: `kubernetes-config/dv/main.tf`**

```terraform
# 1. CONFIGURATION LAYER: Define what you want
locals {
  environment = "dev"
  
  traefik = {
    replicas       = 3                 # How many replicas?
    image_tag      = "v2.11.0"         # Which version?
    service_type   = "LoadBalancer"    # External or internal?
    
    resources = {
      cpu_request    = "100m"          # Minimum CPU
      memory_request = "256Mi"         # Minimum memory
      cpu_limit      = "500m"          # Maximum CPU
      memory_limit   = "512Mi"         # Maximum memory
    }
    
    log_level = "INFO"                 # Verbosity
  }
}

# 2. PASS CONFIGURATION TO MODULE
module "kubernetes_config" {
  source = "../modules/config"
  
  # Pass all settings as variables
  traefik_replicas       = local.traefik.replicas
  traefik_image_tag      = local.traefik.image_tag
  traefik_service_type   = local.traefik.service_type
  traefik_cpu_request    = local.traefik.resources.cpu_request
  traefik_memory_request = local.traefik.resources.memory_request
  traefik_cpu_limit      = local.traefik.resources.cpu_limit
  traefik_memory_limit   = local.traefik.resources.memory_limit
  log_level              = local.traefik.log_level
}
```

**File: `kubernetes-config/modules/config/main.tf`**

```terraform
# 3. HELM RELEASE: Define the deployment
resource "helm_release" "traefik" {
  # Basic Helm release settings
  name             = "traefik"                                    # Release name
  repository       = "https://traefik.github.io"                 # Chart repository
  chart            = "traefik"                                   # Chart name
  version          = "24.0.0"                                    # Chart version
  namespace        = "traefik"                                   # K8s namespace
  create_namespace = true                                        # Create if missing

  # 4. BASE VALUES: Load default values from file
  values = [
    file("${path.module}/../helm-charts/traefik/values.yaml")
  ]

  # 5. OVERRIDE VALUES: Use variables to customize
  
  # Override: deployment replicas
  set {
    name  = "deployment.replicas"
    value = var.traefik_replicas
  }

  # Override: service type
  set {
    name  = "service.type"
    value = var.traefik_service_type
  }

  # Override: container image tag
  set {
    name  = "image.tag"
    value = var.traefik_image_tag
  }

  # Override: resource requests (minimum resources needed)
  set {
    name  = "resources.requests.cpu"
    value = var.traefik_cpu_request
  }

  set {
    name  = "resources.requests.memory"
    value = var.traefik_memory_request
  }

  # Override: resource limits (maximum resources allowed)
  set {
    name  = "resources.limits.cpu"
    value = var.traefik_cpu_limit
  }

  set {
    name  = "resources.limits.memory"
    value = var.traefik_memory_limit
  }

  # Override: logging level
  set {
    name  = "logs.general.level"
    value = var.log_level
  }

  # 6. LIFECYCLE: Handle updates
  lifecycle {
    ignore_changes = [version]  # Don't auto-update chart version
  }
}

# 7. KUBERNETES RESOURCES: Create supporting K8s objects

# Create namespace with labels
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

# Create IngressClass for routing
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
```

### How Helm Release Works

```
Step 1: RETRIEVE CHART
  └─> helm repository add traefik https://traefik.github.io
  └─> helm repository update
  └─> Downloads traefik/traefik:24.0.0

Step 2: MERGE VALUES
  └─> Default values from chart
  └─> + Base values.yaml file
  └─> + set { } overrides from Terraform
  
  Result: Final values dictionary

Step 3: TEMPLATE RENDERING
  Helm Templates (e.g., deployment.yaml):
  apiVersion: apps/v1
  kind: Deployment
  metadata:
    name: {{ .Release.Name }}
    namespace: {{ .Release.Namespace }}
  spec:
    replicas: {{ .Values.deployment.replicas }}  ←─ Filled from values
    template:
      spec:
        containers:
        - image: traefik:{{ .Values.image.tag }}  ←─ Filled from values
          resources:
            requests:
              cpu: {{ .Values.resources.requests.cpu }}
  
  ↓ After template rendering with values:
  
  apiVersion: apps/v1
  kind: Deployment
  metadata:
    name: traefik
    namespace: traefik
  spec:
    replicas: 3
    template:
      spec:
        containers:
        - image: traefik:v2.11.0
          resources:
            requests:
              cpu: 100m

Step 4: APPLY TO KUBERNETES
  kubectl apply -f rendered-manifests.yaml
  
  Result: Resources created in cluster
    ✓ 3 Traefik pods running
    ✓ LoadBalancer service created
    ✓ Namespace created
    ✓ IngressClass registered
```

### Configuration via Terraform Variables

**File: `kubernetes-config/modules/config/variables.tf`**

```terraform
# Define inputs that the module accepts

variable "traefik_replicas" {
  type        = number
  description = "Number of Traefik replicas"
  default     = 3
  
  validation {
    condition = var.traefik_replicas > 0 && var.traefik_replicas < 100
    error_message = "Replicas must be between 1 and 99"
  }
}

variable "traefik_image_tag" {
  type        = string
  description = "Traefik image tag"
  default     = "v2.11.0"
}

variable "traefik_service_type" {
  type        = string
  description = "Service type: LoadBalancer or ClusterIP"
  default     = "LoadBalancer"
  
  validation {
    condition = contains(["LoadBalancer", "ClusterIP", "NodePort"], var.traefik_service_type)
    error_message = "Must be LoadBalancer, ClusterIP, or NodePort"
  }
}

variable "traefik_cpu_request" {
  type        = string
  description = "CPU request (e.g., '100m', '500m', '1')"
  default     = "100m"
}

# ... more variables
```

### Helm Release Workflow

```bash
# 1. WRITE: Update configuration
vim kubernetes-config/dv/main.tf
# Change: traefik.replicas = 5

# 2. PLAN: See what will change
terraform plan -target=helm_release.traefik
# Output: helm_release.traefik will be updated

# 3. APPLY: Deploy
terraform apply -target=helm_release.traefik

# 4. VERIFY: Check deployment
kubectl get pods -n traefik
# Output: 5 traefik pods running (previously 3)

# 5. ROLLBACK: If needed
terraform apply -target=helm_release.traefik \
  -var="traefik_replicas=3"
# Back to 3 replicas
```

### Environment-Specific Configurations

```bash
# DEV: High verbosity, LoadBalancer, 3 replicas
# kubernetes-config/dv/main.tf
traefik = {
  replicas       = 3
  service_type   = "LoadBalancer"  # External access for testing
  log_level      = "INFO"
}

# STAGING: Moderate settings, 5 replicas
# kubernetes-config/staging/main.tf
traefik = {
  replicas       = 5
  service_type   = "ClusterIP"     # Internal only
  log_level      = "WARN"
}

# PROD: Optimized, 10 replicas
# kubernetes-config/prod/main.tf
traefik = {
  replicas       = 10
  service_type   = "ClusterIP"     # Behind Azure Front Door
  log_level      = "ERROR"         # Only errors
}
```

---

## Part 4: Application Build & Deployment

### Application Overview

The Flask application is a lightweight microservice that:
- Responds to HTTP requests
- Provides health check endpoints
- Runs in Docker containers
- Deploys to Kubernetes via Helm

### 1. Application Code

**File: `app/src/main.py`**

```python
from flask import Flask, jsonify
import logging
import os

# Initialize Flask app
app = Flask(__name__)

# Setup logging
logger = logging.getLogger(__name__)
logging.basicConfig(level=logging.INFO)

# Get environment variables
ENVIRONMENT = os.getenv("ENVIRONMENT", "development")
APP_VERSION = os.getenv("APP_VERSION", "1.0.0")

# ============ ROUTES ============

@app.route('/', methods=['GET'])
def index():
    """Main endpoint"""
    return jsonify({
        "status": "OK",
        "app": "hello-world",
        "message": "Application is running"
    }), 200

@app.route('/health', methods=['GET'])
def health():
    """Readiness probe endpoint
    
    Used by Kubernetes to determine if pod is ready to serve traffic
    - Called every 10 seconds
    - If fails, pod is removed from load balancer
    """
    logger.info("Health check - readiness")
    return '', 204  # 204 = No Content (success, no body needed)

@app.route('/healthz', methods=['GET'])
def healthz():
    """Liveness probe endpoint
    
    Used by Kubernetes to determine if pod is alive
    - Called every 30 seconds
    - If fails, pod is restarted
    """
    logger.info("Health check - liveness")
    return jsonify({"status": "alive"}), 200

@app.route('/api/info', methods=['GET'])
def info():
    """Application info endpoint"""
    return jsonify({
        "app": "hello-world",
        "version": APP_VERSION,
        "environment": ENVIRONMENT,
        "status": "healthy"
    }), 200

# ============ ERROR HANDLING ============

@app.errorhandler(404)
def not_found(error):
    """Handle 404 errors"""
    return jsonify({"error": "Not found"}), 404

@app.errorhandler(500)
def internal_error(error):
    """Handle 500 errors"""
    logger.error(f"Internal error: {error}")
    return jsonify({"error": "Internal server error"}), 500

# ============ RUN ============

if __name__ == '__main__':
    port = int(os.getenv("PORT", 8080))
    app.run(
        host='0.0.0.0',      # Listen on all interfaces
        port=port,           # Port 8080
        debug=False,         # Production mode
        threaded=True        # Enable threading
    )
```

### 2. Docker Build (Multi-Stage)

**File: `app/Dockerfile`**

Multi-stage builds create smaller images by separating build and runtime.

```dockerfile
# ============ STAGE 1: BUILDER ============
# This stage builds the application and installs dependencies

FROM python:3.12-slim as builder

WORKDIR /build

# Install build tools (gcc for compiling C extensions)
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements
COPY src/requirements.txt .

# Install Python dependencies to /build/.local
# --user: Install to ~/.local instead of system-wide
# --no-cache-dir: Don't cache, saves space
RUN pip install --no-cache-dir --user -r requirements.txt

# At this point, stage 1 has:
#   - Python packages installed in /build/.local
#   - Build tools (gcc) no longer needed

# ============ STAGE 2: RUNTIME ============
# This stage only includes what's needed to run the app

FROM python:3.12-slim

WORKDIR /app

# Create non-root user (security best practice)
# -m: Create home directory
# -u 1000: Specific UID (1000 = regular user)
RUN useradd -m -u 1000 appuser

# Copy ONLY Python packages from builder stage
# This is much smaller than copying entire builder
COPY --from=builder /root/.local /home/appuser/.local

# Copy application code
COPY src/main.py .

# Set environment variables
ENV \
    PATH=/home/appuser/.local/bin:$PATH \
    PYTHONUNBUFFERED=1 \
    PORT=8080 \
    APP_NAME=hello-world \
    APP_VERSION=1.0.0 \
    ENVIRONMENT=production

# Fix permissions
RUN chown -R appuser:appuser /app

# Switch to non-root user
USER appuser

# Expose port
EXPOSE 8080

# Health check (Docker-level, independent of K8s)
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
    CMD python -c "import urllib.request; urllib.request.urlopen('http://localhost:8080/healthz')" || exit 1

# Run application
CMD ["python", "main.py"]
```

**Why multi-stage?**

```
Without multi-stage:
  Image: python:3.12-slim (150MB) + gcc (200MB) + dependencies (50MB) = 400MB

With multi-stage:
  Stage 1: Full build environment (400MB) - DISCARDED
  Stage 2: Only runtime (python + dependencies) = 200MB
  Result: 50% smaller image
```

### 3. Application Dependencies

**File: `app/src/requirements.txt`**

```
Flask==3.0.0          # Web framework
Werkzeug==3.0.1       # WSGI utilities
```

These are minimal for a simple health-check app.

### 4. Helm Chart for Kubernetes Deployment

**File: `app/Chart.yaml`** (Chart metadata)

```yaml
apiVersion: v2
name: hello-world
description: A Helm chart for the hello-world Flask application
type: application
version: 1.0.0
appVersion: "1.0.0"
```

**File: `app/values.yaml`** (Default configuration)

```yaml
# Number of pod replicas
replicaCount: 1

# Container image
image:
  repository: myregistry.azurecr.io/hello-world  # Where image is stored
  pullPolicy: IfNotPresent                        # Pull policy
  tag: "1.0.0"                                    # Image tag/version

# Kubernetes Service
service:
  type: ClusterIP                                 # Service type
  port: 8080                                      # Service port
  targetPort: 8080                                # Container port

# Pod resource limits
resources:
  requests:                                       # Minimum guaranteed resources
    cpu: 100m                                     # 0.1 CPU cores
    memory: 128Mi                                 # 128MB RAM
  limits:                                         # Maximum allowed resources
    cpu: 500m                                     # 0.5 CPU cores
    memory: 256Mi                                 # 256MB RAM

# Liveness probe (is pod alive?)
livenessProbe:
  httpGet:
    path: /healthz
    port: 8080
  initialDelaySeconds: 10                         # Wait 10s before first check
  periodSeconds: 30                               # Check every 30s
  failureThreshold: 3                             # Restart after 3 failures

# Readiness probe (is pod ready for traffic?)
readinessProbe:
  httpGet:
    path: /health
    port: 8080
  initialDelaySeconds: 5                          # Wait 5s before first check
  periodSeconds: 10                               # Check every 10s
  failureThreshold: 3                             # Remove from LB after 3 failures

# Environment variables
env:
  - name: ENVIRONMENT
    value: "production"
  - name: APP_NAME
    value: "hello-world"
  - name: APP_VERSION
    value: "1.0.0"
```

**File: `app/templates/deployment.yaml`** (Kubernetes Deployment)

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: {{ .Release.Name }}
  namespace: {{ .Release.Namespace }}
  labels:
    app: {{ .Chart.Name }}
    version: {{ .Chart.AppVersion }}

spec:
  # How many replicas?
  replicas: {{ .Values.replicaCount }}
  
  selector:
    matchLabels:
      app: {{ .Chart.Name }}

  template:
    metadata:
      labels:
        app: {{ .Chart.Name }}
        version: {{ .Chart.AppVersion }}

    spec:
      # Security context (run as non-root)
      securityContext:
        runAsNonRoot: true
        runAsUser: 1000
        fsGroup: 1000

      containers:
      - name: app
        image: {{ .Values.image.repository }}:{{ .Values.image.tag }}
        imagePullPolicy: {{ .Values.image.pullPolicy }}
        
        ports:
        - name: http
          containerPort: {{ .Values.service.targetPort }}
          protocol: TCP

        # Environment variables
        env:
        {{- range $key, $val := .Values.env }}
        - name: {{ $key }}
          value: "{{ $val }}"
        {{- end }}

        # Liveness probe
        livenessProbe:
          httpGet:
            path: {{ .Values.livenessProbe.httpGet.path }}
            port: {{ .Values.livenessProbe.httpGet.port }}
          initialDelaySeconds: {{ .Values.livenessProbe.initialDelaySeconds }}
          periodSeconds: {{ .Values.livenessProbe.periodSeconds }}
          failureThreshold: {{ .Values.livenessProbe.failureThreshold }}

        # Readiness probe
        readinessProbe:
          httpGet:
            path: {{ .Values.readinessProbe.httpGet.path }}
            port: {{ .Values.readinessProbe.httpGet.port }}
          initialDelaySeconds: {{ .Values.readinessProbe.initialDelaySeconds }}
          periodSeconds: {{ .Values.readinessProbe.periodSeconds }}
          failureThreshold: {{ .Values.readinessProbe.failureThreshold }}

        # Resource limits
        resources:
          requests:
            cpu: {{ .Values.resources.requests.cpu }}
            memory: {{ .Values.resources.requests.memory }}
          limits:
            cpu: {{ .Values.resources.limits.cpu }}
            memory: {{ .Values.resources.limits.memory }}

        # Security context for container
        securityContext:
          allowPrivilegeEscalation: false
          runAsNonRoot: true
          runAsUser: 1000
```

**File: `app/templates/service.yaml`** (Kubernetes Service)

```yaml
apiVersion: v1
kind: Service
metadata:
  name: {{ .Release.Name }}
  namespace: {{ .Release.Namespace }}

spec:
  type: {{ .Values.service.type }}
  
  selector:
    app: {{ .Chart.Name }}

  ports:
  - protocol: TCP
    port: {{ .Values.service.port }}
    targetPort: {{ .Values.service.targetPort }}
    name: http
```

### 5. Build & Deployment Flow

```
┌─────────────────────────────────────────────────────────┐
│ 1. WRITE CODE                                           │
├─────────────────────────────────────────────────────────┤
│ Developer writes src/main.py                            │
│ Adds requirements.txt with dependencies                 │
└─────────────────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────────────────┐
│ 2. BUILD DOCKER IMAGE                                  │
├─────────────────────────────────────────────────────────┤
│ $ docker build -t myregistry/hello-world:1.0.0 .       │
│                                                         │
│ Process:                                                │
│   Stage 1: Install Python + gcc + dependencies         │
│   Stage 2: Copy minimal runtime to fresh image         │
│   Result: ~200MB Docker image                          │
└─────────────────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────────────────┐
│ 3. PUSH TO REGISTRY                                     │
├─────────────────────────────────────────────────────────┤
│ $ docker push myregistry.azurecr.io/hello-world:1.0.0  │
│                                                         │
│ Image now in Azure Container Registry                  │
└─────────────────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────────────────┐
│ 4. DEPLOY VIA HELM                                      │
├─────────────────────────────────────────────────────────┤
│ $ helm install hello-world ./app                        │
│                                                         │
│ Helm uses values.yaml to:                               │
│   - Pull image from registry                            │
│   - Create 1 pod replica                                │
│   - Create Service (ClusterIP, port 8080)               │
│   - Set resource requests/limits                        │
│   - Configure health probes                             │
│                                                         │
│ Result: Application running in Kubernetes              │
└─────────────────────────────────────────────────────────┘
                    ↓
┌─────────────────────────────────────────────────────────┐
│ 5. VERIFY DEPLOYMENT                                    │
├─────────────────────────────────────────────────────────┤
│ $ kubectl get pods                                      │
│ hello-world-xxxxx   1/1     Running                     │
│                                                         │
│ $ kubectl logs hello-world-xxxxx                        │
│ * Running on http://0.0.0.0:8080                        │
│                                                         │
│ $ curl http://service-ip:8080/api/info                 │
│ {"app": "hello-world", "version": "1.0.0"}             │
└─────────────────────────────────────────────────────────┘
```

### 6. Application Lifecycle in Kubernetes

```
Pod Startup Sequence:

1. IMAGE PULL
   ├─ Kubernetes queries ACR
   ├─ Downloads image (200MB)
   └─ ~5 seconds

2. CONTAINER START
   ├─ Docker creates container from image
   ├─ Mounts volumes
   ├─ Sets environment variables
   └─ Runs CMD: python main.py

3. APPLICATION INITIALIZATION
   ├─ Flask app initializes
   ├─ Routes registered
   └─ Listening on 0.0.0.0:8080

4. HEALTH CHECKS START
   ├─ Startup delay: 5s (initialDelaySeconds)
   ├─ Readiness probe: /health every 10s
   │   └─ If success (204): pod marked READY
   │   └─ If fail: pod not added to load balancer
   └─ Liveness probe: /healthz every 30s
       └─ If fail 3x: pod restarted

5. TRAFFIC DELIVERY
   ├─ Service sends requests to pod
   ├─ Readiness probe passes
   └─ Pod serves traffic

6. POD TERMINATION (on update/delete)
   ├─ Termination signal sent
   ├─ Grace period: 30s (default)
   ├─ App gracefully shuts down
   └─ Pod removed from service
```

### 7. Deployment Updates

```bash
# Scenario: Update app from v1.0.0 to v1.0.1

# Step 1: Build new image
docker build -t myregistry/hello-world:1.0.1 .
docker push myregistry/hello-world:1.0.1

# Step 2: Update Helm values
vim app/values.yaml
# Change: tag: "1.0.1"

# Step 3: Upgrade deployment (rolling update)
helm upgrade hello-world ./app

# What happens:
#   1. Kubernetes creates new pod with v1.0.1
#   2. Waits for readiness probe to pass
#   3. Adds new pod to load balancer
#   4. Removes old pod (graceful termination)
#   5. Result: Zero-downtime update

# Verify
kubectl get pods
# hello-world-xxxxx (v1.0.1)   1/1     Running

# Rollback if needed
helm rollback hello-world 1
```

### 8. Scaling the Application

```bash
# Scenario: Increase replicas from 1 to 3

# Option 1: Update values
vim app/values.yaml
# Change: replicaCount: 3

helm upgrade hello-world ./app

# Option 2: Direct kubectl (not recommended, not tracked)
kubectl scale deployment hello-world --replicas=3

# Option 3: Via Kubernetes HPA (auto-scaling)
# Scales based on CPU/memory usage

# Verify
kubectl get pods
# hello-world-xxxxx   1/1     Running
# hello-world-yyyyy   1/1     Running
# hello-world-zzzzz   1/1     Running
```

---

## Complete End-to-End Flow

```
┌─────────────────────────────────────────────────────────────────────┐
│                    COMPLETE DEPLOYMENT FLOW                         │
└─────────────────────────────────────────────────────────────────────┘

1️⃣  INFRASTRUCTURE LAYER
    ├─ Write: infra/dv/main.tf (locals with Azure config)
    ├─ Terraform: Creates Azure resources
    ├─ Output: terraform.tfstate (cluster credentials)
    └─ Result: AKS cluster ready in Azure

2️⃣  KUBERNETES LAYER
    ├─ Read: Cluster credentials from infra state
    ├─ Write: kubernetes-config/dv/main.tf (Traefik config)
    ├─ Terraform: Deploys Helm release (Traefik)
    └─ Result: Ingress controller running in K8s

3️⃣  APPLICATION LAYER
    ├─ Write: app/src/main.py (Flask app)
    ├─ Build: docker build (creates image)
    ├─ Push: docker push (stores in registry)
    ├─ Deploy: helm install (creates K8s resources)
    └─ Result: App pods running, accessible via Traefik

4️⃣  REQUEST FLOW
    User Request
        ↓
    Traefik (IngressClass)
        ↓
    Service (hello-world)
        ↓
    Pod (running Flask app)
        ↓
    Flask routes (/health, /api/info, etc)
        ↓
    Response back to user
```

---

## Summary: Why Each Technology?

| Layer | Technology | Why |
|-------|-----------|-----|
| **Infrastructure** | Terraform | Version control, reproducible, IaC |
| **Ingress** | Traefik via Helm | Industry standard, feature-rich, easy config |
| **Deployment** | Helm + Terraform | Single source of truth, GitOps ready |
| **Container** | Docker multi-stage | Small images, security, efficient |
| **Application** | Flask | Lightweight, perfect for microservices |

Each layer is independent, allowing:
- ✅ Teams to work in parallel
- ✅ Easy to scale each component
- ✅ Version control for everything
- ✅ Reproducible deployments
- ✅ Environment consistency (dev→staging→prod)
