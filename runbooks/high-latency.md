# High latency runbook

## Impact

`HighP99Latency` fires when the p99 request latency for `order-service` stays above one second for ten minutes. Users may see slow order submission, retries, or delayed confirmation from downstream billing.

## Triage

1. Confirm current latency percentiles:

   ```promql
   histogram_quantile(0.50, sum by (le) (rate(http_request_duration_seconds_bucket{service="order-service"}[5m])))
   histogram_quantile(0.95, sum by (le) (rate(http_request_duration_seconds_bucket{service="order-service"}[5m])))
   histogram_quantile(0.99, sum by (le) (rate(http_request_duration_seconds_bucket{service="order-service"}[5m])))
   ```

2. Compare latency with request rate, 5xx rate, HPA state, and available replicas.
3. Check Cloud SQL CPU, active connections, failover events, lock waits, and query latency.
4. Check billing API latency and timeout rates before increasing application retry volume.
5. Verify Redis health. Cache bypass preserves correctness, but it can increase database load.

## Mitigation

Scale the workload only after confirming database and node capacity. If the issue began with the latest release, roll back the deployment and verify p95 and p99 latency return to baseline.
