# HighErrorRate runbook

## Alert context and impact

`HighErrorRate` fires when more than 1% of `order-service` HTTP requests return 5xx for at least five minutes.

`order-service` accepts and reads customer orders, depends on PostgreSQL, and calls an external billing API. During this alert, users may see failed order submissions, delayed confirmations, retries, or duplicate billing risk if upstream operations are not idempotent.

Treat production alerts as customer-impacting until proven otherwise. Do not paste customer payloads, credentials, access tokens, or full billing responses into public tickets or chat.

## Quick facts

| Field | Value |
|---|---|
| Service | `order-service` |
| Namespace | `order-service` |
| Primary alert | `HighErrorRate` |
| Severity | `critical` |
| SLO affected | Availability, 99.9% non-5xx over 30 days |
| Main dashboard | Grafana dashboard `Order Service SRE` |
| Related runbooks | `high-latency.md`, `database-pool-exhaustion.md`, `pod-crash-looping.md` |

## First five minutes

1. Acknowledge the alert and open an incident channel.
2. Record the alert start time, environment, current error rate, current image SHA, and on-call owner.
3. Confirm whether the alert is still firing:

   ```promql
   sum(rate(http_requests_total{service="order-service",status_code=~"5.."}[5m]))
   /
   clamp_min(sum(rate(http_requests_total{service="order-service"}[5m])), 0.001)
   ```

4. Check traffic, latency, and error budget burn together:

   ```promql
   sum by (status_code) (rate(http_requests_total{service="order-service"}[5m]))
   histogram_quantile(0.99, sum by (le) (rate(http_request_duration_seconds_bucket{service="order-service"}[5m])))
   order_service:error_budget_burn_rate:ratio_1h
   ```

5. Confirm Kubernetes state:

   ```bash
   kubectl -n order-service get deploy,rs,pods,hpa,pdb,svc -o wide
   kubectl -n order-service rollout status deployment/order-service --timeout=30s
   kubectl -n order-service get events --sort-by=.lastTimestamp | tail -n 50
   ```

6. Correlate the alert start time with deployments, node maintenance, HPA scaling, Cloud SQL events, Redis degradation, or billing-provider incidents.

## Diagnosis

### 1. Confirm scope

Check whether errors are global, limited to one pod, or caused by one HTTP path or status class:

```promql
sum by (status_code) (rate(http_requests_total{service="order-service"}[5m]))
sum by (pod) (rate(http_requests_total{service="order-service",status_code=~"5.."}[5m]))
sum by (pod) (rate(http_requests_total{service="order-service"}[5m]))
```

If errors are isolated to one pod, inspect that pod first. If errors are spread evenly, suspect a shared dependency, bad release, or capacity issue.

### 2. Check rollout and application health

```bash
kubectl -n order-service rollout history deployment/order-service
kubectl -n order-service describe deployment/order-service
kubectl -n order-service describe hpa order-service
kubectl -n order-service logs deployment/order-service --since=15m --all-containers --prefix
kubectl -n order-service logs deployment/order-service --previous --since=15m --all-containers --prefix
```

Look for panics, readiness failures, connection refused, timeouts, Secret sync failures, OOM kills, and billing API status codes.

### 3. Check PostgreSQL

```promql
(
  db_pool_connections_max{service="order-service"}
  - db_pool_connections_in_use{service="order-service"}
)
/
clamp_min(db_pool_connections_max{service="order-service"}, 1)
```

From the bastion or approved diagnostic pod, verify TCP connectivity to the private Cloud SQL address without printing credentials. In Google Cloud Monitoring, check Cloud SQL CPU, active connections, storage, failover events, lock waits, and query latency.

### 4. Check Redis cache

```promql
sum by (result) (rate(cache_requests_total{service="order-service"}[5m]))
```

Cache failures should not directly corrupt responses, but sustained Redis errors can shift read load to PostgreSQL and trigger database pressure.

### 5. Check external billing API

Inspect structured logs and provider status for timeouts, 5xx, 429, or unusually slow responses. Do not increase retries until idempotency and upstream capacity are confirmed.

## Resolution steps

Take one action at a time, then watch error rate, p99 latency, available replicas, and burn rate for at least ten minutes.

1. Let Kubernetes replace an isolated bad pod after confirming readiness/liveness failure. Avoid deleting multiple pods at once.
2. If capacity is the issue and dependencies are healthy, let HPA scale. If HPA is capped, temporarily raise `maxReplicas` only after confirming node and database capacity.
3. If the incident started after a release, roll back:

   ```bash
   kubectl -n order-service rollout undo deployment/order-service
   kubectl -n order-service rollout status deployment/order-service --timeout=10m
   ```

4. If Secret Manager sync failed, verify the synced Kubernetes Secrets and restart only pods that need refreshed secrets.
5. If Redis is degraded, allow cache bypass while restoring Redis. Do not create an independent regional cache that can return inconsistent data.
6. If PostgreSQL is exhausted, reduce avoidable database load before scaling pods. Cancel queries only after database owner approval.
7. If the billing API is failing, enable the documented degraded mode or circuit breaker. Queue work only when idempotency and queue capacity are confirmed.
8. Perform Cloud SQL failover, restart, or database resizing only when evidence points to the database primary and the database on-call approves.

## Escalation path

Escalate immediately to the service owner when:

- error rate exceeds 5% for more than five minutes;
- rollback fails or rollout is stuck;
- payment correctness, duplicate charges, or data loss is possible.

Page the database on-call when:

- database pool availability is below 10%;
- Cloud SQL reports HA, storage, CPU, or failover problems;
- query latency or locks are the dominant cause.

Engage the billing provider or vendor owner when:

- billing API failures exceed baseline for ten minutes;
- provider status page declares an incident;
- retry or idempotency behavior is unclear.

Notify the incident commander when:

- production customer impact lasts more than 15 minutes;
- projected error budget exhaustion is under 24 hours;
- incident severity may be SEV-1 or SEV-2;
- legal, compliance, billing, or security follow-up may be needed.

## Recovery criteria

Resolve the incident only when:

- `/healthz` and `/readyz` are healthy;
- 5xx ratio remains below 1% for at least 15 minutes;
- p99 latency is back under the alert threshold;
- HPA and available replicas are stable;
- backlog or retry queues are draining;
- customer-impact follow-up has an owner.
