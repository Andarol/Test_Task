include "global" {
  path   = find_in_parent_folders("global.hcl")
  expose = true
}

locals {
  environment = "production"
}

terraform {
  source = "../../../../terraform//stacks/platform"
}

inputs = {
  project_id   = include.global.locals.project_id
  environment  = local.environment
  region       = include.global.locals.region
  cluster_name = "order-${local.environment}-${include.global.locals.region}-gke"
}
