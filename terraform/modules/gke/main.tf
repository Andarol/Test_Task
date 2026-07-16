resource "google_service_account" "nodes" {
  project      = var.project_id
  account_id   = substr(replace("${var.name}-nodes", "_", "-"), 0, 30)
  display_name = "${var.name} GKE node identity"
}

locals {
  node_roles = toset([
    "roles/artifactregistry.reader",
    "roles/logging.logWriter",
    "roles/monitoring.metricWriter",
    "roles/monitoring.viewer",
    "roles/stackdriver.resourceMetadata.writer",
  ])
}

resource "google_project_iam_member" "nodes" {
  for_each = local.node_roles
  project  = var.project_id
  role     = each.value
  member   = "serviceAccount:${google_service_account.nodes.email}"
}

resource "google_container_cluster" "this" {
  project  = var.project_id
  name     = var.name
  location = var.region

  node_locations = var.node_locations

  network    = var.network_id
  subnetwork = var.subnetwork_id

  initial_node_count       = 1
  remove_default_node_pool = true
  skip_node_pool_refresh   = true
  deletion_protection      = true

  # GKE must create a temporary default pool before removing it. Keep that
  # bootstrap pool on standard disks so it does not consume SSD quota.
  node_config {
    disk_type    = "pd-standard"
    disk_size_gb = 20
  }

  networking_mode   = "VPC_NATIVE"
  datapath_provider = "ADVANCED_DATAPATH"

  ip_allocation_policy {
    cluster_secondary_range_name  = var.pod_range_name
    services_secondary_range_name = var.service_range_name
  }

  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = true
    master_ipv4_cidr_block  = var.master_cidr

    master_global_access_config {
      enabled = false
    }
  }

  master_authorized_networks_config {
    gcp_public_cidrs_access_enabled      = false
    private_endpoint_enforcement_enabled = true

    dynamic "cidr_blocks" {
      for_each = var.master_authorized_networks
      content {
        cidr_block   = cidr_blocks.value.cidr_block
        display_name = cidr_blocks.value.display_name
      }
    }
  }

  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  binary_authorization {
    evaluation_mode = "PROJECT_SINGLETON_POLICY_ENFORCE"
  }

  secret_sync_config {
    enabled = true
    rotation_config {
      enabled           = true
      rotation_interval = "300s"
    }
  }

  release_channel {
    channel = "REGULAR"
  }

  addons_config {
    horizontal_pod_autoscaling {
      disabled = false
    }
    http_load_balancing {
      disabled = false
    }
  }

  logging_config {
    enable_components = ["SYSTEM_COMPONENTS", "WORKLOADS", "APISERVER", "SCHEDULER", "CONTROLLER_MANAGER"]
  }

  monitoring_config {
    enable_components = ["SYSTEM_COMPONENTS", "APISERVER", "SCHEDULER", "CONTROLLER_MANAGER", "STORAGE", "POD", "DEPLOYMENT", "STATEFULSET", "DAEMONSET", "HPA", "CADVISOR", "KUBELET"]
    managed_prometheus {
      enabled = true
    }
  }

  maintenance_policy {
    recurring_window {
      start_time = "2026-01-04T02:00:00Z"
      end_time   = "2026-01-04T06:00:00Z"
      recurrence = "FREQ=WEEKLY;BYDAY=SU"
    }
  }

  resource_labels = var.labels

  lifecycle {
    prevent_destroy = true
    # Worker topology is managed by google_container_node_pool.application.
    # Changing this default must never replace an existing regional control plane.
    ignore_changes = [node_config, node_locations]
  }
}

resource "google_container_node_pool" "application" {
  project  = var.project_id
  name     = "application"
  location = var.region
  cluster  = google_container_cluster.this.name

  node_locations = var.node_locations

  initial_node_count = var.min_nodes_per_zone

  autoscaling {
    min_node_count  = var.min_nodes_per_zone
    max_node_count  = var.max_nodes_per_zone
    location_policy = "BALANCED"
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  upgrade_settings {
    max_surge       = 1
    max_unavailable = 0
  }

  node_config {
    machine_type    = var.machine_type
    image_type      = "COS_CONTAINERD"
    disk_type       = "pd-standard"
    disk_size_gb    = 50
    service_account = google_service_account.nodes.email
    oauth_scopes    = ["https://www.googleapis.com/auth/cloud-platform"]
    tags            = [var.node_network_tag]

    labels = merge(var.labels, {
      workload = "order-service"
    })

    metadata = {
      disable-legacy-endpoints = "true"
    }

    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }
  }

  lifecycle {
    ignore_changes = [initial_node_count]
  }

  depends_on = [google_project_iam_member.nodes]
}
