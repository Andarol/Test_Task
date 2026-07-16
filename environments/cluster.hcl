locals {
  environment = read_terragrunt_config(find_in_parent_folders("environment.hcl"))
  region      = basename(dirname(path_relative_to_include()))
  regional    = local.environment.locals.regions[local.region]
  project_id  = local.environment.locals.project_id
}

remote_state {
  backend = "gcs"

  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }

  config = {
    project              = local.project_id
    bucket               = "${local.project_id}-order-service-tfstate"
    # Preserve the existing state address while exposing an explicit cluster directory.
    prefix               = "${local.environment.locals.environment}/${local.region}/terraform.tfstate"
    location             = "EU"
    skip_bucket_creation = true
  }
}

terraform {
  source = "../../../../terraform//stacks/cluster"
}

dependency "foundation" {
  config_path = "../../foundation"
  mock_outputs = {
    network_id                  = "projects/mock/global/networks/order-mock-vpc"
    network_name                = "order-mock-vpc"
    database_password_secret_id = "order-mock-postgres-password"
    database_service_cidr       = "10.90.0.0/16"
    redis_auth_secret_id        = "order-mock-redis-auth"
    redis_ca_secret_id          = "order-mock-redis-ca"
    management_subnet_cidr      = "10.0.0.0/24"
    vpn_client_cidr             = "10.250.0.0/24"
  }
  mock_outputs_allowed_terraform_commands = ["validate"]
}

inputs = merge(local.environment.locals.common_inputs, {
  region                      = local.region
  network_id                  = dependency.foundation.outputs.network_id
  network_name                = dependency.foundation.outputs.network_name
  node_cidr                   = local.regional.node_cidr
  pod_cidr                    = local.regional.pod_cidr
  service_cidr                = local.regional.service_cidr
  database_service_cidr       = dependency.foundation.outputs.database_service_cidr
  database_password_secret_id = dependency.foundation.outputs.database_password_secret_id
  redis_auth_secret_id        = dependency.foundation.outputs.redis_auth_secret_id
  redis_ca_secret_id          = dependency.foundation.outputs.redis_ca_secret_id
  master_cidr                 = local.regional.master_cidr
  gke_machine_type            = local.regional.gke_machine_type
  gke_node_locations          = local.regional.zones
  gke_min_nodes_per_zone      = local.regional.min_nodes_per_zone
  gke_max_nodes_per_zone      = local.regional.max_nodes_per_zone
  trusted_ingress_cidrs = [
    dependency.foundation.outputs.management_subnet_cidr,
    dependency.foundation.outputs.vpn_client_cidr,
  ]
  master_authorized_networks = [
    {
      cidr_block   = dependency.foundation.outputs.management_subnet_cidr
      display_name = "management subnet"
    },
    {
      cidr_block   = dependency.foundation.outputs.vpn_client_cidr
      display_name = "WireGuard administrator VPN"
    },
  ]
})
