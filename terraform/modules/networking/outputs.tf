output "gke_subnetwork_id" {
  value       = google_compute_subnetwork.gke.id
  description = "GKE subnetwork ID."
}

output "pod_range_name" {
  value       = google_compute_subnetwork.gke.secondary_ip_range[0].range_name
  description = "GKE pod secondary range name."
}

output "service_range_name" {
  value       = google_compute_subnetwork.gke.secondary_ip_range[1].range_name
  description = "Kubernetes Service secondary range name."
}

output "node_network_tag" {
  value       = local.node_tag
  description = "Network tag attached to GKE nodes."
}
