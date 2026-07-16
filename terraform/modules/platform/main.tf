data "google_client_config" "current" {}

data "google_container_cluster" "this" {
  project  = var.project_id
  name     = var.cluster_name
  location = var.cluster_location
}

locals {
  private_endpoint = data.google_container_cluster.this.private_cluster_config[0].private_endpoint
}

provider "kubernetes" {
  host                   = "https://${local.private_endpoint}"
  token                  = data.google_client_config.current.access_token
  cluster_ca_certificate = base64decode(data.google_container_cluster.this.master_auth[0].cluster_ca_certificate)
}

provider "helm" {
  kubernetes {
    host                   = "https://${local.private_endpoint}"
    token                  = data.google_client_config.current.access_token
    cluster_ca_certificate = base64decode(data.google_container_cluster.this.master_auth[0].cluster_ca_certificate)
  }
}

resource "helm_release" "argocd" {
  name             = "argocd"
  namespace        = "argocd"
  create_namespace = true
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = var.argocd_chart_version

  set {
    name  = "server.service.type"
    value = "ClusterIP"
  }
  set {
    name  = "server.insecure"
    value = "true"
  }
}

resource "random_password" "rancher_bootstrap" {
  length  = 32
  special = true
}

resource "helm_release" "rancher" {
  name             = "rancher"
  namespace        = "cattle-system"
  create_namespace = true
  repository       = "https://releases.rancher.com/server-charts/stable"
  chart            = "rancher"
  version          = var.rancher_chart_version

  set {
    name  = "hostname"
    value = var.rancher_hostname
  }
  set {
    name  = "bootstrapPassword"
    value = random_password.rancher_bootstrap.result
  }
  set {
    name  = "replicas"
    value = "1"
  }
  set {
    name  = "ingress.tls.source"
    value = "rancher"
  }
}

resource "google_secret_manager_secret" "rancher_bootstrap" {
  project   = var.project_id
  secret_id = "${var.cluster_name}-rancher-bootstrap"
  replication {
    auto {}
  }
}

resource "google_secret_manager_secret_version" "rancher_bootstrap" {
  secret      = google_secret_manager_secret.rancher_bootstrap.id
  secret_data = random_password.rancher_bootstrap.result
}
