resource "random_password" "database" {
  length  = 32
  special = true
}

resource "google_sql_database_instance" "this" {
  project             = var.project_id
  name                = var.instance_name
  database_version    = "POSTGRES_15"
  region              = var.region
  deletion_protection = true

  lifecycle {
    prevent_destroy = true
  }

  settings {
    tier              = var.tier
    availability_type = "REGIONAL"
    disk_type         = "PD_SSD"
    disk_size         = 20
    disk_autoresize   = true

    backup_configuration {
      enabled                        = true
      point_in_time_recovery_enabled = true
      transaction_log_retention_days = 7

      backup_retention_settings {
        retained_backups = var.backup_retained_count
        retention_unit   = "COUNT"
      }
    }

    ip_configuration {
      ipv4_enabled    = false
      private_network = var.network
      ssl_mode        = "ENCRYPTED_ONLY"
    }

    insights_config {
      query_insights_enabled  = true
      query_string_length     = 1024
      record_application_tags = true
      record_client_address   = false
    }
  }
}

resource "google_sql_database" "this" {
  project  = var.project_id
  name     = var.database_name
  instance = google_sql_database_instance.this.name
}

resource "google_sql_user" "application" {
  project  = var.project_id
  name     = "order-service"
  instance = google_sql_database_instance.this.name
  password = random_password.database.result
}

resource "google_secret_manager_secret" "database_credentials" {
  project   = var.project_id
  secret_id = "${var.instance_name}-credentials"

  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "database_credentials" {
  secret = google_secret_manager_secret.database_credentials.id
  secret_data = jsonencode({
    username = google_sql_user.application.name
    password = random_password.database.result
    database = google_sql_database.this.name
    host     = google_sql_database_instance.this.private_ip_address
    port     = 5432
  })
}
