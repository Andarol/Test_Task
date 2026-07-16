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
  source = "../../../terraform//stacks/global"
}

dependency "cluster" {
  config_path = "../${local.environment.locals.region}/cluster"
  mock_outputs = {
    neg_name           = "order-service-${local.environment.locals.environment}-europe-west3"
    gke_node_locations = ["europe-west3-a", "europe-west3-b", "europe-west3-c"]
  }
  mock_outputs_allowed_terraform_commands = ["validate"]
}

inputs = merge(local.environment.locals.common_inputs, {
  domain_names                    = local.environment.locals.domain_names
  waf_preview                     = local.environment.locals.waf_preview
  waf_rate_limit_requests_per_min = local.environment.locals.waf_rate_limit_requests_per_min
  regions = {
    (local.environment.locals.region) = {
      neg_name        = dependency.cluster.outputs.neg_name
      zones           = dependency.cluster.outputs.gke_node_locations
      capacity_scaler = local.environment.locals.regions[local.environment.locals.region].capacity_scaler
    }
  }
})
