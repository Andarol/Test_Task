resource "google_compute_network" "vpc" {
  project                         = var.project_id
  name                            = var.name
  auto_create_subnetworks         = false
  delete_default_routes_on_create = false
  routing_mode                    = "REGIONAL"
}

resource "google_compute_subnetwork" "gke" {
  project                  = var.project_id
  name                     = "${var.name}-gke"
  region                   = var.region
  network                  = google_compute_network.vpc.id
  ip_cidr_range            = var.gke_subnet_cidr
  private_ip_google_access = true

  secondary_ip_range {
    range_name    = "pods"
    ip_cidr_range = var.gke_pods_cidr
  }

  secondary_ip_range {
    range_name    = "services"
    ip_cidr_range = var.gke_services_cidr
  }
}

resource "google_compute_subnetwork" "sql" {
  project                  = var.project_id
  name                     = "${var.name}-sql"
  region                   = var.region
  network                  = google_compute_network.vpc.id
  ip_cidr_range            = var.sql_subnet_cidr
  private_ip_google_access = true
}

resource "google_compute_router" "nat_router" {
  project = var.project_id
  name    = "${var.name}-router"
  region  = var.region
  network = google_compute_network.vpc.id
}

resource "google_compute_router_nat" "private_nat" {
  project                            = var.project_id
  name                               = "${var.name}-nat"
  router                             = google_compute_router.nat_router.name
  region                             = var.region
  nat_ip_allocate_option             = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "LIST_OF_SUBNETWORKS"

  subnetwork {
    name                    = google_compute_subnetwork.gke.id
    source_ip_ranges_to_nat = ["ALL_IP_RANGES"]
  }
}

resource "google_compute_global_address" "private_services" {
  project       = var.project_id
  name          = "${var.name}-private-services"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  address       = cidrhost(var.private_service_cidr, 0)
  prefix_length = tonumber(split("/", var.private_service_cidr)[1])
  network       = google_compute_network.vpc.id
}

resource "google_service_networking_connection" "private_services" {
  network                 = google_compute_network.vpc.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_services.name]
}

resource "google_compute_firewall" "internal" {
  project   = var.project_id
  name      = "${var.name}-allow-internal"
  network   = google_compute_network.vpc.name
  direction = "INGRESS"

  source_ranges = [var.gke_subnet_cidr, var.sql_subnet_cidr]
  allow {
    protocol = "tcp"
    ports    = ["443", "5432", "10250"]
  }
  allow {
    protocol = "udp"
    ports    = ["53", "8472"]
  }
  allow {
    protocol = "icmp"
  }
}

resource "google_compute_firewall" "control_plane" {
  project   = var.project_id
  name      = "${var.name}-allow-control-plane"
  network   = google_compute_network.vpc.name
  direction = "INGRESS"
  priority  = 900

  source_ranges = var.admin_cidrs
  allow {
    protocol = "tcp"
    ports    = ["443", "10250"]
  }
}

resource "google_compute_firewall" "health_checks" {
  project     = var.project_id
  name        = "${var.name}-allow-health-checks"
  network     = google_compute_network.vpc.name
  direction   = "INGRESS"
  target_tags = ["gke-nodes"]
  source_ranges = [
    "35.191.0.0/16",
    "130.211.0.0/22",
  ]

  allow {
    protocol = "tcp"
    ports    = ["80", "443"]
  }
}
