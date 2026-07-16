variable "project_id" {
  type = string
}

variable "environment" {
  type = string
}

variable "region" {
  type = string
}

variable "cluster_name" {
  type = string
}

variable "argocd_chart_version" {
  type    = string
  default = "7.7.16"
}

variable "rancher_chart_version" {
  type    = string
  default = "2.9.0"
}
