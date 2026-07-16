variable "project_id" {
  type        = string
  description = "Google Cloud project ID."
}

variable "name" {
  type        = string
  description = "Cloud SQL instance name."
}

variable "region" {
  type        = string
  description = "Cloud SQL region."
}

variable "network_id" {
  type        = string
  description = "VPC ID used for private IP."
}

variable "allocated_ip_range" {
  type        = string
  description = "Private Service Access range dedicated to this environment."
}

variable "database_name" {
  type        = string
  description = "Application database name."
  default     = "orders"
}

variable "database_user" {
  type        = string
  description = "Application database user."
  default     = "order_service"
}

variable "database_tier" {
  type        = string
  description = "Cloud SQL machine tier."
  default     = "db-custom-2-7680"
}

variable "disk_size_gb" {
  type        = number
  description = "Initial SSD disk size."
  default     = 100
}

variable "backup_retention_count" {
  type        = number
  description = "Number of automated backups retained."
  default     = 30
}

variable "labels" {
  type        = map(string)
  description = "User labels for the Cloud SQL instance."
  default     = {}
}
