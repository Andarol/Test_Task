data "google_compute_image" "ubuntu" {
  project = "ubuntu-os-cloud"
  family  = "ubuntu-2404-lts-amd64"
}

resource "google_service_account" "runner" {
  project      = var.project_id
  account_id   = substr(var.name, 0, 30)
  display_name = "Order service GitHub self-hosted runner"
}

locals {
  runner_roles = toset([
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
  ])
}

resource "google_project_iam_member" "runner" {
  for_each = local.runner_roles
  project  = var.project_id
  role     = each.value
  member   = "serviceAccount:${google_service_account.runner.email}"
}

resource "google_secret_manager_secret" "registration" {
  project   = var.project_id
  secret_id = "${var.name}-registration"

  replication {
    auto {}
  }

  labels = var.labels
}

resource "google_secret_manager_secret_iam_member" "runner" {
  project   = var.project_id
  secret_id = google_secret_manager_secret.registration.secret_id
  role      = "roles/secretmanager.secretAccessor"
  member    = "serviceAccount:${google_service_account.runner.email}"
}

resource "google_compute_instance" "runner" {
  project      = var.project_id
  name         = var.name
  zone         = var.zone
  machine_type = var.machine_type
  tags         = var.network_tags
  labels       = var.labels

  boot_disk {
    initialize_params {
      image = data.google_compute_image.ubuntu.self_link
      size  = var.disk_size_gb
      type  = "pd-balanced"
    }
  }

  network_interface {
    subnetwork = var.subnetwork_id
  }

  service_account {
    email  = google_service_account.runner.email
    scopes = ["https://www.googleapis.com/auth/cloud-platform"]
  }

  metadata = {
    enable-oslogin         = "TRUE"
    block-project-ssh-keys = "TRUE"
    serial-port-enable     = "TRUE"
  }

  metadata_startup_script = templatefile("${path.module}/templates/startup.sh.tftpl", {
    project_id          = var.project_id
    registration_secret = google_secret_manager_secret.registration.secret_id
    repository_url      = var.github_repository_url
    runner_name         = var.name
    runner_labels       = join(",", var.runner_labels)
    runner_version      = var.runner_version
    runner_sha256       = var.runner_archive_sha256
  })

  shielded_instance_config {
    enable_secure_boot          = true
    enable_vtpm                 = true
    enable_integrity_monitoring = true
  }

  scheduling {
    automatic_restart   = true
    on_host_maintenance = "MIGRATE"
    provisioning_model  = "STANDARD"
  }

  lifecycle {
    prevent_destroy = true
    ignore_changes  = [metadata_startup_script]
  }

  depends_on = [
    google_project_iam_member.runner,
    google_secret_manager_secret_iam_member.runner,
  ]
}
