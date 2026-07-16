provider "google" {
  project = var.project_id
  region  = var.database_region
}

data "google_project" "current" {
  project_id = var.project_id
}

locals {
  name = "order-${var.environment}"
  labels = {
    application = "order-service"
    environment = var.environment
    scope       = "shared"
    managed_by  = "terragrunt"
  }
}

module "cloudsql" {
  source = "../../modules/cloudsql"

  project_id           = var.project_id
  project_number       = data.google_project.current.number
  name                 = "${local.name}-postgres"
  region               = var.database_region
  network_id           = var.network_id
  allocated_ip_range   = var.private_service_range_name
  kubernetes_namespace = "order-service-${var.environment}"
  database_tier        = var.database_tier
  disk_size_gb         = var.database_disk_size_gb
  labels               = local.labels

}

module "redis" {
  source = "../../modules/redis"

  project_id           = var.project_id
  project_number       = data.google_project.current.number
  name                 = "${local.name}-redis"
  region               = var.cache_region
  network_id           = var.network_id
  reserved_ip_range    = var.private_service_range_name
  kubernetes_namespace = "order-service-${var.environment}"
  memory_size_gb       = var.cache_memory_size_gb
  labels               = local.labels

}
