provider "google" {
  project = var.project_id
  region  = var.region
}

module "platform" {
  source = "../../modules/platform"

  project_id            = var.project_id
  cluster_name          = var.cluster_name
  cluster_location      = var.region
  argocd_chart_version  = var.argocd_chart_version
  rancher_chart_version = var.rancher_chart_version
  rancher_hostname      = "rancher.${var.environment}.internal"
}
