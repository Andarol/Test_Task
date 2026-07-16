output "network_id" {
  value       = var.network_id
  description = "Shared management VPC ID."
}

output "network_name" {
  value       = var.network_name
  description = "Shared management VPC name."
}

output "management_subnet_cidr" {
  value       = var.management_subnet_cidr
  description = "CIDR containing the management resources."
}

output "vpn_client_cidr" {
  value       = var.vpn_client_cidr
  description = "CIDR routed by the shared WireGuard VPN."
}

output "image_repository" {
  value       = var.image_repository
  description = "Shared Artifact Registry repository without tag."
}

output "cloudsql_private_ip" {
  value       = module.cloudsql.private_ip
  description = "Private IP of the regional-HA writable Cloud SQL primary."
}

output "database_password_secret_id" {
  value       = module.cloudsql.password_secret_id
  description = "Database password secret used by the application cluster."
}

output "database_service_cidr" {
  value       = var.database_service_cidr
  description = "Shared Private Service Access CIDR."
}

output "database_region" {
  value       = var.database_region
  description = "Region of the single writable Cloud SQL primary."
}

output "redis_host" {
  value       = module.redis.host
  description = "Private endpoint of the one shared Redis cache."
}

output "redis_port" {
  value       = module.redis.port
  description = "TLS port of the shared Redis cache."
}

output "redis_auth_secret_id" {
  value       = module.redis.auth_secret_id
  description = "Secret Manager secret containing Redis AUTH."
}

output "redis_ca_secret_id" {
  value       = module.redis.ca_secret_id
  description = "Secret Manager secret containing the Redis TLS CA."
}

output "cache_region" {
  value       = var.cache_region
  description = "Region of the shared Redis cache."
}
