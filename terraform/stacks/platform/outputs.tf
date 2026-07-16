output "rancher_hostname" {
  value       = var.rancher_hostname
  description = "Configured Rancher hostname."
}

output "argocd_hostname" {
  value       = var.argocd_hostname
  description = "Private Argo CD hostname used through the VPN tunnel."
}

output "rancher_bootstrap_secret_id" {
  value       = google_secret_manager_secret.rancher_bootstrap.secret_id
  description = "Secret Manager secret containing the initial Rancher admin password."
}

output "argocd_root_application" {
  value       = "order-service-${var.environment}"
  description = "Argo CD app-of-apps root Application name."
}
