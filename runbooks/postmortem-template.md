# Blameless incident postmortem

## Incident summary

| Field | Value |
|---|---|
| Title | |
| Date | |
| Severity | SEV-? |
| Start / end | |
| Duration | |
| On-call engineer | |
| Incident commander | |
| Services affected | |
| Document owner | |
| Review date | |

Briefly explain what customers experienced, how the incident was detected, and how service was restored. Describe system behavior and contributing conditions without attributing blame to individuals.

## Impact

- Users, orders, requests, regions, or tenants affected:
- Customer-visible symptoms:
- Failed, delayed, duplicated, or lost work:
- Availability and latency SLO impact:
- Error budget consumed, including calculation and window:
- Financial, compliance, or support impact:

## Detection

- First signal and timestamp:
- Alert that fired:
- Why detection was timely or delayed:
- Detection improvements:

## Timeline

Use UTC and link evidence. Clearly identify detection, declaration, mitigation, recovery, and resolution.

| Time (UTC) | Event / observation | Decision or action | Owner |
|---|---|---|---|
| | Incident detected | | |
| | Incident declared | | |
| | Mitigation started | | |
| | Customer impact ended | | |
| | Incident resolved | | |

## Root cause and contributing factors

Describe the technical failure mechanism and the conditions that allowed it to affect customers. Separate root cause, trigger, and contributing factors.

### Five Whys

1. Why did customers experience the impact?
2. Why did that system behavior occur?
3. Why was the triggering condition possible?
4. Why did safeguards not prevent or limit it?
5. Why was the underlying organizational or technical condition present?

### What went well

-

### What did not go well

-

### Where we were fortunate

-

## Resolution and recovery

Explain the mitigation, why it was selected, risks considered, how correctness was verified, and how any backlog or inconsistent data was reconciled.

## Action items

Every action must be specific, measurable, owned, and dated. Avoid an unowned “monitor more” item.

| Priority | Action | Type (prevent/detect/mitigate/process) | Owner | Due date | Tracking link | Status |
|---|---|---|---|---|---|---|
| P0/P1/P2 | | | | YYYY-MM-DD | | Open |

## Lessons learned

- What assumption was invalid?
- Which control or design should change?
- What should other teams learn from this incident?
- Which runbooks, dashboards, tests, or SLOs need updating?

## Follow-up verification

- Date fixes were tested:
- Evidence that recurrence is prevented or bounded:
- Date postmortem actions will be audited:
