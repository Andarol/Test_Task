# Review Findings

## Buggy Terraform

| # | Location | Problem | Impact | Fix |
|---|---|---|---|---|
| 1 | `google_sql_database_instance.postgres.settings.ip_configuration.ipv4_enabled` | Cloud SQL public IPv4 is enabled. | The database is reachable through a public endpoint, increasing exposure and violating the private-IP-only requirement. | Set `ipv4_enabled = false`, configure `private_network`, and use Private Service Access from the VPC. |
| 2 | `google_sql_database_instance.postgres.settings.backup_configuration.enabled` | Automated backups are disabled. | A failed migration, bad deploy, or data corruption event may not be recoverable to a recent point in time. | Enable automated backups and point-in-time recovery with an appropriate retention policy. |
| 3 | `google_sql_database_instance.postgres.deletion_protection` | Deletion protection is disabled. | Accidental Terraform changes or manual actions can delete the production database. | Set `deletion_protection = true` and add Terraform `lifecycle { prevent_destroy = true }` for production safety. |
| 4 | `google_container_cluster.main.remove_default_node_pool` | The default node pool is kept. | Workloads may run on an unmanaged/default pool instead of a separately configured application node pool with the intended sizing, labels, service account, and security settings. | Set `remove_default_node_pool = true` and create an explicit application node pool with autoscaling and a least-privilege node service account. |
| 5 | `google_container_cluster.main.master_authorized_networks_config.cidr_blocks.cidr_block` | The control plane is authorized from `0.0.0.0/0`. | Anyone on the internet can attempt to reach the GKE control plane endpoint, increasing attack surface. | Restrict authorized networks to known admin, VPN, or bastion CIDRs only. |

## Buggy Manifest

| # | Location | Problem | Impact | Fix |
|---|---|---|---|---|
| 1 | `spec.replicas` | The deployment runs only one replica. | A single pod cannot provide high availability, cannot tolerate node disruption, and cannot support zero-downtime rollout for the expected traffic. | Use a production baseline replica count with HPA, for example 4-6 replicas depending on environment and load testing. |
| 2 | `containers[0].image` | The image uses the mutable `latest` tag. | Deployments are not reproducible; the same manifest can run different images over time and rollbacks become unreliable. | Use an immutable image tag, such as the git SHA pushed to Artifact Registry. |
| 3 | `containers[0].resources` | Only large limits are set, with no resource requests. | Kubernetes cannot schedule the pod based on guaranteed capacity, and a 4 CPU / 4 GiB limit can waste or distort capacity planning in a shared cluster. | Set realistic CPU and memory requests and moderate limits based on load testing, for example `500m`/`512Mi` requests and `1` CPU/`1Gi` limits. |
| 4 | `containers[0].livenessProbe` | Liveness checks `/readyz`, starts immediately, and fails after one failure. | Temporary dependency issues can restart healthy processes; startup or readiness delays can cause crash loops. | Use `/healthz` for liveness, `/readyz` for readiness, add a startup probe, and use sane thresholds/timeouts. |
| 5 | `containers[0].env.DB_PASSWORD.value` | The database password is hardcoded in the manifest. | Credentials are exposed in git, Kubernetes object history, CI logs, and anyone with manifest access. | Store credentials in GCP Secret Manager, sync them into Kubernetes Secrets through Workload Identity, and reference them with `secretKeyRef`. |

## Buggy Pipeline

| # | Location | Problem | Impact | Fix |
|---|---|---|---|---|
| 1 | `on.push.branches: ["*"]` | The deployment pipeline runs on every branch push. | Any feature branch can deploy to production, bypassing review, merge policy, and environment promotion. | Run deploys only from `main` after merge; use PR workflows for validation and `terraform plan`. |
| 2 | `jobs.deploy.runs-on: ubuntu-latest` | The workflow uses a GitHub-hosted runner instead of the required self-hosted runner. | The job does not run inside the controlled private GCP/VPC runner environment and cannot rely on private access patterns or preconfigured deployment tooling. | Use self-hosted runners with explicit labels, for example `[self-hosted, linux, gke-private]`. |
| 3 | `Build and push` / `Deploy to production` image tag | The image is built, pushed, and deployed as `order-service:latest`. | The deployed artifact is mutable and not traceable to a specific commit; rollback and incident investigation become unreliable. | Tag images with the immutable git SHA and push to Artifact Registry, then deploy that exact SHA tag. |
| 4 | Step order and deployment controls | The workflow deploys to production before tests and has no plan/apply approval, staging gate, smoke test, production approval, or rollback. | Broken code can reach production automatically, Terraform changes are not reviewed, and failed deployments have no automated recovery. | Run lint/test first with race detection, then build, Terraform plan/apply with manual approval, deploy staging, wait for rollout, smoke test `/healthz` and `/readyz`, require production approval, and roll back on failure. |
