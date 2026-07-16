locals {
  environment = read_terragrunt_config(find_in_parent_folders("environment.hcl"))
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
  source = "../../../terraform//stacks/foundation"
}

dependency "management" {
  config_path = "../../bootstrap/runner"
  mock_outputs = {
    network_id             = "projects/mock/global/networks/order-management-vpc"
    network_name           = "order-management-vpc"
    management_subnet_cidr = "10.0.0.0/24"
    vpn_client_cidr        = "10.250.0.0/24"
    image_repository       = "europe-west3-docker.pkg.dev/mock/order-service/order-service"
    private_service_ranges = {
      staging = {
        name = "order-staging-psa"
        cidr = "10.90.0.0/16"
      }
      production = {
        name = "order-production-psa"
        cidr = "10.190.0.0/16"
      }
    }
  }
  mock_outputs_allowed_terraform_commands = ["validate"]
}

inputs = merge(local.environment.locals.common_inputs, {
  network_id                 = dependency.management.outputs.network_id
  network_name               = dependency.management.outputs.network_name
  management_subnet_cidr     = dependency.management.outputs.management_subnet_cidr
  vpn_client_cidr            = dependency.management.outputs.vpn_client_cidr
  image_repository           = dependency.management.outputs.image_repository
  private_service_range_name = dependency.management.outputs.private_service_ranges[local.environment.locals.environment].name
  database_region            = local.environment.locals.database_region
  database_service_cidr      = local.environment.locals.database_service_cidr
  database_tier              = local.environment.locals.database_tier
  database_disk_size_gb      = local.environment.locals.database_disk_size_gb
  cache_region               = local.environment.locals.cache_region
  cache_memory_size_gb       = local.environment.locals.cache_memory_size_gb
})
