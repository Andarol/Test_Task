output "argocd_namespace" {
  value = module.platform.argocd_namespace
}

output "rancher_namespace" {
  value = module.platform.rancher_namespace
}

output "rancher_bootstrap_secret_id" {
  value = module.platform.rancher_bootstrap_secret_id
}
