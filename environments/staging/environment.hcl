locals {
  environment          = "staging"
  network_cidr         = "10.20.0.0/20"
  pods_cidr            = "10.21.0.0/16"
  services_cidr        = "10.22.0.0/20"
  sql_cidr             = "10.23.0.0/24"
  private_service_cidr = "10.24.0.0/16"
  master_cidr          = "172.16.0.0/28"
}
