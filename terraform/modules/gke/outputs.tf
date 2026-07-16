output "cluster_name" {
  value       = google_container_cluster.this.name
  description = "GKE cluster name."
}

output "cluster_location" {
  value       = google_container_cluster.this.location
  description = "GKE cluster location."
}

output "node_locations" {
  value       = google_container_cluster.this.node_locations
  description = "Zones used by the regional cluster."
}

output "private_endpoint" {
  value       = google_container_cluster.this.private_cluster_config[0].private_endpoint
  description = "Private Kubernetes API endpoint."
  sensitive   = true
}

output "node_service_account" {
  value       = google_service_account.nodes.email
  description = "GKE node service account."
}
