provider "google" {
  project = var.project_id
  region  = var.region
}

data "google_client_config" "current" {}

data "google_container_cluster" "target" {
  project  = var.project_id
  name     = var.gke_cluster_name
  location = var.gke_cluster_location
}

provider "helm" {
  kubernetes {
    host                   = "https://${data.google_container_cluster.target.private_cluster_config[0].private_endpoint}"
    token                  = data.google_client_config.current.access_token
    cluster_ca_certificate = base64decode(data.google_container_cluster.target.master_auth[0].cluster_ca_certificate)
  }
}

locals {
  labels = {
    application = "platform"
    environment = var.environment
    region      = var.region
    managed_by  = "terragrunt"
  }

  application_values = {
    repoURL        = var.git_repository_url
    targetRevision = var.git_revision
    environment    = var.environment
    region         = var.region
    orderService = {
      image = {
        repository = var.image_repository
        tag        = var.image_tag
      }
      projectId = var.project_id
      region    = var.region
      negName   = var.neg_name
      database = {
        host     = var.cloudsql_private_ip
        cidr     = var.database_service_cidr
        secretId = var.database_password_secret_id
      }
      redis = {
        host         = var.redis_host
        port         = var.redis_port
        authSecretId = var.redis_auth_secret_id
        caSecretId   = var.redis_ca_secret_id
      }
    }
  }
}

resource "random_password" "rancher_bootstrap" {
  length  = 32
  special = false
}

resource "google_secret_manager_secret" "rancher_bootstrap" {
  project   = var.project_id
  secret_id = "order-${var.environment}-rancher-bootstrap"

  replication {
    auto {}
  }

  labels = local.labels
}

resource "google_secret_manager_secret_version" "rancher_bootstrap" {
  secret      = google_secret_manager_secret.rancher_bootstrap.id
  secret_data = random_password.rancher_bootstrap.result
}

resource "helm_release" "cert_manager" {
  name             = "cert-manager"
  namespace        = "cert-manager"
  create_namespace = true
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  version          = var.cert_manager_chart_version
  atomic           = true
  wait             = true
  timeout          = 900

  values = [yamlencode({
    crds = {
      enabled = true
    }
    replicaCount = 3
    webhook = {
      replicaCount = 3
    }
    cainjector = {
      replicaCount = 2
    }
  })]
}

resource "helm_release" "rancher" {
  name             = "rancher"
  namespace        = "cattle-system"
  create_namespace = true
  repository       = "https://releases.rancher.com/server-charts/stable"
  chart            = "rancher"
  version          = var.rancher_chart_version
  atomic           = true
  wait             = true
  timeout          = 1200

  values = [yamlencode({
    hostname          = var.rancher_hostname
    bootstrapPassword = random_password.rancher_bootstrap.result
    replicas          = 3
    ingress = {
      enabled = false
    }
    service = {
      type = "ClusterIP"
    }
    antiAffinity = "preferred"
  })]

  depends_on = [helm_release.cert_manager]
}

resource "helm_release" "argocd" {
  name             = "argocd"
  namespace        = "argocd"
  create_namespace = true
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = var.argocd_chart_version
  atomic           = true
  wait             = true
  timeout          = 1200

  values = [yamlencode({
    controller = {
      replicas = 2
    }
    server = {
      replicas = 2
      service = {
        type = "ClusterIP"
      }
      ingress = {
        enabled  = false
        hostname = var.argocd_hostname
      }
    }
    repoServer = {
      replicas = 2
    }
    applicationSet = {
      replicas = 2
    }
    redis = {
      enabled = false
    }
    "redis-ha" = {
      enabled = true
    }
  })]
}

resource "helm_release" "root_application" {
  name      = "order-service-root"
  namespace = "argocd"
  chart     = "${path.module}/charts/root-application"
  atomic    = true
  wait      = true
  timeout   = 600

  values = [yamlencode({
    name           = "order-service-${var.environment}"
    repoURL        = var.git_repository_url
    targetRevision = var.git_revision
    appValues      = local.application_values
  })]

  depends_on = [helm_release.argocd]
}
