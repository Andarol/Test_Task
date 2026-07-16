locals {
  sanitized_cluster_name    = replace(lower(replace(var.cluster_name, "_", "-")), "/[^a-z0-9-]/", "-")
  node_service_account_stem = replace(substr(local.sanitized_cluster_name, 0, 20), "/-+$/", "")
  node_service_account_id   = "${local.node_service_account_stem}-nodes"
}

resource "google_service_account" "nodes" {
  count        = var.node_service_account == null ? 1 : 0
  project      = var.project_id
  account_id   = local.node_service_account_id
  display_name = "${var.cluster_name} GKE nodes"
}

locals {
  node_service_account = coalesce(var.node_service_account, google_service_account.nodes[0].email)
}

resource "google_project_iam_member" "node_artifact_reader" {
  project = var.project_id
  role    = "roles/artifactregistry.reader"
  member  = "serviceAccount:${local.node_service_account}"
}

resource "google_project_iam_member" "node_logging" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${local.node_service_account}"
}

resource "google_project_iam_member" "node_monitoring" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${local.node_service_account}"
}

resource "google_service_account" "order_service_workload" {
  project      = var.project_id
  account_id   = var.workload_service_account_id
  display_name = "${var.cluster_name} order-service workload"
}

resource "google_project_iam_member" "order_service_secret_accessor" {
  project = var.project_id
  role    = "roles/secretmanager.secretAccessor"
  member  = "serviceAccount:${google_service_account.order_service_workload.email}"
}

resource "google_service_account_iam_member" "order_service_workload_identity" {
  service_account_id = google_service_account.order_service_workload.name
  role               = "roles/iam.workloadIdentityUser"
  member             = "serviceAccount:${var.project_id}.svc.id.goog[order-service/order-service]"
}

resource "google_container_cluster" "this" {
  project  = var.project_id
  name     = var.cluster_name
  location = var.region

  node_locations              = var.zones
  network                     = var.network
  subnetwork                  = var.subnetwork
  networking_mode             = "VPC_NATIVE"
  remove_default_node_pool    = true
  initial_node_count          = 1
  deletion_protection         = true
  enable_intranode_visibility = true

  ip_allocation_policy {
    cluster_secondary_range_name  = var.pods_range_name
    services_secondary_range_name = var.services_range_name
  }

  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = true
    master_ipv4_cidr_block  = var.master_cidr
  }

  master_authorized_networks_config {
    dynamic "cidr_blocks" {
      for_each = var.master_authorized_networks
      content {
        cidr_block   = cidr_blocks.value
        display_name = "admin-${cidr_blocks.key}"
      }
    }
  }

  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  binary_authorization {
    evaluation_mode = "PROJECT_SINGLETON_POLICY_ENFORCE"
  }

  release_channel {
    channel = "REGULAR"
  }

  addons_config {
    http_load_balancing {
      disabled = false
    }
    horizontal_pod_autoscaling {
      disabled = false
    }
  }
}

resource "google_container_node_pool" "application" {
  project        = var.project_id
  name           = "application"
  location       = var.region
  cluster        = google_container_cluster.this.name
  node_locations = var.zones

  autoscaling {
    min_node_count = var.node_min_count
    max_node_count = var.node_max_count
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  node_config {
    machine_type    = var.node_machine_type
    service_account = local.node_service_account
    oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]
    tags            = ["gke-nodes"]

    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }
  }
}
