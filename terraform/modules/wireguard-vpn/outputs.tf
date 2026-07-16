output "public_ip" {
  value       = google_compute_address.vpn.address
  description = "WireGuard endpoint public IP."
}

output "instance_name" {
  value       = google_compute_instance.vpn.name
  description = "WireGuard gateway VM name."
}

output "vpn_client_cidr" {
  value       = var.vpn_client_cidr
  description = "CIDR routed through the single client VPN."
}
