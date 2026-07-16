provider "google" {
  project = var.project_id
  region  = var.region
}

locals {
  name = "order-${var.environment}-${var.region}"
}

resource "google_project_service" "required" {
  for_each = toset([
    "compute.googleapis.com",
    "container.googleapis.com",
    "artifactregistry.googleapis.com",
    "iam.googleapis.com",
    "logging.googleapis.com",
    "monitoring.googleapis.com",
    "secretmanager.googleapis.com",
    "servicenetworking.googleapis.com",
    "sqladmin.googleapis.com",
  ])

  project            = var.project_id
  service            = each.value
  disable_on_destroy = false
}

resource "google_artifact_registry_repository" "docker" {
  project       = var.project_id
  location      = var.region
  repository_id = "order-service"
  format        = "DOCKER"
  description   = "Docker images for order-service and private GitHub runners"

  depends_on = [google_project_service.required]
}

module "networking" {
  source = "../../modules/networking"

  project_id           = var.project_id
  name                 = "${local.name}-network"
  region               = var.region
  gke_subnet_cidr      = var.network_cidr
  gke_pods_cidr        = var.gke_pods_cidr
  gke_services_cidr    = var.gke_services_cidr
  sql_subnet_cidr      = var.sql_subnet_cidr
  private_service_cidr = var.private_service_cidr
  admin_cidrs          = var.admin_cidrs
  labels = {
    environment = var.environment
    managed_by  = "terragrunt"
  }

  depends_on = [google_project_service.required]
}

module "gke" {
  source = "../../modules/gke"

  project_id                  = var.project_id
  cluster_name                = "${local.name}-gke"
  region                      = var.region
  zones                       = var.zones
  network                     = module.networking.network_name
  subnetwork                  = module.networking.gke_subnet_name
  pods_range_name             = module.networking.pods_range_name
  services_range_name         = module.networking.services_range_name
  master_cidr                 = var.master_cidr
  master_authorized_networks  = var.admin_cidrs
  node_machine_type           = var.node_machine_type
  node_min_count              = var.node_min_count
  node_max_count              = var.node_max_count
  workload_service_account_id = "order-${var.environment}-app"

  depends_on = [module.networking]
}

module "cloudsql" {
  source = "../../modules/cloudsql"

  project_id    = var.project_id
  instance_name = "${local.name}-postgres"
  region        = var.region
  network       = module.networking.network_id
  tier          = var.sql_tier

  depends_on = [module.networking]
}

module "bastion" {
  source = "../../modules/bastion"

  project_id = var.project_id
  name       = "${local.name}-bastion"
  zone       = var.zones[0]
  subnetwork = module.networking.gke_subnet_self_link

  depends_on = [module.networking]
}
