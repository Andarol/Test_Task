locals {
  environment = "production"
  project_id  = get_env("GCP_PROJECT_ID", "REPLACE_WITH_PRODUCTION_PROJECT_ID")

  common_inputs = {
    project_id  = local.project_id
    environment = local.environment
  }

  region             = "europe-west3"
  git_repository_url = "https://github.com/Andarol/Test_Task.git"
  git_revision       = "main"
  rancher_hostname   = "rancher.production.internal"
  argocd_hostname    = "argocd.production.internal"

  database_region       = "europe-west3"
  database_service_cidr = "10.190.0.0/16"
  database_tier         = "db-custom-2-7680"
  database_disk_size_gb = 100
  cache_region          = "europe-west3"
  cache_memory_size_gb  = 5

  regions = {
    europe-west3 = {
      zones              = ["europe-west3-a", "europe-west3-b"]
      node_cidr          = "10.110.0.0/20"
      pod_cidr           = "10.120.0.0/16"
      service_cidr       = "10.121.0.0/20"
      master_cidr        = "172.17.0.0/28"
      gke_machine_type   = "e2-standard-4"
      min_nodes_per_zone = 1
      max_nodes_per_zone = 3
      capacity_scaler    = 1.0
    }

  }

  domain_names                    = []
  waf_preview                     = false
  waf_rate_limit_requests_per_min = 1200
}
