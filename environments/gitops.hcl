locals {
  environment = read_terragrunt_config(find_in_parent_folders("environment.hcl"))
  region      = basename(dirname(path_relative_to_include()))
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
    # Preserve the previous platform state address after the directory rename.
    prefix               = "${local.environment.locals.environment}/${local.region}/platform/terraform.tfstate"
    location             = "EU"
    skip_bucket_creation = true
  }
}

terraform {
  source = "../../../../terraform//stacks/gitops"
}

dependency "cluster" {
  config_path = "../cluster"
  mock_outputs = {
    gke_cluster_name     = "order-mock-europe-west3-gke"
    gke_cluster_location = "europe-west3"
  }
  mock_outputs_allowed_terraform_commands = ["validate"]
}

inputs = merge(local.environment.locals.common_inputs, {
  region               = local.region
  gke_cluster_name     = dependency.cluster.outputs.gke_cluster_name
  gke_cluster_location = dependency.cluster.outputs.gke_cluster_location
  git_repository_url   = local.environment.locals.git_repository_url
  git_revision         = local.environment.locals.git_revision
  rancher_hostname     = local.environment.locals.rancher_hostname
  argocd_hostname      = local.environment.locals.argocd_hostname
  gitops_values_file   = "gitops/environments/${local.environment.locals.environment}/values.yaml"
})
