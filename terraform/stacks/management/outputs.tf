output "network_id" {
  value       = google_compute_network.management.id
  description = "Shared management VPC self-link."
}

output "network_name" {
  value       = google_compute_network.management.name
  description = "Shared management VPC name."
}

output "management_subnet_cidr" {
  value       = google_compute_subnetwork.management.ip_cidr_range
  description = "CIDR containing the management and VPN resources."
}

output "private_service_ranges" {
  value = {
    for environment, address in google_compute_global_address.private_services : environment => {
      name = address.name
      cidr = var.private_service_ranges[environment].cidr
    }
  }
  description = "Per-environment PSA ranges attached to the shared VPC."
}

output "image_repository" {
  value       = "${var.region}-docker.pkg.dev/${var.project_id}/${google_artifact_registry_repository.application.repository_id}/order-service"
  description = "Shared immutable application repository without tag."
}

output "vpn_public_ip" {
  value       = module.wireguard.public_ip
  description = "Public endpoint of the single WireGuard VPN."
}

output "vpn_instance_name" {
  value       = module.wireguard.instance_name
  description = "WireGuard gateway instance used to read the server public key."
}

output "vpn_client_cidr" {
  value       = module.wireguard.vpn_client_cidr
  description = "CIDR authorized for both private GKE API endpoints."
}
