output "argocd_namespace" {
  value = helm_release.argocd.namespace
}

output "rancher_namespace" {
  value = helm_release.rancher.namespace
}

output "rancher_bootstrap_secret_id" {
  value = google_secret_manager_secret.rancher_bootstrap.secret_id
}
