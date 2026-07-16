locals {
  sanitized_name       = replace(lower(replace(var.name, "_", "-")), "/[^a-z0-9-]/", "-")
  service_account_stem = replace(substr(local.sanitized_name, 0, 20), "/-+$/", "")
  service_account_id   = "${local.service_account_stem}-bastion"
}

resource "google_service_account" "this" {
  count        = var.service_account == null ? 1 : 0
  project      = var.project_id
  account_id   = local.service_account_id
  display_name = "${var.name} bastion"
}

locals {
  service_account = coalesce(var.service_account, google_service_account.this[0].email)
}

resource "google_project_iam_member" "container_viewer" {
  project = var.project_id
  role    = "roles/container.clusterViewer"
  member  = "serviceAccount:${local.service_account}"
}

data "google_compute_subnetwork" "this" {
  self_link = var.subnetwork
}

resource "google_compute_instance" "this" {
  project      = var.project_id
  name         = var.name
  zone         = var.zone
  machine_type = var.machine_type
  tags         = var.tags

  boot_disk {
    initialize_params {
      image = "projects/debian-cloud/global/images/family/debian-12"
      size  = 20
      type  = "pd-balanced"
    }
  }

  network_interface {
    subnetwork = var.subnetwork
    # No access_config: the bastion has no public IP and is reached through IAP.
  }

  service_account {
    email  = local.service_account
    scopes = ["https://www.googleapis.com/auth/cloud-platform"]
  }

  metadata = {
    enable-oslogin = "TRUE"
  }

  shielded_instance_config {
    enable_secure_boot          = true
    enable_vtpm                 = true
    enable_integrity_monitoring = true
  }
}

resource "google_compute_firewall" "iap_ssh" {
  project     = var.project_id
  name        = "${var.name}-allow-iap-ssh"
  network     = data.google_compute_subnetwork.this.network
  direction   = "INGRESS"
  target_tags = var.tags

  source_ranges = ["35.235.240.0/20"]
  allow {
    protocol = "tcp"
    ports    = ["22"]
  }
}
