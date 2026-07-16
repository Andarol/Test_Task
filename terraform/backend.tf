terraform {
  # Terragrunt generates environment-specific GCS bucket values and stack-specific
  # prefixes for each environment entry point.
  # The GCS backend provides native state locking through a .tflock object.
  backend "gcs" {}
}
