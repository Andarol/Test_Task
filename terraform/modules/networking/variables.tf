variable "project_id" {
  type = string
}

variable "name" {
  type = string
}

variable "region" {
  type = string
}

variable "gke_subnet_cidr" {
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

variable "admin_cidrs" {
  type        = list(string)
  description = "CIDRs allowed to reach the private GKE control plane."
}

variable "labels" {
  type    = map(string)
  default = {}
}
