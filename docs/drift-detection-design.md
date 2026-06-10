# Drift Detection Design

## Automated Detection Mechanism and Frequency

**Terraform drift** (infrastructure divergence) is detected by running `terraform plan` against the live AWS environment in a scheduled GitHub Actions workflow that executes every four hours. The workflow authenticates via OIDC, runs `terraform plan -detailed-exitcode` against both dev and prod state files, and publishes the exit code to a CloudWatch metric. Exit code 2 means drift exists. The plan output is uploaded as a workflow artifact and a structured JSON summary is posted to the `#infra-drift` Slack channel via an SNS-to-Lambda-to-Slack bridge. Because the plan is read-only (`terraform plan`, not `apply`), there is zero risk of accidental change.

**Kubernetes configuration drift** (cluster state diverging from Git) is a fundamentally different problem. It occurs when someone runs `kubectl apply` directly, edits a ConfigMap in-cluster, or an operator mutates a resource outside GitOps control. Argo CD detects this continuously — by default it re-syncs its cache every three minutes and compares live cluster state against the Git HEAD of the tracked branch. When a drift is found, Argo CD marks the application as `OutOfSync` and optionally auto-corrects it (if `syncPolicy.automated.selfHeal: true` is set). This is not periodic polling but an event-driven reconciliation loop — far more responsive than a scheduled Terraform plan.

The distinction matters: Terraform drift means "the cloud resource does not match what Terraform thinks it should be." Kubernetes drift means "what is running in the cluster does not match what Git says should be running." Both must be monitored but with different tools.

A third category — **policy drift** — occurs when Kyverno ClusterPolicies in the cluster diverge from those in Git. Since Kyverno itself is managed by Argo CD (the policies live in `infrastructure/kyverno-policies/` and are synced as part of the platform app), Argo CD catches this automatically.

## Response Policy

When drift is detected, the following SLAs apply:

| Drift Type | Notification | Remediation SLA | Escalation |
|---|---|---|---|
| Terraform drift (non-security) | Slack `#infra-drift` | 8 business hours | Platform lead if breached |
| Terraform drift (security group / IAM) | PagerDuty P2 | 2 hours | CISO + platform lead |
| Kubernetes OutOfSync (non-production) | Slack `#platform-alerts` | 4 hours | Auto-heal re-enabled |
| Kubernetes OutOfSync (production) | PagerDuty P1 | 30 minutes | Incident declared |

**When is drift accepted?** Drift is accepted and state updated to match reality only in two scenarios:

1. A legitimate emergency change was made manually during an incident. Within 24 hours of recovery, the engineer who made the change must open a PR that codifies it in Terraform or the Git manifests and the drift is resolved by `terraform apply` or Argo CD sync.
2. A cloud provider changes a resource attribute that Terraform cannot control (e.g. AWS updates a managed policy). In this case, `terraform import` is used to pull the new reality into state and a note is added to `reports/drift-accepted.md` with the date and justification.

Drift is never silently ignored. Every detected divergence is logged.

## How GitOps with Argo CD Changes the Drift Story

Without GitOps, a developer runs `kubectl apply -f my-change.yaml` directly against the cluster. The change is applied immediately and lives only in the cluster's etcd — not in any version-controlled source. If a pod is deleted or the cluster is rebuilt, the change is lost. There is no way to detect that this change was made without manually diffing the cluster state against a known-good baseline. This is the manual-kubectl drift problem.

With Argo CD, the mechanism is inverted. Git is the single source of truth. When a developer pushes to the tracked branch, Argo CD's application controller detects the new commit (via webhook or periodic poll) and applies the diff to the cluster using a server-side apply. When someone runs `kubectl apply` directly against a resource Argo CD owns, Argo CD's reconciliation loop detects within three minutes that the live object has diverged from the Git-desired state and either raises an `OutOfSync` alert or, if `selfHeal` is enabled, reverts the manual change automatically.

The practical implication: in a GitOps model, unauthorized kubectl changes are self-healing or immediately visible. In a manual model, they are invisible until the next manual audit. Argo CD makes drift detection continuous and automatic; it does not require scheduled scans because the reconciliation loop never stops. This eliminates an entire category of undetected drift that plagues purely Terraform-managed Kubernetes clusters.

## OPA/Conftest Policy Layer

Beyond Kyverno admission control, Conftest policies (`infrastructure/conftest-policies/kubernetes.rego`) enforce guardrails that are not covered by runtime admission:

- All Deployments and Rollouts must declare a `livenessProbe`
- No application workload Namespace may be named `default`
- All `LoadBalancer` Services must carry a `cost-centre` annotation

These run in CI (Stage 11 equivalent, offline) against every PR that touches `k8s/`. A non-compliant manifest fails the PR check before it reaches Kyverno admission control in the cluster, giving developers fast feedback without requiring a running cluster.
