# Review of the supplied snippets

The requested totals are preserved as five Terraform findings, five Kubernetes findings, and four pipeline findings. Closely related defects are grouped when they share one impact and remediation; otherwise the snippets contain more individually countable defects than the stated totals.

## Terraform — five finding groups

### TF-1 — undersized and non-HA Cloud SQL configuration

- **Location:** `google_sql_database_instance.postgres.settings`, `tier = "db-f1-micro"`, with no `availability_type`.
- **Problem:** a shared-core micro instance has insufficient predictable capacity for a production order service, and the instance is zonal rather than regional HA.
- **Impact:** CPU/memory saturation, connection pressure, and a single-zone or instance failure can make order processing unavailable.
- **Fix:** use an evidence-based custom tier such as `db-custom-2-7680`, set `availability_type = "REGIONAL"`, enable SSD autosizing, and validate the choice with load testing.

### TF-2 — public database networking

- **Location:** `settings.ip_configuration.ipv4_enabled = true`, with no `private_network`.
- **Problem:** Cloud SQL receives a public IPv4 address and is not connected through Private Service Access.
- **Impact:** unnecessary internet exposure and failure to meet the private-only requirement.
- **Fix:** set `ipv4_enabled = false`, reserve a `VPC_PEERING` range, create `google_service_networking_connection`, and assign the custom VPC through `private_network`.

### TF-3 — backups disabled

- **Location:** `settings.backup_configuration.enabled = false`.
- **Problem:** automated backups and point-in-time recovery are absent.
- **Impact:** operator mistakes, corruption, or destructive writes can cause unrecoverable order data loss and excessive RPO.
- **Fix:** enable backups, PITR, transaction-log retention, a defined backup window, and at least 30 retained backups; regularly test restoration.

### TF-4 — destructive database changes are allowed

- **Location:** `deletion_protection = false`.
- **Problem:** an ordinary Terraform change or destroy can delete the database instance.
- **Impact:** accidental permanent data loss and a prolonged outage.
- **Fix:** set Cloud SQL deletion protection and Terraform `lifecycle.prevent_destroy` to true. Require a reviewed two-step change to disable either guard.

### TF-5 — insecure and unmanaged GKE baseline

- **Location:** `remove_default_node_pool = false` and `master_authorized_networks_config` containing `0.0.0.0/0`; the cluster also lacks private-node, Workload Identity, and Binary Authorization configuration.
- **Problem:** the default pool remains unmanaged as part of the cluster, and the Kubernetes API is authorized from the entire internet. Required workload identity and admission controls are absent.
- **Impact:** excessive control-plane exposure, inconsistent node lifecycle, possible key-based credentials, and unverified images.
- **Fix:** remove the default pool, manage a separate autoscaled application pool, enable private nodes and a private endpoint, restrict authorized CIDRs, enable Workload Identity Federation and Binary Authorization.

## Kubernetes — five finding groups

### K8S-1 — invalid Deployment selector and pod labels

- **Location:** `spec` has no `selector`; `spec.template.metadata.labels` is also absent.
- **Problem:** an `apps/v1` Deployment requires a selector that matches immutable pod-template labels.
- **Impact:** the API server rejects the manifest, so nothing is deployed.
- **Fix:** add stable matching labels under `spec.selector.matchLabels` and `spec.template.metadata.labels`.

### K8S-2 — no high availability

- **Location:** `replicas: 1`.
- **Problem:** one pod is a single point of failure and cannot provide zero-downtime rollouts.
- **Impact:** a crash, eviction, node upgrade, or rollout interrupts the service.
- **Fix:** start with at least four replicas across zones/nodes, add a PDB and topology spread constraints, then tune with measured capacity and HPA.

### K8S-3 — mutable image and unsafe resource model

- **Location:** `image: order-service:latest` and `resources` contains only 4-core/4-GiB limits.
- **Problem:** `latest` is not reproducible; requests are absent, while oversized limits permit noisy-neighbor bursts and make HPA utilization undefined.
- **Impact:** unpredictable rollouts, poor scheduling, possible node contention, and incorrect autoscaling.
- **Fix:** deploy an immutable Git SHA or digest and define evidence-based requests and limits, for example 250m/256Mi requests and 1 CPU/512Mi limits as an initial benchmark.

### K8S-4 — probes conflate liveness and readiness

- **Location:** `livenessProbe` calls `/readyz`, starts immediately, and fails after one error; there is no readiness probe.
- **Problem:** a temporary dependency/readiness failure restarts a healthy process, and unready pods remain eligible for traffic because Kubernetes has no readiness signal.
- **Impact:** restart loops and 5xx responses can amplify a dependency incident or rollout failure.
- **Fix:** use `/healthz` for a conservative liveness probe, `/readyz` for readiness, and a startup probe for initialization. Use nonzero periods/timeouts and multiple failures.

### K8S-5 — hardcoded credential

- **Location:** `env.DB_PASSWORD.value = "supersecret123"`.
- **Problem:** the password is committed in plaintext and appears in Deployment history and API responses.
- **Impact:** credential compromise, difficult rotation, and audit/compliance failure.
- **Fix:** store the generated password in Secret Manager, grant the pod KSA least-privilege access through Workload Identity Federation, synchronize it with GKE SecretSync, and reference it using `secretKeyRef` or a mounted volume.

## GitHub Actions — four finding groups

### CI-1 — unsafe trigger and missing PR workflow

- **Location:** `on.push.branches: ["*"]`.
- **Problem:** every branch deploys, while pull requests receive no plan or validation.
- **Impact:** unreviewed code can reach production and infrastructure changes are invisible before merge.
- **Fix:** run validation and Terraform plan on PRs; allow apply/deploy only for merges or dispatches on `main`, with concurrency controls.

### CI-2 — unauthenticated mutable image publication

- **Location:** `docker build/push order-service:latest`.
- **Problem:** no Artifact Registry hostname, Google authentication, immutable SHA tag, provenance, or explicit builder setup is present.
- **Impact:** push normally fails; if it succeeds against an unintended registry, deployments remain non-reproducible and vulnerable to tag replacement.
- **Fix:** authenticate with GitHub OIDC/WIF, push `${REGION}-docker.pkg.dev/...:${GITHUB_SHA}`, and produce provenance/SBOM metadata.

### CI-3 — tests run after production deployment

- **Location:** production `kubectl set image` precedes `go test ./...`.
- **Problem:** untested code is deployed, and race detection is missing.
- **Impact:** known failures can become customer-impacting before CI reports them.
- **Fix:** run formatting, vet, and `go test -race ./...` first; make build, plan, apply, and deployment depend on successful tests.

### CI-4 — no controlled infrastructure or release progression

- **Location:** the single `deploy` job has no Terraform, staging, rollout wait, smoke tests, approvals, or rollback.
- **Problem:** it mutates production directly with no auditable infrastructure plan or safety gates.
- **Impact:** partial deployments and failed releases remain live, with no automatic recovery or human authorization.
- **Fix:** implement `test → build → plan/apply → staging rollout → smoke → production approval → rollout`, use protected GitHub Environments, and call `kubectl rollout undo` when production rollout or smoke verification fails.
