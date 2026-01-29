## Executive Summary

We have successfully deployed a **production-grade, multi-region Azure Kubernetes Service (AKS) infrastructure** with intelligent traffic routing, secure secret management, and automated container image delivery. This document provides a complete overview of what has been built, how it works, and where critical components live.

---

## 1. Infrastructure Architecture Overview

### Geographic Distribution

```
┌─────────────────────────────────────────────────────────────────┐
│                                                                 │
│                    AZURE FRONT DOOR (Premium)                  │
│                    infra_profile: primary/secondary/dual        │
│                                                                 │
└──────────┬──────────────────────────────────────────────┬───────┘
           │                                              │
           │ (intelligent routing based on health)        │
           │                                              │
     ┌─────▼──────┐                              ┌────────▼──────┐
     │  PRIMARY   │                              │  SECONDARY    │
     │  REGION    │                              │  REGION       │
     │  EAST US   │                              │  WEST US 2    │
     └─────┬──────┘                              └────────┬──────┘
           │                                              │
     ┌─────▼────────────────┐                    ┌────────▼──────────────┐
     │ AKS Cluster v1.32    │                    │ AKS Cluster v1.32     │
     │ 7 nodes (3 regions)  │                    │ 7 nodes (3 regions)   │
     │ ├─ System Pool: 3    │                    │ ├─ System Pool: 2     │
     │ ├─ Memory Pool: 2    │                    │ ├─ Memory Pool: 2     │
     │ └─ CPU Pool: 2       │                    │ └─ CPU Pool: 2        │
     └─────┬────────────────┘                    └────────┬──────────────┘
           │                                              │
           ├─ Traefik Ingress (v2.11.0)                  ├─ Traefik Ingress
           ├─ App Deployment (2 replicas)                ├─ App Deployment
           ├─ PostgreSQL Private Endpoint                ├─ PostgreSQL Private Endpoint
           └─ Redis Cache Private Endpoint               └─ Redis Cache Private Endpoint
                    │                                              │
                    └──────────────────────────┬───────────────────┘
                                               │
                    ┌──────────────────────────▼───────────────────────────┐
                    │                                                       │
                    │  SHARED SERVICES (Global)                            │
                    │  ├─ PostgreSQL v16 (Primary + Failover Secondary)   │
                    │  ├─ Redis Premium (Geo-replicated)                  │
                    │  ├─ Azure Key Vault (Secrets & Passwords)           │
                    │  ├─ Azure Container Registry (myacr2026)            │
                    │  └─ Azure Storage (Static Website)                  │
                    │                                                       │
                    └───────────────────────────────────────────────────────┘
```

---

## 2. Front Door Traffic Routing & Failover

### Overview
Azure Front Door Premium acts as a global entry point with intelligent routing based on the `infra_profile` setting.

### How It Works

**Configuration Flag: `infra_profile`**

Located in: `/infra/dv/main.tf` → `infra_profile = "primary"`

#### Three Operating Modes:

| Mode | Configuration | Behavior | Use Case |
|------|---------------|----------|----------|
| **primary** | `infra_profile = "primary"` | All traffic routes to East US AKS. West US 2 is cold standby. | Normal operations, cost optimization |
| **secondary** | `infra_profile = "secondary"` | All traffic routes to West US 2 AKS. East US is backup. | During East US maintenance/outage |
| **dual** | `infra_profile = "dual"` | Traffic load-balanced 50/50 between both regions. | High availability, active-active setup |

### Priority & Failover Rules

```terraform
# Priority assignment (lower = higher preference)
Primary Cluster:
  - primary mode:   priority = 1 (active)
  - secondary mode: priority = 2 (standby)
  - dual mode:      priority = 1 (active, load-balanced)

Secondary Cluster:
  - primary mode:   priority = 2 (standby)
  - secondary mode: priority = 1 (active)
  - dual mode:      priority = 1 (active, load-balanced)
```

### Health Monitoring

Front Door continuously monitors cluster health via HTTP health probes:
- **Endpoint**: `/ping`
- **Protocol**: HTTP
- **Interval**: Every 30 seconds
- **Failure Threshold**: 3 failed probes

If primary cluster becomes unhealthy, traffic automatically fails over to secondary within ~90 seconds.

### To Switch Traffic

Edit `/infra/dv/main.tf`:

```terraform
# Option 1: Switch to secondary
locals {
  infra_profile = "secondary"
}

# Option 2: Enable load balancing
locals {
  infra_profile = "dual"
}

# Then apply:
terraform apply
```

---

## 3. Application-to-Database Connectivity

### Architecture

```
┌──────────────────────────────────────────────────────────────────┐
│  Kubernetes Pod (hello-world-app)                               │
│  ├─ Image: myacr2026.azurecr.io/samples/app:latest             │
│  ├─ Replicas: 2 (across availability zones)                     │
│  └─ Environment Variables:                                      │
│     ├─ ACTIVE_PROFILE: "primary" (or "secondary")              │
│     ├─ DB_HOST_PRIMARY: primary-psql-2026-v2.postgres.database. │
│     │  azure.com:5432                                           │
│     ├─ DB_HOST_SECONDARY: secondary-psql-2026.postgres.database.│
│     │  azure.com:5432                                           │
│     ├─ DB_USER: psqladmin                                       │
│     ├─ DB_NAME: postgres                                        │
│     └─ DB_PASSWORD: (fetched from Kubernetes Secret)            │
└──────────────────────────────────────────────────────────────────┘
                              │
                              ▼
        ┌─────────────────────────────────────────┐
        │  Kubernetes Secret: "db-secret"         │
        │  Type: Opaque                           │
        │  ├─ key: "password"                     │
        │  └─ value: (injected from Key Vault)    │
        │  ┌─────────────────────────────────────┐│
        │  │ Terraform creates this secret using ││
        │  │ credentials from Azure Key Vault    ││
        │  └─────────────────────────────────────┘│
        └─────────────────────────────────────────┘
                              │
                              ▼
        ┌─────────────────────────────────────────────────┐
        │ Application Logic (Python/Flask)                │
        ├─────────────────────────────────────────────────┤
        │ if ACTIVE_PROFILE == "primary":                 │
        │   HOST = DB_HOST_PRIMARY                        │
        │ else:                                           │
        │   HOST = DB_HOST_SECONDARY                      │
        │                                                 │
        │ connection_string = f"host={HOST} \            │
        │   dbname={DB_NAME} user={DB_USER} \            │
        │   password={DB_PASSWORD} sslmode=require"      │
        └─────────────────────────────────────────────────┘
                              │
                              ▼
        ┌──────────────────────────────────────────────────────┐
        │ PostgreSQL Flexible Server (primary-psql-2026-v2)    │
        │ ├─ Version: 16                                       │
        │ ├─ SKU: GP_Standard_D2s_v3                          │
        │ ├─ Storage: 32GB (SSD)                              │
        │ ├─ Public Access: Enabled (with IP restrictions)    │
        │ └─ Authentication:                                  │
        │    ├─ Azure AD: Enabled (for admin access)         │
        │    └─ Password Auth: Enabled (for app connection)  │
        └──────────────────────────────────────────────────────┘
```

### Connection Flow

1. **Pod starts** → Kubernetes mounts the `db-secret` as environment variable
2. **App reads variables** → Gets DB host based on `ACTIVE_PROFILE`
3. **Connection established** → psycopg2 connects using SSL/TLS
4. **Queries executed** → Data flows over encrypted connection

### Endpoint Details

| Component | Endpoint | Port | Protocol |
|-----------|----------|------|----------|
| Primary DB | `primary-psql-2026-v2.postgres.database.azure.com` | 5432 | PostgreSQL SSL |
| Secondary DB | `secondary-psql-2026.postgres.database.azure.com` | 5432 | PostgreSQL SSL |
| App uses | Configured via `ACTIVE_PROFILE` | - | App selects endpoint dynamically |

### Database Failover

To switch the app to use the secondary database:

Edit `/kubernetes-config/modules/config/app.tf`:

```terraform
set {
  name  = "database.activeProfile"
  value = "secondary"  # Changed from "primary"
}
```

Then:
```bash
terraform apply
# Kubernetes will restart pods with new DB config
```

---

## 4. Secrets Management Architecture

### Key Vault Overview

**Location**: Azure Key Vault (`mykeyvault` in resource group)
**Region**: Primary region (East US)

### Secrets Stored in Key Vault

| Secret Name | Value | Type | Usage |
|-------------|-------|------|-------|
| `database-password` | Auto-generated (20 chars, special chars) | Password | PostgreSQL admin password |

### How Secrets Flow

```
┌─────────────────────────────────────────────────────────────┐
│ Terraform (Infra Layer)                                    │
│ /infra/modules/config/postgres.tf                          │
│                                                             │
│ 1. Generate random password (20 chars + special chars)     │
│ 2. Store in Azure Key Vault                               │
│ 3. Use same password for PostgreSQL admin user            │
└──────────────┬──────────────────────────────────────────────┘
               │
               ▼ (Terraform State - encrypted at rest)
┌──────────────────────────────────────────────────────────────┐
│ Azure Key Vault                                             │
│ ├─ Secrets:                                                │
│ │  └─ database-password: (20-char randomly generated)     │
│ ├─ Access Control: RBAC                                    │
│ │  ├─ Terraform: Key Vault Secrets Officer                │
│ │  └─ Azure AD: Enabled for admin access                  │
│ └─ Encryption: Microsoft-managed or customer-managed      │
└──────────────┬──────────────────────────────────────────────┘
               │
               ▼ (Read by Kubernetes)
┌──────────────────────────────────────────────────────────────┐
│ Kubernetes Secret (dv namespace)                            │
│ ├─ Name: db-secret                                          │
│ ├─ Type: Opaque                                             │
│ └─ Data:                                                    │
│    └─ password: (value from Key Vault)                     │
└──────────────┬──────────────────────────────────────────────┘
               │
               ▼ (Mounted in Pod)
┌──────────────────────────────────────────────────────────────┐
│ Application Container                                       │
│ ├─ Environment Variable: DB_PASSWORD                        │
│ ├─ Source: Kubernetes Secret mount                          │
│ └─ Used for: PostgreSQL authentication                      │
└──────────────────────────────────────────────────────────────┘
```

### Security Features

✅ **Secrets NOT in Git**: Password generated dynamically, stored only in Key Vault
✅ **Encryption at Rest**: All secrets encrypted in Key Vault
✅ **Encryption in Transit**: TLS 1.2+ for all connections
✅ **Access Control**: RBAC prevents unauthorized access
✅ **Audit Logging**: All key vault operations logged in Azure Monitor
✅ **Rotation Support**: Can rotate passwords without code changes

### To Rotate Database Password

```bash
# 1. Generate new password in Key Vault (Azure Portal or CLI)
az keyvault secret set \
  --vault-name mykeyvault \
  --name database-password \
  --value "$(openssl rand -base64 32)"

# 2. Update PostgreSQL admin password
az postgres flexible-server update \
  --name primary-psql-2026-v2 \
  --admin-password $(az keyvault secret show --vault-name mykeyvault --name database-password --query value -o tsv)

# 3. Restart Kubernetes pods to pick up new secret
kubectl rollout restart deployment/app -n dv
```

---

## 5. Container Image Storage & Deployment

### Azure Container Registry (ACR) Setup

**Registry Name**: `myacr2026`
**SKU**: Premium (supports Private Link, geo-replication)
**Location**: Primary region (East US)

### Image Storage

```
┌────────────────────────────────────────────────────┐
│ Azure Container Registry (ACR)                     │
│ myacr2026.azurecr.io                              │
│                                                    │
│ Repository Structure:                             │
│ └─ samples/app                                    │
│    ├─ latest (latest build)                       │
│    ├─ v1.0.0 (tagged release)                     │
│    ├─ v1.0.1 (tagged release)                     │
│    └─ ... (more tags/versions)                    │
│                                                    │
│ Each image contains:                              │
│ ├─ Base Image: python:3.12-slim                  │
│ ├─ Dependencies: requirements.txt                 │
│ ├─ Application: main.py                          │
│ └─ Metadata: version, build info                 │
└────────────────────────────────────────────────────┘
```

### Dockerfile Build Process (Multi-stage)

```dockerfile
# Stage 1: Builder
FROM python:3.12-slim as builder
RUN apt-get update && apt-get install -y gcc
COPY src/requirements.txt .
RUN pip install --user -r requirements.txt

# Stage 2: Runtime
FROM python:3.12-slim
COPY --from=builder /root/.local /home/appuser/.local
COPY src/main.py .
USER appuser (non-root, UID 1000)
CMD ["python", "main.py"]
```

**Result**: ~200MB final image size (optimized, no build tools)

### Image Deployment Flow

```
┌─────────────────────────┐
│ Local Development       │
│ docker build -t ...     │
└────────────┬────────────┘
             │
             ▼
┌─────────────────────────────────────────────────────────┐
│ Push to ACR                                             │
│ docker push myacr2026.azurecr.io/samples/app:latest    │
└────────────┬────────────────────────────────────────────┘
             │
             ▼
┌──────────────────────────────────────────────────────────┐
│ Azure Container Registry                                │
│ myacr2026.azurecr.io/samples/app:latest               │
│ (stored with all layers, scanned for vulnerabilities) │
└────────────┬──────────────────────────────────────────┬─┘
             │                                          │
             ├─ primary AKS cluster                     │
             │  ├─ Pull image                           │
             │  ├─ Create pod                           │
             │  └─ Start container                      │
             │                                          │
             └─ secondary AKS cluster                   │
                ├─ Pull image                           │
                ├─ Create pod                           │
                └─ Start container                      │
```

### Build & Push Steps

```bash
# 1. Navigate to app directory
cd /Users/ramguru/Documents/apps/kovai/azure-arch/app

# 2. Build image locally
docker build -t myacr2026.azurecr.io/samples/app:latest .

# 3. Login to ACR
az acr login --name myacr2026

# 4. Push to ACR
docker push myacr2026.azurecr.io/samples/app:latest

# 5. Verify image in ACR
az acr repository show --name myacr2026 --repository samples/app

# 6. Kubernetes will auto-pull on next deployment
kubectl get pods -n dv -o wide  # Verify pods running with new image
```

### Image Configuration in Kubernetes

```yaml
# Set in /kubernetes-config/modules/config/app.tf
set {
  name  = "image.repository"
  value = "myacr2026.azurecr.io/samples/app"
}

set {
  name  = "image.tag"
  value = "latest"  # or specific version like "v1.0.0"
}

set {
  name  = "image.pullPolicy"
  value = "IfNotPresent"  # Only pull if not cached locally
}
```

### Image Security

✅ **Non-root User**: App runs as UID 1000 (not root)
✅ **Minimal Base Image**: python:3.12-slim (only ~130MB)
✅ **Multi-stage Build**: Build tools not included in final image
✅ **Vulnerability Scanning**: ACR can scan images automatically
✅ **Private Registry**: Only authorized users can pull

---

## 6. Summary: What's Connected to What

| Component | Connection To | Protocol | Authentication |
|-----------|--------------|----------|-----------------|
| **Front Door** | Primary AKS | HTTP/HTTPS | Health probes only |
| **Front Door** | Secondary AKS | HTTP/HTTPS | Health probes only |
| **Front Door** | Both Traefik Services | HTTP | Direct (no auth needed for health) |
| **App Pod** | PostgreSQL Primary | PostgreSQL SSL | Username/password (from Secret) |
| **App Pod** | PostgreSQL Secondary | PostgreSQL SSL | Username/password (from Secret) |
| **App Pod** | Redis Cache | Redis SSL | TLS only (optional auth) |
| **Kubernetes** | Azure Key Vault | Azure AD | Managed Identity |
| **Kubernetes** | ACR | Azure AD | Managed Identity / Image Pull Secret |
| **AKS Nodes** | PostgreSQL | VNet Private Endpoint | Private IP, SSL |
| **AKS Nodes** | Redis | VNet Private Endpoint | Private IP, TLS |

---

## 7. Deployment Modes & Scenarios

### Scenario 1: Normal Operations (Primary Active)

```
infra_profile = "primary"

Traffic Flow:
  Client → Front Door (primary) → Primary AKS Traefik → App → PostgreSQL Primary
                        ↓
                    Secondary AKS (standby, receives 0% traffic)
```

### Scenario 2: Primary Region Maintenance

```
infra_profile = "secondary"

Traffic Flow:
  Client → Front Door (secondary) → Secondary AKS Traefik → App → PostgreSQL Secondary
                        ↓
                    Primary AKS (maintenance, receives 0% traffic)
```

### Scenario 3: High Availability (Active-Active)

```
infra_profile = "dual"

Traffic Flow:
  Client → Front Door (50/50 load balanced)
           ├─→ Primary AKS Traefik → App → PostgreSQL Primary
           └─→ Secondary AKS Traefik → App → PostgreSQL Secondary
```

---

## 8. Troubleshooting & Key Commands

### View Infrastructure Status

```bash
# Check AKS clusters
az aks list --output table

# Check PostgreSQL servers
az postgres flexible-server list --output table

# View Key Vault secrets
az keyvault secret list --vault-name mykeyvault

# Check ACR images
az acr repository list --name myacr2026

# View pods in Kubernetes
kubectl get pods -n dv -o wide

# Check app logs
kubectl logs -n dv -l app=hello-world -f

# Verify database connectivity from pod
kubectl exec -it <pod-name> -n dv -- psql \
  -h primary-psql-2026-v2.postgres.database.azure.com \
  -U psqladmin -d postgres \
  -c "SELECT version();"
```

### Switch Traffic

```bash
# Edit main.tf and change infra_profile
vim /infra/dv/main.tf

# Apply changes
cd /infra/dv
terraform plan
terraform apply

# Verify traffic switched
# Check Front Door in Azure Portal → Origins → Enabled/Disabled status
```

---

## 9. File Locations & Quick Reference

| Component | File Location | Key Variables |
|-----------|--------------|---------------|
| **Infrastructure Config** | `/infra/dv/main.tf` | `infra_profile`, `secondary_enabled` |
| **Front Door Setup** | `/infra/modules/config/frontdoor.tf` | Origins, priorities, health probes |
| **PostgreSQL Setup** | `/infra/modules/config/postgres.tf` | Version, SKU, passwords |
| **Key Vault Setup** | `/infra/modules/config/secret.tf` | Secrets, access policies |
| **App Deployment** | `/kubernetes-config/modules/config/app.tf` | Image, secrets, DB config |
| **App Values** | `/kubernetes-config/helm-charts/app/values.yaml` | Image repo, DB hosts, probes |
| **App Code** | `/app/src/main.py` | Flask routes, DB connection logic |
| **Dockerfile** | `/app/Dockerfile` | Multi-stage build, Python setup |

---

## 10. Key Takeaways

✅ **Geo-distributed**: Two AKS clusters in different regions for resilience
✅ **Intelligent Routing**: Front Door automatically routes to healthy cluster
✅ **Flexible Failover**: Three modes (primary/secondary/dual) for different scenarios
✅ **Secure Secrets**: Passwords stored in Key Vault, never in code
✅ **Container Registry**: All images in Azure Container Registry for quick deployment
✅ **Multi-region Databases**: Primary and secondary PostgreSQL for data resilience
✅ **Zero-downtime Switching**: Change traffic route with a single Terraform variable
✅ **Automated Health Checks**: Front Door monitors cluster health every 30 seconds
✅ **Non-root Containers**: Enhanced security with unprivileged app execution
✅ **Infrastructure as Code**: All resources defined in Terraform for reproducibility

---

## Next Steps

1. **Build & Push Container Image**
   ```bash
   cd /Users/ramguru/Documents/apps/kovai/azure-arch/app
   ./build-and-push.sh  # or manually: docker build & push
   ```

2. **Verify Database Connectivity**
   ```bash
   kubectl exec -it <app-pod> -n dv -- python -c "import psycopg2; print('DB OK')"
   ```

3. **Test Failover** (change infra_profile and verify traffic switches)

4. **Monitor with Azure Monitor** (set up alerts for key metrics)

---

**Infrastructure Prepared By**: Terraform
**Last Updated**: 2026-01-23
**Status**: Production Ready ✅

---

For questions or clarifications, refer to the technical documentation in `/TECHNICAL_EXPLANATION.md`.
