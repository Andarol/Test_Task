variable "project_id" {
  type        = string
  description = "Google Cloud project ID."
}

variable "name" {
  type        = string
  description = "Cluster name."
}

variable "region" {
  type        = string
  description = "GKE control-plane region."
}

variable "network_id" {
  type        = string
  description = "VPC network ID."
}

variable "subnetwork_id" {
  type        = string
  description = "GKE subnetwork ID."
}

variable "pod_range_name" {
  type        = string
  description = "Secondary range name for pods."
}

variable "service_range_name" {
  type        = string
  description = "Secondary range name for Services."
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
  description = "Networks allowed to reach the private control-plane endpoint."
}

variable "node_network_tag" {
  type        = string
  description = "Network tag for application nodes."
}

variable "machine_type" {
  type        = string
  description = "Application node machine type."
  default     = "e2-standard-4"
}

variable "node_locations" {
  type        = list(string)
  description = "Zones used by the regional GKE cluster and application node pool."

  validation {
    condition     = length(var.node_locations) == 3
    error_message = "The application node pool must use exactly three zones."
  }
}

variable "min_nodes_per_zone" {
  type        = number
  description = "Minimum application nodes per zone."
  default     = 1
}

variable "max_nodes_per_zone" {
  type        = number
  description = "Maximum application nodes per zone."
  default     = 3
}

variable "labels" {
  type        = map(string)
  description = "Resource labels."
  default     = {}
}
