resource "google_compute_subnetwork" "gke" {
  project                  = var.project_id
  name                     = "${var.name}-gke"
  region                   = var.region
  network                  = var.network_id
  ip_cidr_range            = var.node_cidr
  private_ip_google_access = true

  secondary_ip_range {
    range_name    = "${var.name}-pods"
    ip_cidr_range = var.pod_cidr
  }

  secondary_ip_range {
    range_name    = "${var.name}-services"
    ip_cidr_range = var.service_cidr
  }

  log_config {
    aggregation_interval = "INTERVAL_5_SEC"
    flow_sampling        = 0.5
    metadata             = "INCLUDE_ALL_METADATA"
  }
}

resource "google_compute_router" "this" {
  project = var.project_id
  name    = "${var.name}-router"
  region  = var.region
  network = var.network_id
}

resource "google_compute_router_nat" "this" {
  project                            = var.project_id
  name                               = "${var.name}-nat"
  region                             = var.region
  router                             = google_compute_router.this.name
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"

  subnetwork {
    name                    = google_compute_subnetwork.gke.id
    source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
  }

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}

locals {
  internal_ranges = concat([var.node_cidr, var.pod_cidr, var.service_cidr], var.trusted_ingress_cidrs)
  node_tag        = "${var.name}-gke-node"
}

resource "google_compute_firewall" "internal_ingress" {
  project   = var.project_id
  name      = "${var.name}-internal-ingress"
  network   = var.network_name
  direction = "INGRESS"
  priority  = 1000

  source_ranges = local.internal_ranges
  target_tags   = [local.node_tag]

  allow {
    protocol = "all"
  }
}

resource "google_compute_firewall" "control_plane_ingress" {
  project   = var.project_id
  name      = "${var.name}-control-plane-ingress"
  network   = var.network_name
  direction = "INGRESS"
  priority  = 900

  source_ranges = [var.master_cidr]
  target_tags   = [local.node_tag]

  allow {
    protocol = "tcp"
    ports    = ["443", "10250"]
  }
}

resource "google_compute_firewall" "health_checks" {
  project   = var.project_id
  name      = "${var.name}-health-checks"
  network   = var.network_name
  direction = "INGRESS"
  priority  = 900

  source_ranges = ["35.191.0.0/16", "130.211.0.0/22"]
  target_tags   = [local.node_tag]

  allow {
    protocol = "tcp"
    ports    = ["8080"]
  }
}

resource "google_compute_firewall" "https_egress" {
  project   = var.project_id
  name      = "${var.name}-https-egress"
  network   = var.network_name
  direction = "EGRESS"
  priority  = 1000

  destination_ranges = ["0.0.0.0/0"]
  target_tags        = [local.node_tag]

  allow {
    protocol = "tcp"
    ports    = ["443"]
  }
}

resource "google_compute_firewall" "database_egress" {
  project   = var.project_id
  name      = "${var.name}-database-egress"
  network   = var.network_name
  direction = "EGRESS"
  priority  = 900

  destination_ranges = [var.database_service_cidr]
  target_tags        = [local.node_tag]

  allow {
    protocol = "tcp"
    ports    = ["5432"]
  }
}
