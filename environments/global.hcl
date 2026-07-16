locals {
  project_id        = get_env("GCP_PROJECT_ID", "REPLACE_WITH_GCP_PROJECT_ID")
  region            = "europe-west3"
  zones             = ["europe-west3-a", "europe-west3-b"]
  state_environment = split("/", path_relative_to_include())[0]
  state_bucket_suffixes = {
    staging    = "stage"
    production = "prod"
  }
  state_bucket_suffix = local.state_bucket_suffixes[local.state_environment]
  state_bucket        = get_env("TF_STATE_BUCKET_${upper(local.state_bucket_suffix)}", "${local.project_id}-${local.state_bucket_suffix}-tfstate")
}

remote_state {
  backend = "gcs"

  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }

  config = {
    # Terraform state is separated by environment at bucket level:
    # - staging    -> $TF_STATE_BUCKET_STAGE or <project_id>-stage-tfstate
    # - production -> $TF_STATE_BUCKET_PROD or <project_id>-prod-tfstate
    #
    # Each Terragrunt entry point then gets an isolated object prefix:
    # - gs://<stage-bucket>/staging/europe-west3/terraform.tfstate
    # - gs://<stage-bucket>/staging/europe-west3/platform/terraform.tfstate
    # - gs://<prod-bucket>/production/europe-west3/terraform.tfstate
    # - gs://<prod-bucket>/production/europe-west3/platform/terraform.tfstate
    #
    # GCS provides native state locking through the .tflock object created next
    # to each state file.
    bucket = local.state_bucket
    prefix = "${path_relative_to_include()}/terraform.tfstate"
  }
}
