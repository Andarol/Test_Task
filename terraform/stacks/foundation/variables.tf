variable "project_id" {
  type        = string
  description = "Google Cloud project ID."
}

variable "environment" {
  type        = string
  description = "Deployment environment."
}

variable "network_id" {
  type        = string
  description = "Shared management VPC self-link."
}

variable "network_name" {
  type        = string
  description = "Shared management VPC name."
}

variable "private_service_range_name" {
  type        = string
  description = "Environment-specific PSA range created during runner bootstrap."
}

variable "management_subnet_cidr" {
  type        = string
  description = "CIDR containing the self-hosted runner."
}

variable "vpn_client_cidr" {
  type        = string
  description = "WireGuard client CIDR authorized for private platform access."
}

variable "image_repository" {
  type        = string
  description = "Shared Artifact Registry repository created during runner bootstrap."
}

variable "database_region" {
  type        = string
  description = "Region containing the single writable Cloud SQL primary."
}

variable "database_service_cidr" {
  type        = string
  description = "Shared Private Service Access range for Cloud SQL."
}

variable "database_tier" {
  type        = string
  description = "Cloud SQL machine tier."
  default     = "db-custom-2-7680"
}

variable "database_disk_size_gb" {
  type        = number
  description = "Initial Cloud SQL SSD size."
  default     = 100
}

variable "cache_region" {
  type        = string
  description = "Region containing the single shared HA Redis cache."
}

variable "cache_memory_size_gb" {
  type        = number
  description = "Shared Redis capacity in GiB."
  default     = 1
}
