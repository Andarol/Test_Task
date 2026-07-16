# Redis cache degraded

## Impact

The application treats Redis as disposable cache and continues serving reads with `X-Cache: BYPASS`. User-visible correctness is preserved, but Cloud SQL traffic and request latency can increase.

## Triage

1. Confirm `cache_requests_total{result="error"}` by region and compare it with request latency and Cloud SQL utilization.
2. Check Memorystore instance availability, maintenance events, memory usage, evictions, AUTH failures, and TLS certificate errors.
3. Verify routing from both GKE pod CIDRs to the shared Redis private endpoint and confirm the rendered NetworkPolicy contains the current host and TLS port.
4. Verify the latest Redis AUTH and CA Secret Manager versions have synchronized to `order-service-cache` in both clusters.
5. Do not create an independent regional cache as an emergency workaround; it can produce inconsistent cache contents. Let requests bypass Redis while restoring the shared instance.

## Recovery

Restore connectivity or Memorystore health, restart only pods holding stale synchronized secrets if necessary, then verify `MISS` followed by `HIT` on `GET /orders`. Confirm Redis errors stop and Cloud SQL load returns to baseline.
