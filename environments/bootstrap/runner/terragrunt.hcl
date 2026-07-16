locals {
  project_id = get_env("GCP_PROJECT_ID", "REPLACE_WITH_GCP_PROJECT_ID")
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
    prefix               = "bootstrap/runner/terraform.tfstate"
    location             = "EU"
    skip_bucket_creation = true
  }
}

terraform {
  source = "../../../terraform//stacks/management"
}

inputs = {
  project_id                      = local.project_id
  region                          = "europe-west3"
  zone                            = "europe-west3-a"
  management_cidr                 = "10.0.0.0/24"
  github_repository_url           = "https://github.com/Andarol/Test_Task"
  wireguard_client_public_key     = get_env("WIREGUARD_CLIENT_PUBLIC_KEY", "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=")
  wireguard_allowed_source_ranges = [get_env("WIREGUARD_ALLOWED_SOURCE_CIDR", "0.0.0.0/0")]
  private_service_ranges = {
    staging = {
      cidr = "10.90.0.0/16"
    }
    production = {
      cidr = "10.190.0.0/16"
    }
  }
}
