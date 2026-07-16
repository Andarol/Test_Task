variable "project_id" {
  type        = string
  description = "Google Cloud project ID."
}

variable "environment" {
  type        = string
  description = "Deployment environment."
}

variable "region" {
  type        = string
  description = "Single GCP region containing the multi-AZ GKE cluster."
}

variable "gke_cluster_name" {
  type        = string
  description = "Regional GKE cluster receiving Rancher and Argo CD."
}

variable "gke_cluster_location" {
  type        = string
  description = "Regional GKE cluster location."
}

variable "git_repository_url" {
  type        = string
  description = "Public Git repository watched by Argo CD."
}

variable "git_revision" {
  type        = string
  description = "Git revision watched by Argo CD."
  default     = "main"
}

variable "rancher_hostname" {
  type        = string
  description = "DNS hostname for the Rancher ingress."
}

variable "argocd_hostname" {
  type        = string
  description = "Private hostname used while tunnelling to the Argo CD service."
}

variable "image_repository" {
  type        = string
  description = "Regional Artifact Registry image repository."
}

variable "image_tag" {
  type        = string
  description = "Immutable application image tag deployed by Argo CD."
}

variable "neg_name" {
  type        = string
  description = "Standalone NEG name requested by the application Service."
}

variable "cloudsql_private_ip" {
  type        = string
  description = "Private IP of the shared Cloud SQL primary."
}

variable "database_service_cidr" {
  type        = string
  description = "Private Service Access CIDR containing Cloud SQL."
}

variable "database_password_secret_id" {
  type        = string
  description = "Secret Manager database password secret ID."
}

variable "redis_host" {
  type        = string
  description = "Private Redis endpoint."
}

variable "redis_port" {
  type        = number
  description = "TLS Redis port."
}

variable "redis_auth_secret_id" {
  type        = string
  description = "Secret Manager Redis AUTH secret ID."
}

variable "redis_ca_secret_id" {
  type        = string
  description = "Secret Manager Redis CA secret ID."
}

variable "cert_manager_chart_version" {
  type        = string
  description = "Pinned cert-manager Helm chart version."
  default     = "v1.21.0"
}

variable "rancher_chart_version" {
  type        = string
  description = "Pinned Rancher Helm chart version."
  default     = "2.14.3"
}

variable "argocd_chart_version" {
  type        = string
  description = "Pinned Argo CD Helm chart version."
  default     = "9.5.12"
}
