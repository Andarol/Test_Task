# Order service infrastructure

This repository contains a small, reviewable GCP platform for the SRE assessment. It is intentionally limited to one region (`europe-west3`) and two zones so the design can be demonstrated without a large footprint.

## Layout

```text
terraform/modules/networking   custom VPC, GKE/SQL subnets, NAT, firewall, PSA
terraform/modules/gke           private regional GKE, Workload Identity, Binary Authorization
terraform/modules/cloudsql      private PostgreSQL 15 HA, backups, Secret Manager credentials
terraform/modules/bastion       separate IAP-only Compute Engine bastion
terraform/modules/platform      Argo CD and Rancher Helm releases
terraform/stacks/infrastructure composition of the infrastructure modules
terraform/stacks/platform       cluster management applications
environments/<env>/europe-west3 Terragrunt entry points and isolated GCS prefixes
observability/                  SLO recording rules, alerts, Alertmanager routing, dashboard
.github/runner-image            custom self-hosted runner image with deployment tooling
.github/workflows/runner-*.yml   runner image build and ARC runner deployment
.github/workflows/build.yml      app lint, test, image build, and staging dispatch
.github/workflows/deploy.yml     environment deployment workflow
```

Monitoring and GitHub Actions are deliberately not included yet. They can be added after the infrastructure code is reviewed. Application delivery is expected to use Argo CD from the platform stack.

## Bootstrap state storage

The state bucket is created once with a local bootstrap state. It is not destroyed or recreated by every environment deployment:

```bash
export GCP_PROJECT_ID=project-03272afe-c622-4c2b-868
export TF_STATE_BUCKET_STAGE="${GCP_PROJECT_ID}-stage-tfstate"
export TF_STATE_BUCKET_PROD="${GCP_PROJECT_ID}-prod-tfstate"
export GOOGLE_OAUTH_ACCESS_TOKEN="$(gcloud auth print-access-token)"
terragrunt run --working-dir environments/bootstrap/state init
terragrunt run --working-dir environments/bootstrap/state apply -auto-approve
```

The generated GCS backend uses a separate bucket for each environment, a separate prefix for each Terragrunt stack, and native GCS locking.

State is separated by environment at bucket level:

| Environment | State bucket |
| --- | --- |
| staging | `gs://$TF_STATE_BUCKET_STAGE` |
| production | `gs://$TF_STATE_BUCKET_PROD` |

Each stack also has its own state object inside that environment bucket:

| Terragrunt entry point | GCS state object |
| --- | --- |
| `environments/staging/europe-west3` | `gs://$TF_STATE_BUCKET_STAGE/staging/europe-west3/terraform.tfstate` |
| `environments/staging/europe-west3/platform` | `gs://$TF_STATE_BUCKET_STAGE/staging/europe-west3/platform/terraform.tfstate` |
| `environments/production/europe-west3` | `gs://$TF_STATE_BUCKET_PROD/production/europe-west3/terraform.tfstate` |
| `environments/production/europe-west3/platform` | `gs://$TF_STATE_BUCKET_PROD/production/europe-west3/platform/terraform.tfstate` |

The backend itself is declared in `terraform/backend.tf`; Terragrunt injects the bucket and prefix values into generated `backend.tf` files during `terragrunt init`.

## Deploy infrastructure

Use a restricted administrator CIDR for the private control-plane endpoint. Do not use `0.0.0.0/0`.

```bash
export GKE_ADMIN_CIDR="10.10.10.10/32"
terragrunt run --working-dir environments/staging/europe-west3 init
terragrunt run --working-dir environments/staging/europe-west3 plan
terragrunt run --working-dir environments/staging/europe-west3 apply
```

Production uses the same modules and a different state prefix:

```bash
terragrunt run --working-dir environments/production/europe-west3 plan
terragrunt run --working-dir environments/production/europe-west3 apply
```

The application node pool is separate from the removed default pool and autoscales from one to four `e2-medium` nodes across two zones. GKE nodes and the bastion have no public IP addresses. The bastion is reached through IAP and has a least-privilege cluster viewer service account; it is the place to run platform operations against the private endpoint.

## Install Argo CD and Rancher

Run this Terragrunt stack from the bastion (or from a workstation connected through an IAP tunnel to the private endpoint) after the infrastructure stack is ready:

```bash
gcloud compute ssh order-staging-europe-west3-bastion \
  --zone=europe-west3-a --tunnel-through-iap
terragrunt run --working-dir environments/staging/europe-west3/platform init
terragrunt run --working-dir environments/staging/europe-west3/platform apply
```

The platform stack installs Argo CD and Rancher with Helm and stores the Rancher bootstrap password in Secret Manager. The Helm provider connects to the private GKE endpoint using the VM's identity; no service-account key files are used.

## Self-hosted runners and private image builds

Application CI/CD jobs run on self-hosted runners labeled `gke-private`. These runners are deployed into the private GKE subnet through Actions Runner Controller, so pushes to Artifact Registry use the regional Artifact Registry hostname from inside the VPC. The GKE subnet has Private Google Access enabled, so Artifact Registry traffic follows the private Google APIs path instead of relying on a NAT public IP as the primary route.

Cloud NAT still exists for non-Google outbound dependencies, such as an external billing API or public package downloads.

Runner lifecycle is split into two workflows:

```bash
.github/workflows/runner-build.yml   builds and pushes the custom runner image
.github/workflows/runner-deploy.yml  deploys the ARC runner scale set to GKE
```

The runner image is stored in Artifact Registry as `github-runner:<git-sha>` and includes `gcloud`, `terraform`, `terragrunt`, `kubectl`, `helm`, and Docker CLI. Secrets and GitHub tokens are not baked into the image; they are supplied at runtime through GitHub secrets and Kubernetes secrets.

The runner build and runner deploy workflows expect one initial self-hosted bootstrap runner labeled `bootstrap`. That bootstrap runner must also live in the GCP VPC/private subnet with Private Google Access enabled; it is only used to build and deploy the first ARC runner image. After the ARC runner scale set is running, normal app workflows use `runs-on: [self-hosted, linux, gke-private]`.

## Assessment mapping

- Custom VPC, dedicated GKE and Cloud SQL subnets, Cloud NAT, and scoped firewall rules: `modules/networking`.
- Private regional GKE, separate autoscaled application pool, Workload Identity, Binary Authorization, and restricted master networks: `modules/gke`.
- PostgreSQL 15 private IP, regional HA, backups, deletion protection, and Secret Manager credentials: `modules/cloudsql`.
- Artifact Registry repository for application and runner images: `stacks/infrastructure`.
- GCS backend and per-environment prefixes: `terraform/backend.tf` and `environments/global.hcl`.
- Downstream cluster, database, subnet, bastion, and secret outputs: stack output files.
