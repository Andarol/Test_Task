locals {
  environment = read_terragrunt_config(find_in_parent_folders("environment.hcl"))
  region      = basename(path_relative_to_include())
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
    prefix               = "${path_relative_to_include()}/terraform.tfstate"
    location             = "EU"
    skip_bucket_creation = true
  }
}

terraform {
  source = "../../../terraform//stacks/regional"
}

dependency "foundation" {
  config_path = "../foundation"
  mock_outputs = {
    network_id                  = "projects/mock/global/networks/order-mock-vpc"
    network_name                = "order-mock-vpc"
    cloudsql_private_ip         = "10.90.0.10"
    database_password_secret_id = "order-mock-postgres-password"
    database_service_cidr       = "10.90.0.0/16"
    redis_host                  = "10.90.1.10"
    redis_port                  = 6378
    redis_auth_secret_id        = "order-mock-redis-auth"
    redis_ca_secret_id          = "order-mock-redis-ca"
    management_subnet_cidr      = "10.0.0.0/24"
    vpn_client_cidr             = "10.250.0.0/24"
    image_repository            = "europe-west3-docker.pkg.dev/mock/order-service/order-service"
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
  cloudsql_private_ip         = dependency.foundation.outputs.cloudsql_private_ip
  database_password_secret_id = dependency.foundation.outputs.database_password_secret_id
  redis_host                  = dependency.foundation.outputs.redis_host
  redis_port                  = dependency.foundation.outputs.redis_port
  redis_auth_secret_id        = dependency.foundation.outputs.redis_auth_secret_id
  redis_ca_secret_id          = dependency.foundation.outputs.redis_ca_secret_id
  image_repository            = dependency.foundation.outputs.image_repository
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
      display_name = "self-hosted runner subnet"
    },
    {
      cidr_block   = dependency.foundation.outputs.vpn_client_cidr
      display_name = "WireGuard administrator VPN"
    },
  ]
})
