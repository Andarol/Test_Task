variable "project_id" {
  type        = string
  description = "Google Cloud project ID."
}

variable "region" {
  type        = string
  description = "Region represented by this stack instance."
}

variable "environment" {
  type        = string
  description = "Deployment environment."
}

variable "network_id" {
  type        = string
  description = "Shared foundation VPC ID."
}

variable "network_name" {
  type        = string
  description = "Shared foundation VPC name."
}

variable "image_repository" {
  type        = string
  description = "Shared Artifact Registry image repository without tag."
}

variable "node_cidr" {
  type        = string
  description = "Primary range for regional GKE nodes."
}

variable "pod_cidr" {
  type        = string
  description = "Secondary range for regional GKE pods."
}

variable "service_cidr" {
  type        = string
  description = "Secondary range for regional Kubernetes Services."
}

variable "database_service_cidr" {
  type        = string
  description = "Shared foundation Private Service Access range containing Cloud SQL."
}

variable "cloudsql_private_ip" {
  type        = string
  description = "Private IP of the single shared Cloud SQL primary."
}

variable "database_password_secret_id" {
  type        = string
  description = "Secret ID for the single shared database password."
}

variable "redis_host" {
  type        = string
  description = "Private endpoint of the one shared Redis cache."
}

variable "redis_port" {
  type        = number
  description = "TLS port of the shared Redis cache."
}

variable "redis_auth_secret_id" {
  type        = string
  description = "Secret Manager secret containing Redis AUTH."
}

variable "redis_ca_secret_id" {
  type        = string
  description = "Secret Manager secret containing the Redis TLS CA."
}

variable "master_cidr" {
  type        = string
  description = "Private GKE control-plane /28."
}

variable "master_authorized_networks" {
  type = list(object({
    cidr_block   = string
    display_name = string
  }))
  description = "Networks allowed to reach the private Kubernetes API endpoint."
}

variable "trusted_ingress_cidrs" {
  type        = list(string)
  description = "Management and VPN CIDRs allowed to reach GKE nodes."
}

variable "gke_machine_type" {
  type        = string
  description = "GKE application node machine type."
  default     = "e2-standard-4"
}

variable "gke_node_locations" {
  type        = list(string)
  description = "Zones in the region used by the GKE control plane and node pool."
}

variable "gke_min_nodes_per_zone" {
  type        = number
  description = "Minimum GKE application nodes in each zone."
  default     = 1
}

variable "gke_max_nodes_per_zone" {
  type        = number
  description = "Maximum GKE application nodes in each zone."
  default     = 3
}
