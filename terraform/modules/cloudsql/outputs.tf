output "instance_name" {
  value       = google_sql_database_instance.this.name
  description = "Cloud SQL instance name."
}

output "connection_name" {
  value       = google_sql_database_instance.this.connection_name
  description = "Cloud SQL connection name."
}

output "private_ip" {
  value       = google_sql_database_instance.this.private_ip_address
  description = "Cloud SQL private IPv4 address."
}

output "database_name" {
  value       = google_sql_database.application.name
  description = "Application database name."
}

output "database_user" {
  value       = google_sql_user.application.name
  description = "Application database user."
}

output "password_secret_id" {
  value       = google_secret_manager_secret.database_password.secret_id
  description = "Secret Manager secret containing the application database password."
}
