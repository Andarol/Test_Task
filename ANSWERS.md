# SRE Assessment Answers

## Part 2: Kubernetes manifests

### Deployment sizing

The baseline replica count is set to 6 pods for `order-service`.

The service is expected to handle about 5,000 requests/minute at peak, which is about 83 requests/second. A 6-pod baseline gives roughly 14 requests/second per pod before autoscaling. That leaves enough steady-state headroom for short bursts, slow external billing API calls, and one pod being unavailable during a rollout or node event.

The HPA can scale from 6 to 40 replicas. This keeps the normal footprint modest while allowing peak traffic, retry storms, or dependency latency to be absorbed without immediately exhausting pod capacity.

### Resource requests and limits

Each pod requests `500m` CPU and `512Mi` memory and is limited to `1` CPU and `1Gi` memory.

The request reserves enough CPU for a Go HTTP service doing JSON handling, database connectivity, Redis cache access, metrics, and external API waits without being too expensive at the 6-pod baseline. The CPU limit allows short bursts up to one full core per pod while preventing one busy pod from starving the node.

The memory request gives room for the Go runtime, connection buffers, TLS Redis calls, metrics, and normal heap growth. The `1Gi` limit gives burst room while still surfacing leaks or abnormal memory growth quickly.

### Probes

The liveness probe uses `/healthz` because it only verifies that the process and HTTP server are alive. It should not depend on PostgreSQL or external systems, otherwise a database issue could cause unnecessary restarts.

The readiness probe uses `/readyz` because the service implementation checks internal readiness and PostgreSQL TCP connectivity there. If the database is unreachable, the pod is removed from service endpoints instead of receiving traffic it cannot handle.

A startup probe is included so slower cold starts do not trigger liveness failures before the process is ready.

### Rolling updates

The deployment uses `maxUnavailable: 0` and `maxSurge: 2`.

This keeps all existing ready pods serving traffic while new pods start and pass readiness checks. `minReadySeconds: 15`, graceful termination, and a `preStop` delay give the load balancer and endpoint controller time to stop sending new requests to terminating pods.

### HPA policy

CPU target is `65%`, which gives the autoscaler enough signal before pods reach saturation. Memory target is `75%`, which prevents sustained memory pressure while avoiding premature scaling for normal Go heap variation.

Scale-up allows fast reaction with either 100% growth or up to 6 pods per minute. Scale-down uses a 300-second stabilization window and conservative policies to prevent flapping after short traffic spikes.

### PDB

The PodDisruptionBudget uses `minAvailable: 75%`.

With 6 baseline replicas, at least 5 pods must remain available during voluntary disruptions such as node upgrades or maintenance. This keeps the service available while still allowing controlled infrastructure operations to proceed.

### Secrets

Application credentials are not hardcoded in manifests.

`k8s/secret-sync.yaml` defines GKE Secret Manager sync resources that materialize Kubernetes Secrets from Secret Manager. The deployment consumes only those Kubernetes Secrets. Access is granted through the Kubernetes service account and GKE Workload Identity, so no service account key files are needed.

## Questions

### Q1: Private GKE nodes pulling images from Artifact Registry

The pod does not pull the image itself. The kubelet on the private GKE node pulls the image before starting the container.

Network path with private access to Google APIs:

1. The scheduler assigns the pod to a private GKE node in the GKE node subnet.
2. The kubelet/container runtime on that node reads the image reference, for example `europe-west3-docker.pkg.dev/project-03272afe-c622-4c2b-868/order-service/order-service:<sha>`.
3. The node uses its node service account to request an access token from Google metadata server / IAM credentials.
4. The node resolves `europe-west3-docker.pkg.dev` through Cloud DNS / Google DNS.
5. Traffic leaves the private node through the custom VPC subnet route.
6. The GKE node subnet has Private Google Access enabled, or the VPC has Private Service Connect for Google APIs.
7. The request reaches Artifact Registry over Google's private network path for Google APIs. The node does not need an external IP and does not need to use a NAT public IP for Artifact Registry.
8. Artifact Registry validates the token and checks IAM permission such as `roles/artifactregistry.reader`.
9. Image layers are downloaded back to the private node over the same private Google APIs path.
10. The container runtime stores the layers locally and starts the container.

GCP components involved: private GKE node, kubelet/container runtime, node service account, IAM, metadata server / IAM credentials path, custom VPC, private GKE node subnet, subnet Private Google Access or Private Service Connect for Google APIs, Cloud DNS / Google DNS resolution, Artifact Registry, and Artifact Registry IAM.

Cloud NAT is still useful for private nodes when they need outbound access to non-Google public endpoints, such as an external billing API. It should not be the primary path for pulling images from Artifact Registry.

### Q2: Workload Identity and Secret Manager without key files

Workload Identity removes the need for JSON service account keys by binding a Kubernetes ServiceAccount to a Google Service Account.

Chain of trust:

1. The pod runs as a Kubernetes ServiceAccount, for example `order-service` in namespace `order-service`.
2. The Kubernetes ServiceAccount is annotated with the Google Service Account email.
3. GKE issues a projected Kubernetes service account token to the pod.
4. The pod or Secret Manager sync component calls the GKE metadata server from inside the cluster.
5. GKE metadata server validates the projected Kubernetes token with the Kubernetes control plane trust root.
6. IAM checks that the Kubernetes identity is allowed to impersonate the Google Service Account through Workload Identity binding.
7. Google STS / IAM credentials exchange that trusted Kubernetes identity for a short-lived Google access token.
8. The Google access token is scoped to the Google Service Account permissions.
9. Secret Manager authorizes the request using IAM, for example `roles/secretmanager.secretAccessor` on the required secrets.

No key file exists in the pod, repository, CI variables, or Kubernetes Secret. The trust chain is Kubernetes ServiceAccount → GKE Workload Identity pool → IAM binding → Google Service Account → Secret Manager IAM.

### Q3: Cloud SQL will be destroyed and recreated

I do not run `terraform apply` until the risk is understood and a recovery plan exists.

Steps in order:

1. Stop and read the plan. Identify exactly which argument forces replacement.
2. Confirm this is the intended workspace, project, environment, region, and state file.
3. Check whether the Cloud SQL instance has `deletion_protection` and Terraform `prevent_destroy` enabled. If Terraform is still planning replacement, understand why.
4. Compare Terraform state with real infrastructure using `terraform state show` and `gcloud sql instances describe`.
5. Check recent code changes for immutable fields such as region, database version downgrade, instance name, private network, or settings that force replacement.
6. If the change is accidental, revert or correct the Terraform change and rerun `terraform plan`.
7. If replacement is truly required, open a change record and get approval from the service owner and database owner.
8. Take an on-demand backup and verify automated backups are healthy.
9. Validate point-in-time recovery settings and backup retention.
10. Export or snapshot critical data if required by the recovery policy.
11. Test restore into a temporary Cloud SQL instance.
12. Prepare a migration plan: new instance, schema migration, data restore or replication, application cutover, rollback path, DNS/config changes, and validation queries.
13. Schedule a maintenance window if downtime or write freeze is possible.
14. Pause risky deploys and notify stakeholders.
15. Run `terraform apply` only after the replacement path is safe, approved, backed up, and tested.
16. After apply, verify connectivity, application readiness, database version, data integrity, backups, and monitoring.

For a production database, accidental destroy/recreate should be treated as a stop-the-line event.

### Q4: Rolling update with 3 replicas and new pod returns 500s

With readiness configured against `/readyz`, Kubernetes only sends Service traffic to pods that pass readiness.

Given `maxUnavailable: 0` and `maxSurge: 2`:

1. The Deployment starts with 3 old ready replicas.
2. A rolling update creates a new ReplicaSet.
3. Kubernetes creates one or more surge pods without deleting old pods because `maxUnavailable: 0`.
4. The new pod starts and the startup/liveness probe checks `/healthz`.
5. The readiness probe checks `/readyz`.
6. If the new pod returns 500 on `/readyz`, it is marked `NotReady`.
7. The Service endpoints do not include the new pod.
8. The old 3 pods remain ready and continue serving all traffic.
9. Because no new pod becomes available, the Deployment cannot safely scale down old pods.
10. After `progressDeadlineSeconds`, the rollout is marked failed or not progressing.

If the new pod only returns 500 for business endpoints but `/readyz` still returns 200, Kubernetes will consider it ready and it can receive traffic. That is why `/readyz` must reflect dependencies and startup correctness, not only process liveness.

The HPA does not react directly to HTTP 500s. It reacts to configured resource metrics, CPU and memory here. If the broken new pod consumes high CPU or memory, HPA may scale the Deployment. If errors happen with normal resource usage, HPA does not help. This is why rollback automation and smoke tests are required in addition to HPA.

### Q5: 30-day error budget burn rate at 10x

A 99.9% availability SLO allows 0.1% bad requests over 30 days.

30 days is 43,200 minutes, so 0.1% is 43.2 minutes of budget, usually rounded to 43 minutes.

At 1x burn, the service consumes the 30-day budget evenly across 30 days:

```text
43.2 minutes / 30 days = 1.44 minutes per day
1.44 minutes / 24 hours = 0.06 minutes per hour
```

At 10x burn:

```text
0.06 minutes/hour * 10 = 0.6 minutes/hour
```

If the full 43.2-minute budget remained:

```text
43.2 / 0.6 = 72 hours
```

So the service is consuming 0.6 minutes of error budget per hour and would exhaust a full budget in about 72 hours. If some budget has already been spent, exhaustion is sooner.

Response:

1. Treat the alert as urgent because 10x burn means a customer-impacting condition is active.
2. Acknowledge and open an incident channel.
3. Check current 5xx ratio, request volume, p99 latency, and affected pods.
4. Correlate with the latest deployment, Cloud SQL, Redis, and billing API status.
5. If caused by a new release, roll back immediately after confirmation.
6. If caused by dependency or capacity, mitigate according to the runbook.
7. Page the service owner if burn continues or projected exhaustion is under 24 hours.
8. Keep the incident open until burn rate returns below alert threshold and the error ratio remains healthy.

### Q6: CPU limit of 4 cores in a shared GKE cluster

Setting a 4-core CPU limit so the service is "never throttled" is the wrong framing.

Problems:

1. A high CPU limit does not reserve CPU. CPU requests reserve scheduling capacity; limits only cap runtime usage.
2. If the request stays low and the limit is 4 cores, Kubernetes may pack too many pods onto a node, and the service can still contend with neighbors.
3. If many pods burst toward 4 cores, they can create noisy-neighbor pressure in the shared node pool.
4. A large limit can hide inefficient code and make capacity planning harder.
5. If request is also raised to 4 cores, scheduling becomes expensive and wastes cluster capacity during normal traffic.
6. HPA based on CPU utilization uses requests as the denominator, so oversized or undersized requests distort autoscaling.

I would configure realistic CPU requests based on load testing and production metrics, for example `500m` request and `1` CPU limit for this Go service, then tune from observed p50/p95 CPU. HPA should scale before saturation, such as 60-65% CPU utilization. If CPU throttling is observed during legitimate bursts, increase the limit moderately or remove the CPU limit only if the node pool is dedicated and requests/HPA protect cluster fairness.

The goal is predictable scheduling and fair sharing, not a very large per-pod ceiling.

### Q7: Canary deployment strategy with existing Kubernetes and CI/CD

Use two versions of the same app: stable and canary. No additional tools are required if the cluster uses GKE Gateway or Ingress traffic splitting. The CI/CD workflow already builds an immutable SHA-tagged image, deploys with Helm, waits for rollout, and runs smoke tests.

Kubernetes objects:

1. `Deployment/order-service-stable` running the current production image.
2. `Deployment/order-service-canary` running the new SHA image.
3. `Service/order-service-stable` selecting stable pods.
4. `Service/order-service-canary` selecting canary pods.
5. A Gateway API `HTTPRoute` or GKE load balancer backend configuration that sends 95% traffic to stable and 5% to canary.

Flow:

1. Build workflow runs lint, test with race detection, builds the image, and pushes it to Artifact Registry with the git SHA tag.
2. Deploy workflow creates or updates the canary Deployment with the new image.
3. Wait for canary rollout and readiness:

   ```bash
   kubectl -n order-service rollout status deployment/order-service-canary --timeout=10m
   ```

4. Route 5% of traffic to canary and 95% to stable using weighted backend refs:

   ```yaml
   backendRefs:
     - name: order-service-stable
       port: 80
       weight: 95
     - name: order-service-canary
       port: 80
       weight: 5
   ```

5. Run smoke tests against `/healthz` and `/readyz`.
6. Watch canary metrics for a fixed window, for example 10-15 minutes:

   ```promql
   sum(rate(http_requests_total{service="order-service",version="canary",status_code=~"5.."}[5m]))
   /
   clamp_min(sum(rate(http_requests_total{service="order-service",version="canary"}[5m])), 0.001)
   ```

7. Automatically promote if all checks pass:
   - canary error rate is below 1%;
   - p99 latency is below 1s;
   - canary pods are ready;
   - no crash-loop alert is firing.

8. Promotion updates stable Deployment to the new image, waits for rollout, then changes traffic to 100% stable and 0% canary.

9. Automatically rollback if canary error rate exceeds 1%:
   - change traffic back to 100% stable and 0% canary;
   - scale canary to zero or delete it;
   - mark the GitHub Actions deployment failed;
   - keep the previous stable image serving traffic.

This can be implemented in the existing `deploy.yml` by adding a canary mode before production promotion: deploy canary, patch weighted route, run PromQL checks, then either patch stable to the new SHA or patch traffic back to stable.
