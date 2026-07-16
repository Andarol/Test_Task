variable "project_id" {
  type        = string
  description = "Google Cloud project ID."
}

variable "name" {
  type        = string
  description = "Resource name prefix."
}

variable "region" {
  type        = string
  description = "Region for regional networking resources."
}

variable "network_id" {
  type        = string
  description = "Shared foundation VPC ID."
}

variable "network_name" {
  type        = string
  description = "Shared foundation VPC name."
}

variable "node_cidr" {
  type        = string
  description = "Primary IPv4 range for GKE nodes."
}

variable "pod_cidr" {
  type        = string
  description = "Secondary IPv4 range for GKE pods."
}

variable "service_cidr" {
  type        = string
  description = "Secondary IPv4 range for Kubernetes Services."
}

variable "database_service_cidr" {
  type        = string
  description = "Shared foundation Private Service Access range used by Cloud SQL."
}

variable "master_cidr" {
  type        = string
  description = "GKE control-plane /28 range."
}

variable "trusted_ingress_cidrs" {
  type        = list(string)
  description = "Management and VPN CIDRs allowed to reach GKE nodes."
  default     = []
}
