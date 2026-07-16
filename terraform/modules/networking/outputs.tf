output "network_name" {
  value = google_compute_network.vpc.name
}

output "network_id" {
  value = google_compute_network.vpc.id
}

output "gke_subnet_name" {
  value = google_compute_subnetwork.gke.name
}

output "gke_subnet_self_link" {
  value = google_compute_subnetwork.gke.self_link
}

output "pods_range_name" {
  value = google_compute_subnetwork.gke.secondary_ip_range[0].range_name
}

output "services_range_name" {
  value = google_compute_subnetwork.gke.secondary_ip_range[1].range_name
}

output "sql_subnet_name" {
  value = google_compute_subnetwork.sql.name
}

output "private_service_connection" {
  value = google_service_networking_connection.private_services.network
}
