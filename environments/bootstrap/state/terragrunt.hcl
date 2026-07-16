locals {
  project_id = get_env("GCP_PROJECT_ID", "REPLACE_WITH_GCP_PROJECT_ID")
}

terraform {
  source = "../../../terraform//bootstrap"
}

inputs = {
  project_id = local.project_id
  state_bucket_names = {
    stage = get_env("TF_STATE_BUCKET_STAGE", "${local.project_id}-stage-tfstate")
    prod  = get_env("TF_STATE_BUCKET_PROD", "${local.project_id}-prod-tfstate")
  }
}
