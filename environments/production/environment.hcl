locals {
  environment          = "production"
  network_cidr         = "10.120.0.0/20"
  pods_cidr            = "10.121.0.0/16"
  services_cidr        = "10.122.0.0/20"
  sql_cidr             = "10.123.0.0/24"
  private_service_cidr = "10.124.0.0/16"
  master_cidr          = "172.16.1.0/28"
}
