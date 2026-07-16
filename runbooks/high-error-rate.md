# HighErrorRate runbook

## Purpose and impact

This runbook handles `HighErrorRate`, which fires when more than 1% of `order-service` requests return 5xx for five minutes. Customers can see failed or delayed order submissions and might retry, so first determine whether retries can create duplicate billing attempts. Do not log, paste, or expose customer payloads or credentials during diagnosis.

## First five minutes

1. Acknowledge the alert and open an incident channel. Record the alert start time, current error rate, affected environment, and on-call owner.
2. Check whether the problem is still active:

   ```promql
   sum(rate(http_requests_total{service="order-service",status_code=~"5.."}[5m]))
   /
   clamp_min(sum(rate(http_requests_total{service="order-service"}[5m])), 0.001)
   ```

3. Check availability, request volume, and latency together:

   ```promql
   sum by (status_code) (rate(http_requests_total{service="order-service"}[5m]))
   histogram_quantile(0.99, sum by (le) (rate(http_request_duration_seconds_bucket{service="order-service"}[5m])))
   order_service:error_budget_burn_rate:ratio_1h
   ```

4. Confirm Kubernetes state:

   ```bash
   kubectl -n order-service get deploy,pods,hpa,pdb -o wide
   kubectl -n order-service rollout status deployment/order-service --timeout=30s
   kubectl -n order-service get events --sort-by=.lastTimestamp | tail -n 50
   ```

5. Identify when errors began and correlate them with a deployment, scaling event, node disruption, database event, or billing-provider incident.

## Diagnosis

### Application and rollout

```bash
kubectl -n order-service rollout history deployment/order-service
kubectl -n order-service describe deployment/order-service
kubectl -n order-service logs deployment/order-service --since=15m --all-containers --prefix
kubectl -n order-service logs deployment/order-service --previous --since=15m --all-containers --prefix
```

Compare errors by pod to isolate one bad replica:

```promql
sum by (pod) (rate(http_requests_total{service="order-service",status_code=~"5.."}[5m]))
```

Do not paste unredacted logs into a public ticket. Search for timeouts, connection refusal, pool exhaustion, panics, and billing API status codes.

### PostgreSQL

```promql
(db_pool_connections_max{service="order-service"} - db_pool_connections_in_use{service="order-service"})
/
clamp_min(db_pool_connections_max{service="order-service"}, 1)
```

From an approved diagnostic pod or bastion, verify TCP connectivity to the private Cloud SQL address without printing credentials. Check Cloud SQL health, active connections, CPU, storage, failover events, and query latency in Google Cloud Monitoring.

### Billing API

Break down application dependency metrics and structured logs by upstream response class. Confirm the vendor's status page and current timeout/retry volume. Avoid enabling aggressive retries: retries can amplify an outage and may duplicate non-idempotent billing requests.

## Resolution, least to most disruptive

1. Remove a single unhealthy pod from service by confirming its readiness failure; let the Deployment replace it. Do not delete multiple pods simultaneously.
2. If load exceeds current capacity and pods are healthy, allow HPA to scale. If HPA is blocked at `maxReplicas`, temporarily raise the maximum after confirming node and database capacity.
3. If the latest release correlates with the incident, roll it back:

   ```bash
   kubectl -n order-service rollout undo deployment/order-service
   kubectl -n order-service rollout status deployment/order-service --timeout=10m
   ```

4. If the billing API is failing, enable the documented application degradation/circuit-breaker mode. Queue work only if the service guarantees idempotency and the queue has capacity.
5. If database capacity is exhausted, stop nonessential workloads or expensive queries before resizing. Cancel a query only after the database owner confirms it is safe.
6. Perform Cloud SQL failover or restart only when evidence points to the primary instance and the database on-call approves; both actions can interrupt active transactions.

After each action, watch error rate, p99 latency, available replicas, and burn rate for at least ten minutes. Record commands and timestamps in the incident timeline.

## Escalation

- Page the service owner immediately if errors exceed 5%, payment correctness is uncertain, or rollback fails.
- Page the database on-call when pool availability is below 10%, Cloud SQL reports an HA/storage incident, or query latency is the dominant cause.
- Engage the billing vendor when its failures exceed the internal baseline for ten minutes or its status page declares an incident.
- Notify the incident commander for any customer-visible critical alert lasting 15 minutes, projected error-budget exhaustion under 24 hours, suspected data loss, duplicate charges, or security impact.

Resolve the incident only after `/healthz` and `/readyz` are healthy, the 5xx ratio remains below 1% for 15 minutes, backlog is draining, and customer-impact follow-up has an owner.
