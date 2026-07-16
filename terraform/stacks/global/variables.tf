variable "project_id" {
  type        = string
  description = "Google Cloud project hosting all regional backends."
}

variable "environment" {
  type        = string
  description = "Deployment environment."
}

variable "regions" {
  type = map(object({
    neg_name        = string
    zones           = list(string)
    capacity_scaler = number
  }))
  description = "Regional standalone NEG names, zones, and relative capacity."

  validation {
    condition = alltrue([
      for region in values(var.regions) : region.capacity_scaler >= 0 && region.capacity_scaler <= 1
    ])
    error_message = "Every capacity_scaler must be between 0 and 1."
  }
}

variable "domain_names" {
  type        = list(string)
  description = "Optional DNS names for a Google-managed TLS certificate."
  default     = []
}

variable "max_rate_per_endpoint" {
  type        = number
  description = "Maximum HTTP requests per second assigned to one pod endpoint."
  default     = 80
}

variable "waf_preview" {
  type        = bool
  description = "If true, Cloud Armor logs matches without enforcing WAF and rate-limit actions."
  default     = false
}

variable "waf_rate_limit_requests_per_min" {
  type        = number
  description = "Allowed requests per source IP per minute before Cloud Armor returns 429."
  default     = 1200

  validation {
    condition     = var.waf_rate_limit_requests_per_min >= 1
    error_message = "waf_rate_limit_requests_per_min must be at least 1."
  }
}
