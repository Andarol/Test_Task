resource "google_redis_instance" "this" {
  project                 = var.project_id
  name                    = var.name
  display_name            = "Shared order-service cache"
  region                  = var.region
  tier                    = "STANDARD_HA"
  memory_size_gb          = var.memory_size_gb
  redis_version           = "REDIS_7_2"
  authorized_network      = var.network_id
  connect_mode            = "PRIVATE_SERVICE_ACCESS"
  reserved_ip_range       = var.reserved_ip_range
  auth_enabled            = true
  transit_encryption_mode = "SERVER_AUTHENTICATION"
  labels                  = var.labels

  redis_configs = {
    "maxmemory-policy" = "allkeys-lru"
  }

  persistence_config {
    persistence_mode    = "RDB"
    rdb_snapshot_period = "TWELVE_HOURS"
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "google_secret_manager_secret" "auth" {
  project   = var.project_id
  secret_id = "${var.name}-auth"

  replication {
    auto {}
  }

  labels = var.labels
}

resource "google_secret_manager_secret_version" "auth" {
  secret      = google_secret_manager_secret.auth.id
  secret_data = google_redis_instance.this.auth_string
}

resource "google_secret_manager_secret" "ca" {
  project   = var.project_id
  secret_id = "${var.name}-ca"

  replication {
    auto {}
  }

  labels = var.labels
}

resource "google_secret_manager_secret_version" "ca" {
  secret      = google_secret_manager_secret.ca.id
  secret_data = google_redis_instance.this.server_ca_certs[0].cert
}
