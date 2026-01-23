variable "environment" {
  type        = string
  description = "Deployment environment (dev, staging, prod)"
}

variable "project" {
  type        = string
  description = "Project name"
}

variable "cluster_endpoint" {
  type        = string
  description = "Kubernetes cluster endpoint"
}

variable "cluster_ca_certificate" {
  type        = string
  description = "Kubernetes cluster CA certificate (base64 encoded)"
  sensitive   = true
}

variable "client_certificate" {
  type        = string
  description = "Kubernetes client certificate (base64 encoded)"
  sensitive   = true
}

variable "client_key" {
  type        = string
  description = "Kubernetes client key (base64 encoded)"
  sensitive   = true
}

variable "traefik_replicas" {
  type        = number
  description = "Number of Traefik replicas"
  default     = 3
}

variable "traefik_image_tag" {
  type        = string
  description = "Traefik image tag"
  default     = "v2.11.0"
}

variable "traefik_service_type" {
  type        = string
  description = "Traefik service type (LoadBalancer, ClusterIP)"
  default     = "LoadBalancer"
}

variable "traefik_cpu_request" {
  type        = string
  description = "CPU request for Traefik"
  default     = "100m"
}

variable "traefik_memory_request" {
  type        = string
  description = "Memory request for Traefik"
  default     = "256Mi"
}

variable "traefik_cpu_limit" {
  type        = string
  description = "CPU limit for Traefik"
  default     = "500m"
}

variable "traefik_memory_limit" {
  type        = string
  description = "Memory limit for Traefik"
  default     = "512Mi"
}

variable "log_level" {
  type        = string
  description = "Log level (DEBUG, INFO, WARN, ERROR)"
  default     = "INFO"
}

variable "tags" {
  type        = map(string)
  description = "Common tags for all resources"
  default     = {}
}

variable "aks_private_link_service_name" {
  type        = string
  description = "Name for the AKS Private Link Service"
}

variable "traefik_internal_lb_ip" {
  type        = string
  description = "Internal Load Balancer IP for Traefik"
}

variable "traefik_lb_ip" {
  type        = string
  description = "Load Balancer IP for Traefik"
}
variable "app_profile" {
  type        = string
  description = "Application profile (primary, secondary)"
}

variable "azurerm_resource_group" {
  type        = string
  description = "Azure Resource Group name"
}
