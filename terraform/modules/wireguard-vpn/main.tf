data "google_compute_image" "ubuntu" {
  project = "ubuntu-os-cloud"
  family  = "ubuntu-2404-lts-amd64"
}

resource "google_compute_address" "vpn" {
  project = var.project_id
  name    = "${var.name}-ip"
  region  = var.region
}

resource "google_compute_firewall" "wireguard" {
  project       = var.project_id
  name          = "${var.name}-wireguard"
  network       = var.network_name
  direction     = "INGRESS"
  source_ranges = var.allowed_source_ranges
  target_tags   = ["wireguard-vpn"]

  allow {
    protocol = "udp"
    ports    = ["51820"]
  }
}

resource "google_compute_firewall" "vpn_to_vpc" {
  project       = var.project_id
  name          = "${var.name}-clients"
  network       = var.network_name
  direction     = "INGRESS"
  source_ranges = [var.vpn_client_cidr]

  allow {
    protocol = "tcp"
  }

  allow {
    protocol = "udp"
  }

  allow {
    protocol = "icmp"
  }
}

resource "google_compute_instance" "vpn" {
  project        = var.project_id
  name           = var.name
  zone           = var.zone
  machine_type   = "e2-micro"
  can_ip_forward = true
  tags           = ["wireguard-vpn", "iap-ssh"]
  labels         = var.labels

  boot_disk {
    initialize_params {
      image = data.google_compute_image.ubuntu.self_link
      size  = 20
      type  = "pd-balanced"
    }
  }

  network_interface {
    subnetwork = var.subnetwork_id
    access_config {
      nat_ip = google_compute_address.vpn.address
    }
  }

  metadata = {
    enable-oslogin         = "TRUE"
    block-project-ssh-keys = "TRUE"
    serial-port-enable     = "TRUE"
  }

  metadata_startup_script = templatefile("${path.module}/templates/startup.sh.tftpl", {
    client_public_key = var.client_public_key
    server_address    = var.server_address
    client_address    = var.client_address
  })

  shielded_instance_config {
    enable_secure_boot          = true
    enable_vtpm                 = true
    enable_integrity_monitoring = true
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "google_compute_route" "vpn_clients" {
  project                = var.project_id
  name                   = "${var.name}-clients"
  network                = var.network_name
  dest_range             = var.vpn_client_cidr
  priority               = 800
  next_hop_instance      = google_compute_instance.vpn.self_link
  next_hop_instance_zone = var.zone
}
