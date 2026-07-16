variable "project_id" {
  type = string
}

variable "cluster_name" {
  type = string
}

variable "region" {
  type = string
}

variable "zones" {
  type = list(string)
}

variable "network" {
  type = string
}

variable "subnetwork" {
  type = string
}

variable "pods_range_name" {
  type = string
}

variable "services_range_name" {
  type = string
}

variable "master_cidr" {
  type = string
}

variable "master_authorized_networks" {
  type = list(string)
}

variable "node_machine_type" {
  type    = string
  default = "e2-medium"
}

variable "node_min_count" {
  type    = number
  default = 1
}

variable "node_max_count" {
  type    = number
  default = 4
}

variable "node_service_account" {
  type    = string
  default = null
}

variable "workload_service_account_id" {
  type        = string
  description = "Google service account id used by the order-service Kubernetes service account through Workload Identity."
}
