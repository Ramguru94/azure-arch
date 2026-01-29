# Azure Architecture

This repository contains the complete infrastructure and application setup for a multi-region, cloud-native Azure deployment with containerized applications, Kubernetes ingress controllers, and comprehensive monitoring.

## Quick Start

```bash
# 1. Deploy Infrastructure (Azure resources)
cd infra/dv
terraform init
terraform apply

# 2. Deploy Kubernetes Configuration (Traefik ingress)
cd kubernetes-config/dv
terraform init
terraform apply

# 3. Deploy Application (Flask app to AKS)
Will be deployed via pipeline
```

## Overview

The architecture implements a **multi-region, highly available, and secure** cloud infrastructure with:
- **Infrastructure Layer**: Azure cloud resources (AKS, Redis, PostgreSQL, Storage, CDN)
- **Kubernetes Layer**: Traefik ingress controller with RBAC and ingress classes
- **Application Layer**: Containerized Flask application with health checks and Kubernetes probes

## Architecture Diagram

![Azure Architecture](.document360/assets/azure-arch.png)

For a Mermaid-based interactive version:
![Azure Architecture Mermaid](.document360/assets/azure-arch-mermaid.png)

---

## Folder Structure & Setup

### 1. `/infra` - Infrastructure Layer
Defines all Azure cloud resources using Terraform modules.

```
infra/
├── dv/                          # Dev environment
│   ├── main.tf                  # All locals with infrastructure config
│   ├── versions.tf              # Provider setup
│   ├── outputs.tf               # Output values
│   ├── backend.tf               # Remote state config
│   └── terraform.tfstate        # State file (generated)
└── modules/
    ├── networking.tf            # VNets, subnets, peering
    ├── aks.tf                   # AKS clusters, node pools
    ├── redis.tf                 # Redis caches, geo-replication
    ├── postgres.tf              # PostgreSQL servers
    ├── storage.tf               # Blob storage, static websites
    ├── frontdoor.tf             # CDN, load balancing
    └── variables.tf             # All input variables
```

**Environment Configuration** (`dv/main.tf`):
```terraform
locals {
  environment = "dev"
  project     = "aks-multiregion"
  
  # Multi-region setup
  primary = {
    region = "eastus"
    location = "East US"
    # AKS, VNet, subnets, zones...
  }
  secondary = {
    region = "westus2"
    location = "West US 2"
    # Standby region configuration
  }
  
  # Resources
  aks = { version = "1.32", ... }
  node_pools = { system: {...}, memory_optimized: {...}, cpu_optimized: {...} }
  redis = { capacity = 2, family = "C", sku_name = "Standard" }
  postgres = { version = "16", sku_name = "B_Gen5_1", ... }
  tags = { environment = "dev", managed_by = "terraform" }
}

module "infrastructure" {
  source = "../modules"
  # Passes all locals as variables to modules
}
```

**What Gets Deployed:**
- Azure Resource Groups (primary & secondary regions)
- Virtual Networks with peering
- AKS clusters (3 node pools: system, memory, CPU-optimized)
- Redis clusters with geo-replication
- PostgreSQL servers with zone redundancy
- Azure Storage for static websites
- Azure Front Door for CDN/load balancing
- Private endpoints and DNS zones

**Terraform State Output:**
Stored in `infra/dv/terraform.tfstate` - contains:
- `cluster_endpoint` - AKS API server URL
- `cluster_ca_certificate` - Kubernetes auth cert
- `client_certificate` - Client cert for auth
- `client_key` - Client key for auth
- Resource IDs and connection strings

**To Deploy:**
```bash
cd infra/dv
terraform init      # Initialize backend
terraform plan      # Preview changes
terraform apply     # Deploy resources
```

---

### 2. `/kubernetes-config` - Kubernetes Layer
Configures Kubernetes resources and ingress controller using Terraform + Helm.

```
kubernetes-config/
├── dv/                          # Dev environment
│   ├── main.tf                  # Traefik config locals + module call
│   ├── versions.tf              # Provider setup (Helm + Kubernetes)
│   ├── outputs.tf               # Configuration summary
│   └── terraform.tfstate        # State file (generated)
└── modules/
    └── config/
        ├── main.tf              # Helm release + K8s resources
        ├── variables.tf         # Input variables
        ├── outputs.tf           # Module outputs
        ├── versions.tf          # Provider requirements
        ├── data.tf              # Data sources
        └── helm-charts/
            └── traefik/
                └── values.yaml  # Traefik Helm chart defaults
```

**Environment Configuration** (`dv/main.tf`):
```terraform
locals {
  environment = "dev"
  project     = "aks-multiregion"
  
  traefik = {
    replicas       = 3          # Scales: dev=3, staging=5, prod=10
    image_tag      = "v2.11.0"  # Update per environment
    service_type   = "LoadBalancer"  # LoadBalancer for dev, ClusterIP for prod
    
    resources = {
      cpu_request    = "100m"   # Scales with environment
      memory_request = "256Mi"
      cpu_limit      = "500m"
      memory_limit   = "512Mi"
    }
    
    log_level = "INFO"          # DEBUG for dev, WARN for prod
  }
}

module "kubernetes_config" {
  source = "../modules/config"
  
  # Cluster auth from infra state
  cluster_endpoint           = data.terraform_remote_state.cluster_infra.outputs.cluster_endpoint
  cluster_ca_certificate    = data.terraform_remote_state.cluster_infra.outputs.cluster_ca_certificate
  client_certificate        = data.terraform_remote_state.cluster_infra.outputs.client_certificate
  client_key                = data.terraform_remote_state.cluster_infra.outputs.client_key
  
  # Traefik config from locals
  traefik_replicas       = local.traefik.replicas
  traefik_image_tag      = local.traefik.image_tag
  traefik_service_type   = local.traefik.service_type
  traefik_cpu_request    = local.traefik.resources.cpu_request
  # ... other resource settings
}

data "terraform_remote_state" "cluster_infra" {
  backend = "local"
  config = {
    path = "../../infra/dv/terraform.tfstate"  # Links to infra state
  }
}
```

**Key Features:**
- Reads cluster credentials from `infra/dv/terraform.tfstate`
- Deploys Traefik Helm chart with configuration overrides
- Creates Kubernetes namespace, IngressClass, RBAC
- All configuration environment-specific in `dv/main.tf` locals

**What Gets Deployed:**
- Traefik Helm release (version 24.0.0)
- Kubernetes namespace: `traefik`
- IngressClass: `traefik` (for application ingress routing)
- Pod replicas scale based on `traefik.replicas` (dev: 3, prod: 10)
- Resource requests/limits for pod scheduling
- Service type: LoadBalancer (dev) vs ClusterIP (prod)

**To Deploy:**
```bash
cd kubernetes-config/dv
terraform init      # Initialize backend
terraform plan      # Preview Helm release
terraform apply     # Deploy Traefik + K8s resources
```

---

### 3. `/app` - Application Layer
Contains the containerized application (Flask) and Helm chart for Kubernetes deployment.

```
app/
├── src/
│   ├── main.py                  # Flask application
│   └── requirements.txt          # Python dependencies
├── Dockerfile                   # Multi-stage Docker build
├── Chart.yaml                   # Helm chart metadata
├── values.yaml                  # Default Helm values
├── templates/
│   ├── deployment.yaml          # Kubernetes deployment
│   ├── service.yaml             # Kubernetes service
│   └── ingress.yaml             # Optional ingress resource
├── pipelines/                   # CI/CD pipeline configs
└── README.md                    # Application setup guide
```

**Application Configuration** (`values.yaml`):
```yaml
replicaCount: 1
image:
  repository: myregistry.azurecr.io/hello-world
  tag: "1.0.0"
  pullPolicy: IfNotPresent

service:
  type: ClusterIP
  port: 8080
  targetPort: 8080

resources:
  requests:
    cpu: 100m
    memory: 128Mi
  limits:
    cpu: 500m
    memory: 256Mi

livenessProbe:
  httpGet:
    path: /healthz
    port: 8080
  initialDelaySeconds: 10
  periodSeconds: 30

readinessProbe:
  httpGet:
    path: /health
    port: 8080
  initialDelaySeconds: 5
  periodSeconds: 10
```

**Application** (`src/main.py`):
```python
from flask import Flask, jsonify
import logging

app = Flask(__name__)
logger = logging.getLogger(__name__)

@app.route('/')
def index():
    return jsonify({"status": "OK", "app": "hello-world"})

@app.route('/health')
def health():
    return '', 204  # Readiness probe

@app.route('/healthz')
def healthz():
    return jsonify({"status": "alive"})  # Liveness probe

@app.route('/api/info')
def info():
    return jsonify({
        "app": "hello-world",
        "version": "1.0.0",
        "environment": os.getenv("ENVIRONMENT", "dev")
    })
```

**Docker Build** (`Dockerfile`):
- Multi-stage build for minimal image size (~200MB)
- Non-root user (UID 1000) for security
- Health check endpoint defined
- Environment variables pre-set

**What Gets Deployed:**
- Pod replicas (default: 1, scales with HPA)
- Container port: 8080
- Liveness probe: `/healthz` (restart if fails)
- Readiness probe: `/health` (remove from load balancer if fails)
- Resources: requests 100m CPU/128Mi memory, limits 500m/256Mi
- Service type: ClusterIP (internal K8s traffic)
- Optional Ingress for external routing (uses Traefik from kubernetes-config)

**To Deploy:**
```bash
cd app

# Option 1: Using Helm
helm install hello-world . \
  -n default \
  --set image.tag=1.0.0 \
  --set replicaCount=3

# Option 2: Build and push custom image
docker build -t myregistry.azurecr.io/hello-world:1.0.0 .
docker push myregistry.azurecr.io/hello-world:1.0.0
```

---

## Data Flow Architecture

### Complete Deployment Flow

```
┌─────────────────────────────────────────────────────────────┐
│ 1. INFRASTRUCTURE LAYER (infra/dv)                          │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  locals {                                                  │
│    environment = "dev"                                     │
│    primary = { region = "eastus", ... }                    │
│    secondary = { region = "westus2", ... }                 │
│    aks = { version = "1.32", ... }                         │
│    redis = { capacity = 2, ... }                           │
│    postgres = { version = "16", ... }                      │
│  }                                                         │
│                                                             │
│  ↓ terraform apply                                         │
│                                                             │
│  OUTPUT: terraform.tfstate                                 │
│    - cluster_endpoint                                      │
│    - cluster_ca_certificate                                │
│    - client_certificate                                    │
│    - client_key                                            │
│    - AKS resource IDs                                      │
│    - Redis connection strings                              │
│    - PostgreSQL connection strings                         │
│                                                             │
└─────────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────────┐
│ 2. KUBERNETES LAYER (kubernetes-config/dv)                 │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  data.terraform_remote_state.cluster_infra {               │
│    path = "../../infra/dv/terraform.tfstate"               │
│  }                                                         │
│                                                             │
│  locals {                                                  │
│    traefik = {                                             │
│      replicas = 3                                          │
│      image_tag = "v2.11.0"                                 │
│      service_type = "LoadBalancer"                         │
│      resources = { ... }                                   │
│    }                                                       │
│  }                                                         │
│                                                             │
│  module.kubernetes_config:                                 │
│    - Helm release "traefik" (v24.0.0)                      │
│    - K8s namespace "traefik"                               │
│    - K8s IngressClass "traefik"                            │
│    - RBAC setup for Traefik                                │
│                                                             │
│  ↓ terraform apply                                         │
│                                                             │
│  OUTPUT: Traefik running in AKS cluster                    │
│    - 3 Traefik pods (replicas)                             │
│    - LoadBalancer service (external IP)                    │
│    - Namespace with labels                                 │
│    - IngressClass ready for app ingress                    │
│                                                             │
└─────────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────────┐
│ 3. APPLICATION LAYER (app/)                                │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  values.yaml:                                              │
│    replicaCount: 1                                         │
│    image: myregistry/hello-world:1.0.0                     │
│    service.type: ClusterIP                                 │
│    service.port: 8080                                      │
│    resources.requests: 100m/128Mi                          │
│    livenessProbe: /healthz                                 │
│    readinessProbe: /health                                 │
│                                                             │
│  templates/deployment.yaml:                                │
│    - Pod spec with above values                            │
│    - Environment variables                                 │
│    - Health probes                                         │
│                                                             │
│  templates/service.yaml:                                   │
│    - ClusterIP service port 8080                           │
│                                                             │
│  templates/ingress.yaml (optional):                        │
│    - Routes via IngressClass "traefik"                     │
│    - External access through Traefik load balancer         │
│                                                             │
│  ↓ helm install hello-world . (or: helm apply)             │
│                                                             │
│  OUTPUT: App running in AKS cluster                        │
│    - 1 Pod replica (Flask app)                             │
│    - ClusterIP service on port 8080                        │
│    - Traffic through Traefik (if ingress configured)       │
│    - Health checks: liveness & readiness                   │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

### Request Flow Through Architecture

```
External Request
        ↓
    Cloudflare (DNS + WAF)
        ↓
    Azure Front Door (Global LB)
        ↓
    Traefik LoadBalancer Service (kubernetes-config)
        ↓
    Traefik Ingress Controller (3 pods, replicas from locals)
        ↓
    Application Service (app/templates/service.yaml)
        ↓
    Application Pod(s) (Flask app, src/main.py)
        ↓
    Redis/PostgreSQL (from infra layer)
        ↓
    Response back through layers
```

### Environment Variable Flow

```
1. INFRASTRUCTURE (infra/dv/main.tf)
   locals {
     environment = "dev"
     project = "aks-multiregion"
   }
   ↓
2. KUBERNETES CONFIG (kubernetes-config/dv/main.tf)
   locals {
     environment = "dev"           # From infra
     traefik {
       log_level = "INFO"          # Environment-specific
       replicas = 3                # Environment-specific
     }
   }
   ↓
3. APPLICATION (app/values.yaml)
   env:
     - name: ENVIRONMENT
       value: "dev"                # From kubernetes-config
     - name: APP_NAME
       value: "hello-world"        # Application-specific
   ↓
4. RUNNING POD
   $ENVIRONMENT = "dev"
   $APP_NAME = "hello-world"
```

---

## Creating Additional Environments

To create `staging` or `prod` environments:

### Step 1: Copy Infrastructure Environment
```bash
cp -r infra/dv infra/staging
```

Update `infra/staging/main.tf`:
```terraform
locals {
  environment = "staging"
  secondary_enabled = false        # Reduce cost
  
  aks = {
    version = "1.32"
  }
  
  node_pools = {
    system = { node_count = 2, vm_size = "Standard_D2s_v3" }
    memory_optimized = { node_count = 1 }
    cpu_optimized = { node_count = 1 }
  }
  
  redis = { capacity = 4 }          # More capacity
  postgres = { sku_name = "B_Gen5_2" }  # Better tier
}
```

### Step 2: Copy Kubernetes Config Environment
```bash
cp -r kubernetes-config/dv kubernetes-config/staging
```

Update `kubernetes-config/staging/main.tf`:
```terraform
locals {
  environment = "staging"
  
  traefik = {
    replicas = 5                    # More replicas
    service_type = "ClusterIP"      # Use internal LB
    
    resources = {
      cpu_request = "200m"          # More resources
      memory_request = "512Mi"
      cpu_limit = "500m"
      memory_limit = "512Mi"
    }
    
    log_level = "WARN"              # Less verbose
  }
}

# Update path to staging state
data.terraform_remote_state.cluster_infra {
  config = {
    path = "../../infra/staging/terraform.tfstate"
  }
}
```

### Step 3: Deploy Both Environments
```bash
# Deploy staging infrastructure
cd infra/staging && terraform apply

# Deploy staging kubernetes
cd kubernetes-config/staging && terraform apply

# Deploy staging app
cd app && helm install hello-world . -n staging
```

---

## Key Configuration Differences Between Environments

| Item | Dev | Staging | Prod |
|------|-----|---------|------|
| **Replicas** | 3 | 5 | 10 |
| **Service Type** | LoadBalancer | ClusterIP | ClusterIP |
| **Resources CPU Request** | 100m | 200m | 500m |
| **Resources Memory Request** | 256Mi | 512Mi | 1Gi |
| **Resources CPU Limit** | 500m | 500m | 2000m |
| **Log Level** | INFO | WARN | ERROR |
| **Secondary Region** | Yes | Yes | Yes |
| **Redis Capacity** | 2 | 4 | 6 |
| **PostgreSQL Tier** | B_Gen5_1 | B_Gen5_2 | B_Gen5_4 |
| **Image Tag** | Latest | v1.x.x | v1.x.x (stable) |

---

## Deployment Sequence

**Always deploy in this order:**

1. ✅ **Infrastructure First** (`infra/dv` → `terraform apply`)
   - Creates AKS cluster and dependencies
   - Generates `terraform.tfstate` with cluster credentials

2. ✅ **Kubernetes Config Second** (`kubernetes-config/dv` → `terraform apply`)
   - Reads cluster credentials from infra state
   - Deploys Traefik ingress controller
   - Registers IngressClass for app routing

3. ✅ **Application Last** (`app/` → `helm install`)
   - Deploys app pods to running AKS cluster
   - Routes traffic through Traefik

**Teardown in reverse order:**
1. `helm uninstall hello-world` (App)
2. `terraform destroy` (kubernetes-config)
3. `terraform destroy` (infra)

---

## Key Components

### Edge & Zero Trust
- **Users**: End users accessing the application
- **Cloudflare**: DNS, WAF, and DDoS protection
- **Azure Front Door**: Global traffic management and load balancing

### Deployment Layers
1. **Infrastructure Layer** (`/infra`) - Azure cloud resources via Terraform
2. **Kubernetes Layer** (`/kubernetes-config`) - Traefik ingress via Terraform + Helm
3. **Application Layer** (`/app`) - Flask app via Helm chart

### Multi-Region Architecture
- **Region 1 (Active)**: Primary region (East US) with full AKS cluster
- **Region 2 (Standby)**: Secondary region (West US 2) for failover

Each region includes:
- **AKS Cluster**: Multi-Availability Zone Kubernetes clusters
- **Traefik Ingress**: Ingress controller with middleware
- **Application Pods**: Containerized application workloads
- **Auto-scaling**: HPA for pod replication

### Data & Cache Layer
- **Primary Database**: PostgreSQL (multi-region replicated)
- **Redis Cluster**: Multi-region Redis cache
- **Object Storage**: Azure Blob Storage for static assets

### Observability
- **Prometheus**: Metrics collection
- **Grafana**: Dashboards and visualization
- **Loki**: Log aggregation
- **Alertmanager**: Alert management

### Security
- **Vault**: Secrets management
- **Workload Identity**: Secure workload authentication
- **OPA Policies**: Policy enforcement

## Traffic Flow

```
User Request
    ↓
Cloudflare (DNS + WAF)
    ↓
Azure Front Door (Global Load Balancer)
    ↓
Traefik Ingress (kubernetes-config/dv deployed)
    ↓
Application Service (app/ deployed)
    ↓
Application Pod(s) (Flask app running)
    ↓
Data Layer (Redis, PostgreSQL from infra/dv)
    ↓
Response back through layers
```

## Deployment Sequence

**Always deploy in this order:**

1. ✅ **Infrastructure First** (`infra/dv` → `terraform apply`)
   - Creates AKS cluster and dependencies
   - Generates `terraform.tfstate` with cluster credentials

2. ✅ **Kubernetes Second** (`kubernetes-config/dv` → `terraform apply`)
   - Reads cluster credentials from infra state
   - Deploys Traefik ingress controller
   - Registers IngressClass for app routing

3. ✅ **Application Last** (`app/` → `helm install`)
   - Deploys app pods to running AKS cluster
   - Routes traffic through Traefik

---

## Troubleshooting & Commands

### Check Infrastructure Deployment
```bash
cd infra/dv

# View current configuration
terraform show

# See what will change
terraform plan

# Check state file
terraform state list
terraform state show 'azurerm_kubernetes_cluster.primary'
```

### Check Kubernetes Config Deployment
```bash
cd kubernetes-config/dv

# Verify Traefik deployment
kubectl get pods -n traefik
kubectl get services -n traefik
kubectl get ingressclass

# Check Traefik logs
kubectl logs -n traefik -l app.kubernetes.io/name=traefik
```

### Check Application Deployment
```bash
cd app

# List all releases
helm list -a

# Check application pods
kubectl get pods -l app=hello-world
kubectl logs -l app=hello-world

# Test application endpoints
kubectl port-forward svc/hello-world 8080:8080
curl http://localhost:8080/health
curl http://localhost:8080/api/info
```

### Update Environments
```bash
# Update infrastructure
cd infra/staging
terraform apply -var-file="custom.tfvars"

# Update kubernetes config
cd kubernetes-config/staging
terraform apply

# Update application
cd app
helm upgrade hello-world . -n staging --values custom-values.yaml
```

## Region Outage Scenario

In the event of a region outage (e.g., Region 1 becomes unavailable):

1. **Azure Front Door** automatically detects failed region
2. Reroutes traffic to **Region 2** (standby)
3. **Redis Cluster** ensures cache consistency across regions
4. **PostgreSQL Replication** keeps database synchronized
5. **Traefik** ingress continues routing traffic normally
6. **Application Pods** in Region 2 handle incoming requests
7. **Monitoring** alerts on failover event

This design provides high availability and business continuity.

## Environment Configuration Quick Reference

### Dev Environment
```bash
# Deploy
cd infra/dv && terraform apply
cd kubernetes-config/dv && terraform apply
cd app && helm install hello-world .

# Cleanup
helm uninstall hello-world
cd kubernetes-config/dv && terraform destroy
cd infra/dv && terraform destroy
```

### Staging Environment
```bash
# Create staging from dev
cp -r infra/dv infra/staging
cp -r kubernetes-config/dv kubernetes-config/staging

# Edit staging configs (replicas, resources, log_level)
vim infra/staging/main.tf
vim kubernetes-config/staging/main.tf

# Deploy
cd infra/staging && terraform apply
cd kubernetes-config/staging && terraform apply
cd app && helm install hello-world . -n staging
```

### Prod Environment
```bash
# Create prod from dev
cp -r infra/dv infra/prod
cp -r kubernetes-config/dv kubernetes-config/prod

# Edit prod configs (higher replicas, resources, ClusterIP)
vim infra/prod/main.tf
vim kubernetes-config/prod/main.tf

# Deploy
cd infra/prod && terraform apply
cd kubernetes-config/prod && terraform apply
cd app && helm install hello-world . -n prod
```

## Common Issues & Solutions

### Issue: Traefik pods not starting
```bash
# Check logs
kubectl logs -n traefik <pod-name>

# Check cluster credentials were passed correctly
cd kubernetes-config/dv
terraform show | grep cluster_endpoint
```

### Issue: Application can't reach database
```bash
# Verify PostgreSQL connection string in infra output
cd infra/dv
terraform output postgres_connection_string

# Check network connectivity (private endpoints, DNS)
kubectl exec -it <app-pod> -- nslookup postgres.database.azure.com
```

## Key Principles

1. **Single Source of Truth**: All configuration in `dv/main.tf` locals
2. **Immutable Infrastructure**: Recreate rather than update resources
3. **Layered Deployment**: Infrastructure → Kubernetes → Application
4. **Environment Parity**: Use same code for all environments, different locals
5. **State Management**: Keep `terraform.tfstate` in version control (.gitignore) or remote backend
6. **Scalability**: Change one variable (`replicas`, `node_count`) to scale
7. **Security**: Non-root containers, RBAC, secrets management, private endpoints

## Security Principles

## Monitoring & Alerting

## Region Outage Scenario

![Region Outage Scenario](.document360/assets/region-outage.png)

In the event of a region outage (e.g., Region 1 becomes unavailable), the architecture ensures:

- **Automatic failover**: Azure Front Door reroutes traffic to the standby region (Region 2) with minimal downtime.
- **Multi-region Redis Cluster**: Redis data is synchronized across regions, ensuring cache consistency and availability.
- **Database Replication**: The primary database supports multi-region replication, so data remains accessible.
- **CI/CD Rollouts**: Pipelines can redeploy applications and infrastructure to the standby region as needed.
- **Observability**: Monitoring and alerting continue to function, providing visibility into failover events and system health.
- **Security**: All security controls and policies remain enforced in the standby region.

This design provides high availability, business continuity, and resilience against regional failures.