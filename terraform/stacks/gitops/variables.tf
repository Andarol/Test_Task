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

variable "gitops_values_file" {
  type        = string
  description = "Repository-relative values file consumed directly by the Argo CD root application."
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
