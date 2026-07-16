provider "google" {
  project = var.project_id
  region  = var.region
}

data "google_project" "current" {
  project_id = var.project_id
}

locals {
  name = "order-${var.environment}-${var.region}"
  labels = {
    application = "order-service"
    environment = var.environment
    region      = var.region
    managed_by  = "terragrunt"
  }
}

module "networking" {
  source = "../../modules/networking"

  project_id            = var.project_id
  name                  = local.name
  region                = var.region
  network_id            = var.network_id
  network_name          = var.network_name
  node_cidr             = var.node_cidr
  pod_cidr              = var.pod_cidr
  service_cidr          = var.service_cidr
  database_service_cidr = var.database_service_cidr
  master_cidr           = var.master_cidr
  trusted_ingress_cidrs = var.trusted_ingress_cidrs
}

module "gke" {
  source = "../../modules/gke"

  project_id                 = var.project_id
  name                       = "${local.name}-gke"
  region                     = var.region
  network_id                 = var.network_id
  subnetwork_id              = module.networking.gke_subnetwork_id
  pod_range_name             = module.networking.pod_range_name
  service_range_name         = module.networking.service_range_name
  master_cidr                = var.master_cidr
  master_authorized_networks = var.master_authorized_networks
  node_network_tag           = module.networking.node_network_tag
  machine_type               = var.gke_machine_type
  node_locations             = var.gke_node_locations
  min_nodes_per_zone         = var.gke_min_nodes_per_zone
  max_nodes_per_zone         = var.gke_max_nodes_per_zone
  labels                     = local.labels
}

resource "google_secret_manager_secret_iam_member" "application" {
  for_each = toset([
    var.database_password_secret_id,
    var.redis_auth_secret_id,
    var.redis_ca_secret_id,
  ])

  project   = var.project_id
  secret_id = each.value
  role      = "roles/secretmanager.secretAccessor"
  member    = "principal://iam.googleapis.com/projects/${data.google_project.current.number}/locations/global/workloadIdentityPools/${var.project_id}.svc.id.goog/subject/ns/order-service-${var.environment}/sa/order-service"

  depends_on = [module.gke]
}
