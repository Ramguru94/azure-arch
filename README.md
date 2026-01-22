# Azure Architecture

This repository contains the architecture documentation for a cloud-native Azure-based application deployment.

## Overview

The architecture implements a multi-region, highly available, and secure cloud infrastructure leveraging Azure Kubernetes Service (AKS), Cloudflare for edge security, and various Azure and cloud-agnostic services.


## Architecture Diagram

![Azure Architecture](images/azure-arch.png)

For a Mermaid-based interactive version:
![Azure Architecture Mermaid](images/azure-arch-mermaid.png)

## Region Outage Scenario

![Region Outage Scenario](images/region-outage.png)

This diagram illustrates how the architecture handles a region outage:

- **Automatic Failover:** If the primary region (Region 1) experiences an outage, Azure Front Door automatically routes traffic to the standby region (Region 2).
- **Multi-Region Redis Cluster:** The Redis cluster is deployed across both regions, ensuring cache availability and data consistency even during a regional failure.
- **Database Replication:** The primary database is replicated across regions, so applications in the standby region can continue to operate with up-to-date data.
- **Stateless Applications:** Application pods are stateless and can be started in any region, enabling seamless failover.
- **CI/CD Rollouts:** Pipelines can deploy to either region, supporting rapid recovery and minimal downtime.

This approach ensures high availability, business continuity, and resilience against regional outages.

## Key Components

### Edge & Zero Trust
- **Users**: End users accessing the application
- **Cloudflare**: Provides DNS, Web Application Firewall (WAF), and DDoS protection
- **Azure Front Door**: Global traffic management and load balancing

### CI/CD & Governance
- **Helm Template Repo**: Repository containing golden Helm charts
- **Application Repo**: Source code repository for the application
- **Infra Repo**: Infrastructure as Code using Terraform
- **Build Pipeline**: Creates container images and Helm packages with SAST and DAST scanning
- **Deploy Pipeline**: Applies Terraform configurations for infrastructure deployment and rolls out application Helm charts

### Container Registry
- **Azure Container Registry (ACR)**: Stores trusted container images
- **Helm Chart Registry**: Repository for Helm charts

### Multi-Region Deployment
- **Region 1 (Active)**: Primary region with full AKS cluster
- **Region 2 (Standby)**: Secondary region for failover and disaster recovery

Each region includes:
- **AKS Cluster**: Multi-Availability Zone Kubernetes clusters
- **Traefik Ingress**: Ingress controller with middleware and Open Policy Agent (OPA) integration
- **Application Pods**: Containerized application workloads
- **Horizontal Pod Autoscaler (HPA) + KEDA**: Auto-scaling based on metrics and events

### Data & Cache Layer
- **Primary Database**: Multi-region replicated database
- **Redis Cluster**: Multi-region Redis cluster for global and regional caching
- **Object Storage**: For static assets and file storage

### Observability
- **Prometheus**: Metrics collection and monitoring
- **Grafana**: Visualization and dashboards
- **Loki**: Log aggregation
- **Alertmanager**: Alert management and notifications
- **SLO & Error Budget**: Service Level Objectives and error tracking

### Security
- **Vault**: Secrets management
- **Workload Identity**: Secure identity for workloads
- **OPA Policies**: Policy enforcement at ingress level

## Traffic Flow
1. User requests enter through Cloudflare for initial security filtering
2. Traffic is routed via Azure Front Door for global load balancing
3. Requests are processed by Traefik ingress controllers with OPA policy enforcement
4. Applications access data layer services (DB, Redis, Object Storage)
5. Observability stack monitors all components
6. Security services ensure proper authentication and authorization

## Deployment Strategy
- **Active-Standby**: Region 1 handles primary traffic, Region 2 ready for failover
- **CI/CD Pipelines**: Automated build and deployment using Azure DevOps/GitHub Actions
- **Infrastructure as Code**: Terraform manages all cloud resources
- **GitOps**: Helm charts and Kubernetes manifests stored in repositories

## Security Principles
- **Zero Trust**: Every request is authenticated and authorized
- **Defense in Depth**: Multiple security layers from edge to application
- **Least Privilege**: Workload identity and minimal access policies
- **Encryption**: Data encrypted at rest and in transit

## Monitoring & Alerting
- Centralized logging with Loki
- Metrics collection via Prometheus
- Visualization through Grafana dashboards
- Automated alerting for incidents
- SLO tracking for service reliability