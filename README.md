# Order Service — private GKE with independent infrastructure and GitOps releases

The repository has three deliberately separate lifecycles:

1. `environments/bootstrap/runner` creates the shared VPN, registry, and persistent self-hosted GitHub runner once.
2. `.github/workflows/provision-infrastructure.yml` applies exactly one long-lived Terragrunt component selected by the operator: `foundation`, `cluster`, `gitops`, or `global`.
3. `.github/workflows/deploy.yml` builds an immutable application image and changes only the matching file under `gitops/environments/`. Argo CD then reconciles the custom Helm chart from Git.

An application release never applies Terraform and never calls `kubectl apply`. No container is started on the operator laptop; image builds run on the GCP self-hosted runner.

## Architecture

```mermaid
flowchart TB
  Admin["Administrator"] -->|"one WireGuard VPN"| VPN["WireGuard gateway"]
  Runner["Persistent self-hosted GitHub runner"] --> Registry["Artifact Registry"]
  Runner --> StageAPI["Staging private GKE API"]
  Runner --> ProdAPI["Production private GKE API"]
  VPN --> StageAPI
  VPN --> ProdAPI

  subgraph Staging["Staging — europe-west3"]
    StageAPI --> StageWorkers["Workers in zones a + b + c"]
    StageWorkers --> StageArgo["Argo CD"]
    StageWorkers --> StageRancher["Rancher"]
    StageWorkers --> StageApp["order-service custom chart"]
    StageApp --> StageDB["Regional HA Cloud SQL"]
    StageApp --> StageRedis["Redis cache"]
  end

  subgraph Production["Production — europe-west3"]
    ProdAPI --> ProdWorkers["Workers in zones a + b + c"]
    ProdWorkers --> ProdArgo["Argo CD"]
    ProdWorkers --> ProdRancher["Rancher"]
  end

  Git["gitops/environments/ENV/values.yaml"] --> StageArgo
  Git --> ProdArgo
```

GKE manages the regional control planes. Terraform manages a separate autoscaling worker pool spread across three zones. The cluster state is long-lived and is not touched by normal application releases.

## Repository layout

```text
environments/
├── bootstrap/runner/terragrunt.hcl          # one-time runner/VPN bootstrap
├── staging/
│   ├── foundation/terragrunt.hcl            # Cloud SQL and Redis
│   ├── europe-west3/
│   │   ├── cluster/terragrunt.hcl           # GKE control plane and workers
│   │   └── gitops/terragrunt.hcl            # Rancher, Argo CD, root Application
│   └── global/terragrunt.hcl                # load balancer and WAF
└── production/                              # same isolated states

terraform/stacks/
├── management/
├── foundation/
├── cluster/
├── gitops/
└── global/

gitops/environments/
├── staging/values.yaml
└── production/values.yaml

charts/
├── app-of-apps/
└── order-service/
```

For compatibility with the already-created infrastructure, the renamed `cluster` and `gitops` directories retain the existing GCS state prefixes:

```text
staging/europe-west3/terraform.tfstate
staging/europe-west3/platform/terraform.tfstate
production/europe-west3/terraform.tfstate
production/europe-west3/platform/terraform.tfstate
```

The directory names are now explicit while existing cloud resources remain attached to their original states.

## One-time runner bootstrap

Requirements are Terraform 1.10+, Terragrunt 1.0.4+, authenticated `gcloud` and `gh`, plus `wg` for generating the administrator key. Docker is not required locally.

```bash
umask 077
wg genkey | tee ~/.config/wireguard/order-client.key |
  wg pubkey > ~/.config/wireguard/order-client.pub

export GCP_PROJECT_ID="project-03272afe-c622-4c2b-868"
export WIREGUARD_CLIENT_PUBLIC_KEY="$(cat ~/.config/wireguard/order-client.pub)"
make bootstrap-runner
```

UDP/51820 accepts connections from dynamic public addresses because the administrator uses DHCP. WireGuard still admits only the configured cryptographic peer.

## Infrastructure provisioning

Run `Manual infrastructure component` and choose one environment and one component. Components are intentionally not chained, so changing GitOps does not recreate the cluster and changing the application does not run Terragrunt.

Initial order for an environment:

```text
foundation → cluster → gitops → application release → global
```

`global` is applied after the first Argo CD sync because its load-balancer backend reads the NEGs created by the application Service.

Production application reconciliation is disabled in `gitops/environments/production/values.yaml` until its foundation outputs are recorded there. This prevents Argo CD from deploying with blank database or Redis endpoints.

## Application release

Run `Manual application release` and choose `staging` or `production`. The reusable environment workflow:

```text
verify Go code → build/push GIT_SHA → update gitops values → push main
                                                        ↓
                                                 Argo CD sync
```

Only the image tag changes during a normal release. Terraform owns Rancher, Argo CD, and the root Application; Argo CD exclusively owns the application chart and observability resources.

## Private access

Connect WireGuard, fetch internal cluster credentials, and open local tunnels:

```bash
gcloud container clusters get-credentials order-staging-europe-west3-gke \
  --region=europe-west3 --internal-ip

kubectl -n cattle-system port-forward service/rancher 9443:443
kubectl -n argocd port-forward service/argocd-server 8443:443
```

Production uses `order-production-europe-west3-gke`. Rancher bootstrap passwords are stored in Secret Manager as `order-staging-rancher-bootstrap` and `order-production-rancher-bootstrap`.

## Static checks

```bash
go test -race ./...
go vet ./...
terraform fmt -check -recursive terraform
make terraform-validate
terragrunt hcl fmt --check
make charts-validate
```
