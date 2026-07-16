# Pod crash-looping runbook

## Impact

`PodCrashLooping` fires when an `order-service` container restarts more than three times in 15 minutes. Availability may remain healthy if enough replicas are serving, but capacity and rollout safety are reduced.

## Triage

1. Identify the restarting pod:

   ```bash
   kubectl -n order-service get pods
   kubectl -n order-service describe pod <pod>
   kubectl -n order-service logs <pod> --previous
   ```

2. Check whether restarts correlate with a new image, missing Secret Manager sync, readiness failures, OOM kills, node pressure, or dependency timeouts.
3. Confirm the deployment still has enough available replicas and the PDB is not blocking maintenance.

## Mitigation

If one pod is bad, let the Deployment replace it. If the new revision is consistently crashing, roll back to the previous revision and stop the rollout before more capacity is lost.
