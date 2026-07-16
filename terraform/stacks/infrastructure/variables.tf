variable "project_id" {
  type = string
}

variable "environment" {
  type = string
}

variable "region" {
  type = string
}

variable "zones" {
  type = list(string)
}

variable "admin_cidrs" {
  type = list(string)
}

variable "network_cidr" {
  type = string
}

variable "gke_pods_cidr" {
  type = string
}

variable "gke_services_cidr" {
  type = string
}

variable "sql_subnet_cidr" {
  type = string
}

variable "private_service_cidr" {
  type = string
}

variable "master_cidr" {
  type = string
}

variable "node_machine_type" {
  type = string
}

variable "node_min_count" {
  type = number
}

variable "node_max_count" {
  type = number
}

variable "sql_tier" {
  type = string
}
