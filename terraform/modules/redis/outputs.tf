output "host" {
  value       = google_redis_instance.this.host
  description = "Private Redis endpoint shared by every compute region."
}

output "port" {
  value       = google_redis_instance.this.port
  description = "TLS Redis port."
}

output "auth_secret_id" {
  value       = google_secret_manager_secret.auth.secret_id
  description = "Secret Manager secret containing the Redis AUTH string."
}

output "ca_secret_id" {
  value       = google_secret_manager_secret.ca.secret_id
  description = "Secret Manager secret containing the Redis server CA."
}
