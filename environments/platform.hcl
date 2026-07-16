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
    prefix               = "${path_relative_to_include()}/terraform.tfstate"
    location             = "EU"
    skip_bucket_creation = true
  }
}

terraform {
  source = "../../../../terraform//stacks/platform"
}

dependency "regional" {
  config_path = ".."
  mock_outputs = {
    image_repository            = "europe-west3-docker.pkg.dev/mock/order-service/order-service"
    gke_cluster_name            = "order-mock-europe-west3-gke"
    gke_cluster_location        = "europe-west3"
    cloudsql_private_ip         = "10.90.0.10"
    database_service_cidr       = "10.90.0.0/16"
    database_password_secret_id = "order-mock-postgres-password"
    redis_host                  = "10.90.1.10"
    redis_port                  = 6378
    redis_auth_secret_id        = "order-mock-redis-auth"
    redis_ca_secret_id          = "order-mock-redis-ca"
    neg_name                    = "order-service-mock-europe-west3"
  }
  mock_outputs_allowed_terraform_commands = ["validate"]
}

inputs = merge(local.environment.locals.common_inputs, {
  region                      = local.region
  gke_cluster_name            = dependency.regional.outputs.gke_cluster_name
  gke_cluster_location        = dependency.regional.outputs.gke_cluster_location
  git_repository_url          = local.environment.locals.git_repository_url
  git_revision                = local.environment.locals.git_revision
  rancher_hostname            = local.environment.locals.rancher_hostname
  argocd_hostname             = local.environment.locals.argocd_hostname
  image_repository            = dependency.regional.outputs.image_repository
  image_tag                   = get_env("IMAGE_TAG", "latest")
  neg_name                    = dependency.regional.outputs.neg_name
  cloudsql_private_ip         = dependency.regional.outputs.cloudsql_private_ip
  database_service_cidr       = dependency.regional.outputs.database_service_cidr
  database_password_secret_id = dependency.regional.outputs.database_password_secret_id
  redis_host                  = dependency.regional.outputs.redis_host
  redis_port                  = dependency.regional.outputs.redis_port
  redis_auth_secret_id        = dependency.regional.outputs.redis_auth_secret_id
  redis_ca_secret_id          = dependency.regional.outputs.redis_ca_secret_id
})
