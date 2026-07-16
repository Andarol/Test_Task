#!/usr/bin/env bash
set -euo pipefail

required_commands=(gcloud gh terraform terragrunt)
for command_name in "${required_commands[@]}"; do
  command -v "$command_name" >/dev/null || {
    echo "Missing required command: $command_name" >&2
    exit 1
  }
done

: "${GCP_PROJECT_ID:?Set GCP_PROJECT_ID before running the one-time bootstrap}"
: "${WIREGUARD_CLIENT_PUBLIC_KEY:?Set WIREGUARD_CLIENT_PUBLIC_KEY before running the one-time bootstrap}"
: "${WIREGUARD_ALLOWED_SOURCE_CIDR:=0.0.0.0/0}"
export WIREGUARD_ALLOWED_SOURCE_CIDR

repository="Andarol/Test_Task"
root="$(git rev-parse --show-toplevel)"

export GOOGLE_OAUTH_ACCESS_TOKEN="$(gcloud auth print-access-token)"
export TF_IN_AUTOMATION=true
export TF_INPUT=false
export TERRAGRUNT_NON_INTERACTIVE=true

terraform -chdir="$root/terraform/bootstrap" init -reconfigure
terraform -chdir="$root/terraform/bootstrap" apply -auto-approve \
  -var="project_id=$GCP_PROJECT_ID" \
  -var="github_repository=$repository"

wif_provider="$(terraform -chdir="$root/terraform/bootstrap" output -raw github_workload_identity_provider)"
terraform_sa="$(terraform -chdir="$root/terraform/bootstrap" output -raw terraform_ci_service_account)"
deploy_sa="$(terraform -chdir="$root/terraform/bootstrap" output -raw deploy_ci_service_account)"

for environment in STAGING PRODUCTION; do
  gh variable set "GCP_${environment}_PROJECT_ID" --body "$GCP_PROJECT_ID" --repo "$repository"
  gh variable set "GCP_${environment}_WIF_PROVIDER" --body "$wif_provider" --repo "$repository"
  gh variable set "GCP_${environment}_TERRAFORM_SA" --body "$terraform_sa" --repo "$repository"
  gh variable set "GCP_${environment}_DEPLOY_SA" --body "$deploy_sa" --repo "$repository"
done

terragrunt run --working-dir "$root/environments/bootstrap/runner" -- apply \
  -lock-timeout=5m -auto-approve

echo "Management bootstrap complete: VPC, VPN and Artifact Registry are ready."
echo "Build the ARC runner image, then apply the GitOps component with ARC_ENABLED=true."
echo "Read the VPN server public key with:"
echo "gcloud compute instances get-serial-port-output order-wireguard --zone=europe-west3-a | grep WIREGUARD_SERVER_PUBLIC_KEY | tail -1"
