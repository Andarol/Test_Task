output "region" {
  value       = var.region
  description = "Region represented by this state."
}

output "image_repository" {
  value       = var.image_repository
  description = "Shared image repository without a tag."
}

output "gke_cluster_name" {
  value       = module.gke.cluster_name
  description = "Regional GKE cluster name."
}

output "gke_cluster_location" {
  value       = module.gke.cluster_location
  description = "Regional GKE cluster location."
}

output "gke_node_locations" {
  value       = module.gke.node_locations
  description = "Zones in which GKE creates standalone NEG resources."
}

output "cloudsql_private_ip" {
  value       = var.cloudsql_private_ip
  description = "Private IP of the shared Cloud SQL primary."
}

output "database_password_secret_id" {
  value       = var.database_password_secret_id
  description = "Shared Secret Manager database password secret ID."
}

output "database_service_cidr" {
  value       = var.database_service_cidr
  description = "CIDR permitted by the regional application NetworkPolicy."
}

output "redis_host" {
  value       = var.redis_host
  description = "Private endpoint of the shared Redis cache."
}

output "redis_port" {
  value       = var.redis_port
  description = "TLS port of the shared Redis cache."
}

output "redis_auth_secret_id" {
  value       = var.redis_auth_secret_id
  description = "Secret Manager secret containing Redis AUTH."
}

output "redis_ca_secret_id" {
  value       = var.redis_ca_secret_id
  description = "Secret Manager secret containing the Redis TLS CA."
}

output "neg_name" {
  value       = "order-service-${var.environment}-${var.region}"
  description = "Name requested for the GKE standalone NEG in every cluster zone."
}
