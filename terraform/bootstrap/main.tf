provider "google" {
  project = var.project_id
}

resource "google_storage_bucket" "terraform_state" {
  for_each = var.state_bucket_names

  project                     = var.project_id
  name                        = each.value
  location                    = var.bucket_location
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  force_destroy               = false

  versioning {
    enabled = true
  }

  lifecycle_rule {
    condition {
      num_newer_versions = 10
    }
    action {
      type = "Delete"
    }
  }
}
