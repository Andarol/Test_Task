.PHONY: test fmt terraform-fmt terraform-validate terragrunt-check charts-validate bootstrap-management bootstrap-runner

bootstrap-management:
	./scripts/bootstrap-management.sh

bootstrap-runner: bootstrap-management

test:
	go test -race ./...

fmt:
	gofmt -w app

terraform-fmt:
	terraform fmt -recursive terraform

terraform-validate:
	terraform -chdir=terraform/stacks/management init -backend=false
	terraform -chdir=terraform/stacks/management validate
	terraform -chdir=terraform/stacks/foundation init -backend=false
	terraform -chdir=terraform/stacks/foundation validate
	terraform -chdir=terraform/stacks/cluster init -backend=false
	terraform -chdir=terraform/stacks/cluster validate
	terraform -chdir=terraform/stacks/global init -backend=false
	terraform -chdir=terraform/stacks/global validate
	terraform -chdir=terraform/stacks/gitops init -backend=false
	terraform -chdir=terraform/stacks/gitops validate
	terraform -chdir=terraform/bootstrap init -backend=false
	terraform -chdir=terraform/bootstrap validate

terragrunt-check:
	terragrunt hcl fmt --check

charts-validate:
	helm lint charts/order-service
	helm lint charts/app-of-apps
	helm lint terraform/stacks/gitops/charts/root-application
	helm template order-service charts/order-service >/dev/null
	helm template app-of-apps charts/app-of-apps >/dev/null
	helm template root-application terraform/stacks/gitops/charts/root-application >/dev/null
