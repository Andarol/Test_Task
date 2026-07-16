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
    application = "gitops"
    environment = var.environment
    region      = var.region
    managed_by  = "terragrunt"
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

resource "helm_release" "arc_controller" {
  count = var.arc_enabled ? 1 : 0

  name             = "arc"
  namespace        = "arc-systems"
  create_namespace = true
  repository       = "oci://ghcr.io/actions/actions-runner-controller-charts"
  chart            = "gha-runner-scale-set-controller"
  version          = var.arc_chart_version
  atomic           = true
  wait             = true
  timeout          = 900

  values = [yamlencode({
    replicaCount = 1
    resources = {
      requests = {
        cpu    = "50m"
        memory = "128Mi"
      }
      limits = {
        cpu    = "250m"
        memory = "256Mi"
      }
    }
  })]
}

resource "helm_release" "arc_runner_set" {
  count = var.arc_enabled ? 1 : 0

  name             = "arc-${var.environment}"
  namespace        = "arc-runners"
  create_namespace = true
  repository       = "oci://ghcr.io/actions/actions-runner-controller-charts"
  chart            = "gha-runner-scale-set"
  version          = var.arc_chart_version
  atomic           = true
  wait             = true
  timeout          = 900

  values = [yamlencode({
    githubConfigUrl = var.git_repository_url
    githubConfigSecret = {
      github_token = var.arc_github_token
    }
    minRunners = 0
    maxRunners = 1
    controllerServiceAccount = {
      namespace = "arc-systems"
      name      = "arc-gha-rs-controller"
    }
    template = {
      spec = {
        initContainers = [
          {
            name    = "init-dind-externals"
            image   = var.arc_runner_image
            command = ["cp", "-r", "/home/runner/externals/.", "/home/runner/tmpDir/"]
            volumeMounts = [
              {
                name      = "dind-externals"
                mountPath = "/home/runner/tmpDir"
              }
            ]
          },
          {
            name  = "dind"
            image = "docker:27.5.1-dind"
            args  = ["dockerd", "--host=unix:///var/run/docker.sock", "--group=$(DOCKER_GROUP_GID)"]
            env = [{
              name  = "DOCKER_GROUP_GID"
              value = "123"
            }]
            securityContext = {
              privileged = true
            }
            restartPolicy = "Always"
            startupProbe = {
              exec = {
                command = ["docker", "info"]
              }
              failureThreshold    = 24
              initialDelaySeconds = 0
              periodSeconds       = 5
            }
            volumeMounts = [
              {
                name      = "work"
                mountPath = "/home/runner/_work"
              },
              {
                name      = "dind-sock"
                mountPath = "/var/run"
              },
              {
                name      = "dind-externals"
                mountPath = "/home/runner/externals"
              }
            ]
          }
        ]
        containers = [{
          name    = "runner"
          image   = var.arc_runner_image
          command = ["/home/runner/run.sh"]
          env = [
            {
              name  = "DOCKER_HOST"
              value = "unix:///var/run/docker.sock"
            },
            {
              name  = "RUNNER_WAIT_FOR_DOCKER_IN_SECONDS"
              value = "120"
            }
          ]
          volumeMounts = [
            {
              name      = "work"
              mountPath = "/home/runner/_work"
            },
            {
              name      = "dind-sock"
              mountPath = "/var/run"
            },
            {
              name      = "dind-externals"
              mountPath = "/home/runner/externals"
            }
          ]
          resources = {
            requests = {
              cpu    = "500m"
              memory = "1Gi"
            }
            limits = {
              cpu    = "1"
              memory = "2Gi"
            }
          }
        }]
        volumes = [
          {
            name     = "work"
            emptyDir = {}
          },
          {
            name     = "dind-sock"
            emptyDir = {}
          },
          {
            name     = "dind-externals"
            emptyDir = {}
          }
        ]
      }
    }
  })]

  depends_on = [helm_release.arc_controller]
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
    valuesFile     = var.gitops_values_file
  })]

  depends_on = [helm_release.argocd]
}
