# Database connection pool exhaustion runbook

## Impact

`DatabaseConnectionPoolNearExhaustion` fires when less than 10% of the application database pool remains available for five minutes. Requests can queue, latency can spike, and readiness may fail if the service cannot reach PostgreSQL.

## Triage

1. Confirm available pool capacity:

   ```promql
   (
     db_pool_connections_max{service="order-service"}
     - db_pool_connections_in_use{service="order-service"}
   )
   /
   clamp_min(db_pool_connections_max{service="order-service"}, 1)
   ```

2. Check request rate, p99 latency, HPA replica count, and recent deployments.
3. Inspect Cloud SQL active connections, CPU, locks, slow queries, failover events, and max connection settings.
4. Confirm Redis cache is healthy; cache degradation can shift read traffic to PostgreSQL.

## Mitigation

Avoid blindly scaling pods while the database pool is exhausted. First reduce avoidable database load, roll back a bad release if correlated, and only increase application or database connection limits after verifying Cloud SQL capacity.
