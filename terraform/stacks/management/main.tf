provider "google" {
  project = var.project_id
  region  = var.region
}

locals {
  labels = {
    application = "order-service"
    scope       = "management"
    managed_by  = "terragrunt"
  }
}

resource "google_compute_network" "management" {
  project                 = var.project_id
  name                    = "order-management-vpc"
  auto_create_subnetworks = false
  routing_mode            = "GLOBAL"
}

resource "google_compute_subnetwork" "management" {
  project                  = var.project_id
  name                     = "order-management"
  region                   = var.region
  network                  = google_compute_network.management.id
  ip_cidr_range            = var.management_cidr
  private_ip_google_access = true

  log_config {
    aggregation_interval = "INTERVAL_5_SEC"
    flow_sampling        = 0.5
    metadata             = "INCLUDE_ALL_METADATA"
  }
}

resource "google_compute_router" "management" {
  project = var.project_id
  name    = "order-management-router"
  region  = var.region
  network = google_compute_network.management.id
}

resource "google_compute_router_nat" "management" {
  project                            = var.project_id
  name                               = "order-management-nat"
  region                             = var.region
  router                             = google_compute_router.management.name
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"

  subnetwork {
    name                    = google_compute_subnetwork.management.id
    source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
  }

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}

resource "google_compute_global_address" "private_services" {
  for_each = var.private_service_ranges

  project       = var.project_id
  name          = "order-${each.key}-psa"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  address       = split("/", each.value.cidr)[0]
  prefix_length = tonumber(split("/", each.value.cidr)[1])
  network       = google_compute_network.management.id
}

resource "google_service_networking_connection" "private_services" {
  network                 = google_compute_network.management.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [for address in google_compute_global_address.private_services : address.name]
}

resource "google_artifact_registry_repository" "application" {
  project       = var.project_id
  location      = var.region
  repository_id = "order-service"
  description   = "Immutable application images built by ARC runners"
  format        = "DOCKER"
  labels        = local.labels

  docker_config {
    immutable_tags = true
  }

  cleanup_policy_dry_run = false

  cleanup_policies {
    id     = "keep-recent"
    action = "KEEP"
    most_recent_versions {
      keep_count = 30
    }
  }

  cleanup_policies {
    id     = "delete-untagged"
    action = "DELETE"
    condition {
      tag_state  = "UNTAGGED"
      older_than = "2592000s"
    }
  }
}

module "wireguard" {
  source = "../../modules/wireguard-vpn"

  project_id            = var.project_id
  name                  = "order-wireguard"
  region                = var.region
  zone                  = var.zone
  network_name          = google_compute_network.management.name
  subnetwork_id         = google_compute_subnetwork.management.id
  client_public_key     = var.wireguard_client_public_key
  allowed_source_ranges = var.wireguard_allowed_source_ranges
  labels                = local.labels
}
