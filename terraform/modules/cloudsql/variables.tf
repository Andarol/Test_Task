variable "project_id" {
  type = string
}

variable "instance_name" {
  type = string
}

variable "region" {
  type = string
}

variable "network" {
  type = string
}

variable "database_name" {
  type    = string
  default = "orders"
}

variable "tier" {
  type    = string
  default = "db-custom-2-7680"
}

variable "backup_retained_count" {
  type    = number
  default = 7
}
