variable "project_id" {
  type        = string
  description = "Google Cloud project ID."
}

variable "github_repository" {
  type        = string
  description = "Trusted GitHub repository in owner/name form."
}

variable "bucket_location" {
  type        = string
  description = "Multi-region or region for the Terraform state bucket."
  default     = "EU"
}

provider "google" {
  project = var.project_id
}

locals {
  required_apis = toset([
    "artifactregistry.googleapis.com",
    "binaryauthorization.googleapis.com",
    "cloudresourcemanager.googleapis.com",
    "compute.googleapis.com",
    "container.googleapis.com",
    "iam.googleapis.com",
    "iamcredentials.googleapis.com",
    "iap.googleapis.com",
    "logging.googleapis.com",
    "monitoring.googleapis.com",
    "oslogin.googleapis.com",
    "redis.googleapis.com",
    "secretmanager.googleapis.com",
    "servicenetworking.googleapis.com",
    "sqladmin.googleapis.com",
    "sts.googleapis.com",
    "storage.googleapis.com",
  ])

  terraform_ci_roles = toset([
    "roles/artifactregistry.admin",
    "roles/cloudsql.admin",
    "roles/compute.networkAdmin",
    "roles/compute.securityAdmin",
    "roles/compute.instanceAdmin.v1",
    "roles/container.admin",
    "roles/iam.serviceAccountAdmin",
    "roles/iam.serviceAccountUser",
    "roles/iam.workloadIdentityPoolAdmin",
    "roles/resourcemanager.projectIamAdmin",
    "roles/redis.admin",
    "roles/secretmanager.admin",
    "roles/serviceusage.serviceUsageAdmin",
    "roles/storage.objectAdmin",
  ])

  deploy_ci_roles = toset([
    "roles/artifactregistry.writer",
    "roles/container.clusterViewer",
    "roles/container.developer",
  ])
}

resource "google_project_service" "required" {
  for_each           = local.required_apis
  project            = var.project_id
  service            = each.value
  disable_on_destroy = false
}

resource "google_storage_bucket" "terraform_state" {
  project                     = var.project_id
  name                        = "${var.project_id}-order-service-tfstate"
  location                    = var.bucket_location
  uniform_bucket_level_access = true
  public_access_prevention    = "enforced"
  force_destroy               = false

  versioning {
    enabled = true
  }

  lifecycle_rule {
    condition {
      num_newer_versions = 30
      with_state         = "ARCHIVED"
    }
    action {
      type = "Delete"
    }
  }

  depends_on = [google_project_service.required]
}

resource "google_iam_workload_identity_pool" "github" {
  project                   = var.project_id
  workload_identity_pool_id = "github-actions"
  display_name              = "GitHub Actions"
  description               = "OIDC identities for ${var.github_repository}"

  depends_on = [google_project_service.required]
}

resource "google_iam_workload_identity_pool_provider" "github" {
  project                            = var.project_id
  workload_identity_pool_id          = google_iam_workload_identity_pool.github.workload_identity_pool_id
  workload_identity_pool_provider_id = "github"
  display_name                       = "GitHub repository provider"

  attribute_mapping = {
    "google.subject"       = "assertion.sub"
    "attribute.actor"      = "assertion.actor"
    "attribute.repository" = "assertion.repository"
    "attribute.ref"        = "assertion.ref"
  }

  attribute_condition = "assertion.repository == '${var.github_repository}'"

  oidc {
    issuer_uri = "https://token.actions.githubusercontent.com"
  }
}

resource "google_service_account" "terraform_ci" {
  project      = var.project_id
  account_id   = "order-terraform-ci"
  display_name = "Order service Terragrunt CI"
}

resource "google_service_account" "deploy_ci" {
  project      = var.project_id
  account_id   = "order-deploy-ci"
  display_name = "Order service build and deploy CI"
}

resource "google_project_iam_member" "terraform_ci" {
  for_each = local.terraform_ci_roles
  project  = var.project_id
  role     = each.value
  member   = "serviceAccount:${google_service_account.terraform_ci.email}"
}

resource "google_project_iam_member" "deploy_ci" {
  for_each = local.deploy_ci_roles
  project  = var.project_id
  role     = each.value
  member   = "serviceAccount:${google_service_account.deploy_ci.email}"
}

resource "google_service_account_iam_member" "terraform_github" {
  service_account_id = google_service_account.terraform_ci.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.repository/${var.github_repository}"
}

resource "google_service_account_iam_member" "deploy_github" {
  service_account_id = google_service_account.deploy_ci.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "principalSet://iam.googleapis.com/${google_iam_workload_identity_pool.github.name}/attribute.repository/${var.github_repository}"
}

output "bucket_name" {
  value       = google_storage_bucket.terraform_state.name
  description = "Bucket used by Terragrunt remote_state."
}

output "github_workload_identity_provider" {
  value       = google_iam_workload_identity_pool_provider.github.name
  description = "Provider value for google-github-actions/auth."
}

output "terraform_ci_service_account" {
  value       = google_service_account.terraform_ci.email
  description = "Service account used for Terragrunt plan/apply."
}

output "deploy_ci_service_account" {
  value       = google_service_account.deploy_ci.email
  description = "Service account used for image build and GKE deployment."
}
