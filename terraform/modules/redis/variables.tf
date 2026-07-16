variable "project_id" {
  type        = string
  description = "Google Cloud project ID."
}

variable "project_number" {
  type        = string
  description = "Google Cloud numeric project ID used for GKE Workload Identity principals."
}

variable "name" {
  type        = string
  description = "Memorystore instance name."
}

variable "region" {
  type        = string
  description = "Region containing the shared Redis instance."
}

variable "network_id" {
  type        = string
  description = "Shared VPC network self link."
}

variable "reserved_ip_range" {
  type        = string
  description = "Private Service Access allocated range name."
}

variable "memory_size_gb" {
  type        = number
  description = "Redis capacity in GiB."
  default     = 1

  validation {
    condition     = var.memory_size_gb >= 1
    error_message = "memory_size_gb must be at least 1."
  }
}

variable "labels" {
  type        = map(string)
  description = "User labels for the Redis instance and secrets."
  default     = {}
}

variable "kubernetes_namespace" {
  type        = string
  description = "Namespace of the workload allowed to read Redis secrets."
  default     = "order-service"
}

variable "kubernetes_service_account" {
  type        = string
  description = "Kubernetes ServiceAccount allowed to read Redis secrets."
  default     = "order-service"
}
