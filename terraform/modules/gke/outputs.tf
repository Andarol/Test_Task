output "cluster_name" {
  value = google_container_cluster.this.name
}

output "cluster_location" {
  value = google_container_cluster.this.location
}

output "cluster_endpoint" {
  value     = google_container_cluster.this.endpoint
  sensitive = true
}

output "cluster_ca_certificate" {
  value     = google_container_cluster.this.master_auth[0].cluster_ca_certificate
  sensitive = true
}

output "node_service_account" {
  value = local.node_service_account
}

output "application_node_pool" {
  value = google_container_node_pool.application.name
}

output "order_service_workload_service_account" {
  value = google_service_account.order_service_workload.email
}
