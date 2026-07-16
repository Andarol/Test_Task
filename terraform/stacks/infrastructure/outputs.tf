output "network_name" {
  value = module.networking.network_name
}

output "gke_subnet_name" {
  value = module.networking.gke_subnet_name
}

output "sql_subnet_name" {
  value = module.networking.sql_subnet_name
}

output "cluster_name" {
  value = module.gke.cluster_name
}

output "cluster_location" {
  value = module.gke.cluster_location
}

output "cluster_endpoint" {
  value     = module.gke.cluster_endpoint
  sensitive = true
}

output "application_node_pool" {
  value = module.gke.application_node_pool
}

output "order_service_workload_service_account" {
  value = module.gke.order_service_workload_service_account
}

output "sql_instance_name" {
  value = module.cloudsql.instance_name
}

output "sql_private_ip" {
  value = module.cloudsql.private_ip
}

output "sql_credentials_secret_id" {
  value = module.cloudsql.credentials_secret_id
}

output "bastion_name" {
  value = module.bastion.instance_name
}

output "bastion_internal_ip" {
  value = module.bastion.internal_ip
}

output "bastion_iap_ssh_command" {
  value = module.bastion.iap_ssh_command
}

output "artifact_registry_repository" {
  value = google_artifact_registry_repository.docker.name
}

output "artifact_registry_docker_hostname" {
  value = "${var.region}-docker.pkg.dev"
}
