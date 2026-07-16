.PHONY: test fmt terraform-fmt terraform-validate terragrunt-check charts-validate

test:
	go test -race ./...

fmt:
	gofmt -w app

terraform-fmt:
	terraform fmt -recursive terraform environments

terraform-validate:
	terraform -chdir=terraform/bootstrap init -backend=false
	terraform -chdir=terraform/bootstrap validate
	terraform -chdir=terraform/stacks/infrastructure init -backend=false
	terraform -chdir=terraform/stacks/infrastructure validate
	terraform -chdir=terraform/stacks/platform init -backend=false
	terraform -chdir=terraform/stacks/platform validate

terragrunt-check:
	terragunt hcl fmt --check

charts-validate:
	helm lint charts/order-service
	helm lint charts/app-of-apps
	helm template order-service charts/order-service >/dev/null
	helm template app-of-apps charts/app-of-apps >/dev/null
