# Architecture answers

## Q1 — private GKE image pull path

The pod does not pull its own image. The kubelet asks containerd on the GKE node to resolve and pull the image before the pod can start.

1. The scheduler binds the pending pod to a node in the private GKE node pool.
2. Kubelet passes the Artifact Registry image reference to containerd.
3. The node resolves `${region}-docker.pkg.dev` through Cloud DNS using Google-provided DNS.
4. GKE obtains a short-lived OAuth token for the node's dedicated Google service account through the Compute Engine metadata server. IAM verifies that this service account has `roles/artifactregistry.reader` on the repository/project. This is node identity, not the application pod's Workload Identity.
5. The node sends HTTPS traffic from its private NIC in the custom VPC and GKE subnetwork. Private Google Access on that subnetwork lets the private source address reach Google APIs and Artifact Registry through Google networking. The VPC route and Google API frontend carry the request to Artifact Registry; Artifact Registry authorizes it with IAM and returns the manifest and image layers.
6. Containerd verifies layer digests, stores the content in its local cache, and creates the container. Binary Authorization is evaluated by GKE admission before the workload runs according to the project policy.

Cloud NAT is available for general public HTTPS egress, including the external billing API. It is not the required path for supported Google APIs when Private Google Access is used. If DNS were deliberately configured to use ordinary public endpoints without Private Google Access, the alternative path would be node private IP → VPC route → Cloud NAT/Cloud Router → Google frontend, but that is not the selected design.

Components involved are: GKE scheduler, kubelet, containerd, node service account, Compute Engine metadata server, IAM, Cloud DNS, the node NIC, custom VPC, GKE subnetwork, VPC routes, Private Google Access, Google API frontend, Artifact Registry, and Binary Authorization. Cloud NAT/Cloud Router serve non-Google public egress.

## Q2 — Workload Identity chain of trust

This design uses direct Workload Identity Federation for GKE, without a Google service-account key and without impersonating a Google service account.

1. The pod is assigned Kubernetes ServiceAccount `order-service` in namespace `order-service`.
2. GKE registers the cluster as an identity provider in the Google-managed workload identity pool `${PROJECT_ID}.svc.id.goog` and runs the GKE metadata server on each node.
3. When the GKE SecretSync controller acts for the named KSA, a short-lived, audience-bound KSA JWT is issued and signed by the Kubernetes API server.
4. The GKE metadata server exchanges that JWT with Google Security Token Service. STS verifies the cluster issuer, signature, audience, namespace, and service-account subject, then returns a short-lived federated token for the principal:

   `principal://iam.googleapis.com/projects/PROJECT_NUMBER/locations/global/workloadIdentityPools/PROJECT_ID.svc.id.goog/subject/ns/order-service/sa/order-service`

5. The Secret Manager secret IAM policy grants only that principal `roles/secretmanager.secretAccessor`.
6. Secret Manager validates the federated identity and IAM policy and returns the selected secret version over TLS.
7. The GKE SecretSync controller maps it to the `order-service-db` Kubernetes Secret. The Deployment references only the `password` key. GKE encrypts Kubernetes Secret data at rest; namespace RBAC must still be restricted.

All credentials are short-lived and derived from the pod identity. No JSON key is created, mounted, or stored in GitHub.

## Q3 — a plan wants to replace Cloud SQL

Do not apply it. The order of operations is:

1. Save the complete plan artifact, identify every force-replacement attribute, and confirm that the plan uses the correct project, backend prefix, workspace/state, provider version, and variables.
2. Check for accidental resource-address changes, module renames, state drift, provider schema changes, immutable network/region/name changes, or a resource that exists in GCP but is absent from state.
3. Pull and securely archive the current state: `terraform state pull`. Do not put it in Git because it contains sensitive values.
4. Compare `terraform state show` with the actual Cloud SQL instance. Refresh with a reviewed plan; never “fix” this using direct state-file editing.
5. Prefer a non-destructive correction: restore the previous argument, add a `moved` block, or import the existing instance into the correct address. Run a new plan and require the destroy/create actions to disappear.
6. If replacement is genuinely required, open a reviewed migration change, define RTO/RPO and rollback, select a maintenance window, freeze unrelated database changes, and notify service/database owners.
7. Verify automated backup/PITR health, take an on-demand backup, export critical data to a separately protected bucket if policy requires it, and test restore into a temporary instance.
8. Provision the replacement alongside the old instance where possible. Restore/replicate data, validate schema, extensions, users, flags, connectivity, performance, and application smoke tests.
9. Drain writes or establish a final synchronization point, switch the application secret/configuration, deploy, and verify correctness plus SLOs. Keep the old instance protected during the rollback window.
10. Only after approval and successful verification should the team deliberately remove `prevent_destroy` and Cloud SQL deletion protection in a separate reviewed apply, then execute the replacement plan. Re-enable both controls immediately afterward.

The repository sets both guards, so an unexpected replacement is blocked even if a reviewer misses it.

## Q4 — new pod returns 500 during rolling update

The Deployment uses four replicas, `maxUnavailable: 0`, `maxSurge: 1`, a startup probe on `/healthz`, and readiness on `/readyz`.

The controller creates one additional new pod while all four old pods remain. Until startup succeeds, liveness/readiness do not cause it to receive Service traffic. After startup succeeds, readiness controls whether its endpoint is published.

- If `/readyz` also returns a failure, the new pod stays unready and is not added to the Service endpoint set. No old pod is terminated because `maxUnavailable` is zero. After `progressDeadlineSeconds`, the rollout is marked failed and CI rolls back. Customers continue on the four old pods.
- If only business requests return 500 while `/readyz` incorrectly returns 200, Kubernetes considers the pod ready after `minReadySeconds`. It receives traffic, and the rollout may remove an old pod. This is why readiness must verify every dependency required to serve orders, not merely process health.

HPA does not react directly to HTTP 500 or readiness. It uses CPU and memory utilization relative to requests. It may scale indirectly if the failure increases those metrics, and it excludes not-yet-ready pod CPU during its initialization rules. Scaling changes the Deployment's desired replica count while the rollout controller continues respecting surge/unavailable limits.

## Q5 — 10x burn rate

A 99.9% 30-day objective allows `30 × 24 × 60 × 0.001 = 43.2` minutes of errors. At the sustainable 1x rate, the service consumes `43.2 / 720 = 0.06` error-budget minutes per wall-clock hour. At 10x it consumes `0.6` budget minutes per hour.

If the entire budget remains and the burn stays constant, exhaustion occurs after `43.2 / 0.6 = 72` hours. More generally, exhaustion time is `remaining budget minutes / 0.6`. The 10x rate corresponds to roughly a 1% error ratio for a 99.9% availability SLO.

At 03:00 this is a page, not a ticket: acknowledge, check customer/payment correctness, correlate rollout/database/billing events, stop a bad rollout or roll back, control retry amplification, and involve the service owner. The team should mitigate immediately because multi-window symptoms or prior budget use can make the real exhaustion time much shorter than 72 hours.

## Q6 — four-core CPU limit

A 4-core limit does not reserve four cores and does not guarantee the container will never be throttled. Scheduling uses CPU requests. With a small or absent request, many such pods can share a node and each may burst toward four cores, causing contention and noisy-neighbor latency. With a four-core request, each pod consumes an entire `e2-standard-4` node's schedulable CPU, wasting capacity. HPA CPU utilization is also calculated against requests, so an unrealistic request distorts scaling.

The initial configuration requests 250m CPU/256Mi memory and limits the pod to 1 CPU/512Mi. The request gives the scheduler and HPA a realistic baseline; the higher CPU limit permits bounded bursts without allowing one pod to dominate a node; the memory limit prevents unbounded OOM pressure. These are hypotheses: load tests should measure per-request CPU, allocation rate, p95/p99 latency, throttling, and GC behavior, then right-size requests, limits, replicas, and HPA targets. For a latency-sensitive Go service, omitting the CPU limit can also be evaluated, but only with strong requests, quotas, and monitoring in place.

## Q7 — 5% canary without another tool

A plain Kubernetes Service has no weighted routing. The available no-tool approximation is endpoint weighting: run two Deployments selected by the same Service, with 19 ready stable pods and one ready canary pod. With sufficiently distributed new connections this gives approximately 5% of traffic to the canary. HTTP keep-alive and unequal pod capacity mean it is not an exact 5%; exact weighting requires an ingress/controller or service mesh and would violate the “no additional tools” constraint.

Pipeline procedure:

1. Record the stable image digest and current replica/HPA settings. Temporarily stabilize the experiment at 19 stable replicas and suspend HPA changes that would alter the ratio.
2. Create `order-service-canary` with one replica, the same probes/resources/configuration, a `track=canary` label, and the new Git-SHA image. Keep the Service selector common to both Deployments.
3. Wait for canary readiness. If it does not become ready, delete it immediately; all traffic remains on stable endpoints.
4. Observe for a defined period, such as ten minutes, and query the canary pod series:

   ```promql
   sum(rate(http_requests_total{pod=~"order-service-canary-.*",status_code=~"5.."}[5m]))
   /
   clamp_min(sum(rate(http_requests_total{pod=~"order-service-canary-.*"}[5m])), 0.001)
   ```

   Also require readiness, sufficient request count, p99 latency, restarts, and database/billing dependency health.
5. If the error ratio exceeds 1% or another gate fails, delete the canary Deployment. That removes its endpoint and returns 100% of new traffic to stable. Record the failed SHA.
6. On success, update the stable Deployment to the canary SHA and wait for its normal zero-downtime rolling update. If that rollout fails, run `kubectl rollout undo`.
7. Delete the canary, return stable to four minimum replicas, restore HPA, and verify `/healthz`, `/readyz`, error rate, and latency.

This strategy is viable for the exercise but operationally expensive. In production I would explicitly document that 5% is statistical rather than guaranteed.
