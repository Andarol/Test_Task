include "global" {
  path   = find_in_parent_folders("global.hcl")
  expose = true
}

include "environment" {
  path   = find_in_parent_folders("environment.hcl")
  expose = true
}

terraform {
  source = "../../../terraform//stacks/infrastructure"
}

inputs = {
  project_id           = include.global.locals.project_id
  environment          = include.environment.locals.environment
  region               = include.global.locals.region
  zones                = include.global.locals.zones
  admin_cidrs          = [get_env("GKE_ADMIN_CIDR", "10.10.10.10/32")]
  network_cidr         = include.environment.locals.network_cidr
  gke_pods_cidr        = include.environment.locals.pods_cidr
  gke_services_cidr    = include.environment.locals.services_cidr
  sql_subnet_cidr      = include.environment.locals.sql_cidr
  private_service_cidr = include.environment.locals.private_service_cidr
  master_cidr          = include.environment.locals.master_cidr
  node_machine_type    = "e2-medium"
  node_min_count       = 1
  node_max_count       = 4
  sql_tier             = "db-custom-2-7680"
}
