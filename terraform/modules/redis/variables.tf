variable "project_id" {
  type        = string
  description = "Google Cloud project ID."
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
