variable "project_id" {
  type = string
}

variable "name" {
  type = string
}

variable "zone" {
  type = string
}

variable "subnetwork" {
  type = string
}

variable "machine_type" {
  type    = string
  default = "e2-micro"
}

variable "service_account" {
  type    = string
  default = null
}

variable "tags" {
  type    = list(string)
  default = ["bastion"]
}
