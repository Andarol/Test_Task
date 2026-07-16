# Blameless incident postmortem

This document describes what happened, why the system behaved that way, how customer impact was mitigated, and what we will change. It must not assign blame to individuals.

## Incident summary

| Field | Value |
|---|---|
| Title | |
| Date | |
| Severity | SEV-? |
| Start time UTC | |
| Detection time UTC | |
| Mitigation time UTC | |
| Resolution time UTC | |
| Duration | |
| On-call engineer | |
| Incident commander | |
| Services affected | `order-service` |
| Environments affected | stage / prod |
| Document owner | |
| Review date | |

Briefly summarize what users experienced, how the incident was detected, what mitigated it, and how full recovery was verified.

## Impact

| Field | Value |
|---|---|
| Users affected | |
| Orders affected | |
| Failed requests | |
| Delayed requests | |
| Duplicate or incorrect billing risk | |
| Regions or clusters affected | |
| Customer-visible symptoms | |
| Support tickets or external reports | |

### SLO impact

| SLO | Target | Window | Impact |
|---|---:|---|---|
| Availability | 99.9% non-5xx | 30 days | |
| Latency | 95% < 500ms | 30 days | |

Error budget burned:

```text
Error budget burned = incident bad events / allowed bad events for the 30-day window
```

Include the PromQL or dashboard link used to calculate the budget burn.

## Detection

- First signal:
- Alert name:
- Time alert fired:
- Time acknowledged:
- Was detection automatic or customer-reported?
- Why detection was timely or delayed:
- Missing alert, dashboard, or log signal:

## Timeline

Use UTC. Link to dashboards, alerts, commits, deploys, logs, and incident messages where possible.

| Time UTC | Phase | Event / observation | Decision or action | Owner |
|---|---|---|---|---|
| | Detection | Incident detected | | |
| | Declaration | Incident severity assigned | | |
| | Diagnosis | Initial hypothesis formed | | |
| | Mitigation | First customer-impact mitigation applied | | |
| | Recovery | Metrics returned to healthy range | | |
| | Resolution | Incident resolved | | |
| | Follow-up | Postmortem scheduled | | |

## Root cause analysis

### What happened

Describe the technical failure mechanism in plain language. Separate trigger, root cause, and contributing factors.

- Trigger:
- Root cause:
- Contributing factors:
- Why existing safeguards did not prevent or limit impact:

### Five Whys

1. Why did users experience failed or degraded requests?
2. Why did `order-service` return those failures or delays?
3. Why did the dependency, release, capacity limit, or configuration behave that way?
4. Why did our deployment, testing, monitoring, or automation not catch it earlier?
5. Why was the underlying technical or process gap present?

## Mitigation and resolution

- Mitigation chosen:
- Why this mitigation was selected:
- Alternatives considered:
- Risks accepted:
- Commands, deploys, or configuration changes made:
- How recovery was verified:
- Remaining cleanup or reconciliation:

## Lessons learned

### What went well

-

### What did not go well

-

### Where we were fortunate

-

### What we learned

-

## Action items

Every action item must have one owner and a due date. Avoid vague actions like “monitor more” unless the monitoring change is specific.

| Priority | Action | Type | Owner | Due date | Tracking link | Status |
|---|---|---|---|---|---|---|
| P0/P1/P2 | | prevent / detect / mitigate / process | | YYYY-MM-DD | | Open |

## Follow-up verification

- Date fixes were deployed:
- Evidence that fixes work:
- Date action items will be audited:
- Owner for audit:
