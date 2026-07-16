output "load_balancer_ip" {
  value       = google_compute_global_address.application.address
  description = "Global anycast IPv4 address."
}

output "backend_service" {
  value       = google_compute_backend_service.application.name
  description = "Global backend service balancing all regional GKE NEGs."
}

output "waf_security_policy" {
  value       = google_compute_security_policy.application.name
  description = "Cloud Armor policy attached to the global backend service."
}

output "regional_backends" {
  value = {
    for key, neg in data.google_compute_network_endpoint_group.regional : key => neg.id
  }
  description = "Resolved zonal NEGs attached to the global backend service."
}
