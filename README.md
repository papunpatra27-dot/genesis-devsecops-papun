DevSecOps Platform

![Coverage](https://img.shields.io/badge/coverage-≥75%25-brightgreen)
![Terraform](https://img.shields.io/badge/terraform-≥1.7-blueviolet)
![Python](https://img.shields.io/badge/python-3.12-blue)
![License](https://img.shields.io/badge/license-MIT-green)

A production-quality DevSecOps reference implementation built on AWS Free Tier resources. Demonstrates a complete secure software delivery lifecycle: hardened Terraform IaC, a 13-stage GitHub Actions pipeline, GitOps with Argo CD, metric-driven canary deployments with Argo Rollouts, Prometheus/Grafana observability, and SLO-based operational discipline.

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│  GitHub                                                      │
│  ├── PR → CI Pipeline (13 stages, Stages 1-11)              │
│  │        ├── Gitleaks (secret scan)                        │
│  │        ├── pip-audit (dependency CVEs)                   │
│  │        ├── Semgrep (SAST)                                │
│  │        ├── pytest ≥75% coverage                          │
│  │        ├── Docker buildx (multi-stage, non-root)         │
│  │        ├── Trivy (image scan, CRITICAL blocks)           │
│  │        ├── Syft SBOM (CycloneDX)                         │
│  │        ├── Cosign (keyless image signing)                │
│  │        ├── tflint (IaC lint)                             │
│  │        ├── Checkov (IaC security scan)                   │
│  │        └── Kyverno offline validation                    │
│  └── push main → Deploy Pipeline (Stages 12-13)            │
│               ├── ECR push (SHA tag, IMMUTABLE)             │
│               ├── Argo CD GitOps sync                       │
│               └── Canary smoke test                         │
│                                                             │
│  AWS (Free Tier)                                            │
│  ├── EC2 t2.micro ──── k3s cluster                         │
│  │   ├── Argo CD (GitOps controller)                        │
│  │   ├── Argo Rollouts (canary: 10→25→50→100%)             │
│  │   ├── Kyverno (admission enforcement)                    │
│  │   ├── Prometheus + Grafana (kube-prometheus-stack)       │
│  │   └── Genesis Platform API (FastAPI)                     │
│  ├── ECR (image registry, scan-on-push, IMMUTABLE tags)    │
│  ├── S3 (Terraform state, versioned, encrypted)            │
│  ├── DynamoDB (state locking)                               │
│  └── IAM (OIDC provider for GitHub Actions)                │
└─────────────────────────────────────────────────────────────┘
```

---

## Repository Structure

```
genesis-devsecops-papun/
├── app/                          # FastAPI application
│   ├── main.py                   # Three endpoints + Prometheus instrumentation
│   ├── requirements.txt
│   ├── pytest.ini
│   ├── Dockerfile                # Multi-stage builder + non-root runtime
│   └── tests/
│       └── test_main.py          # 15+ test cases, ≥75% coverage
├── .github/
│   ├── CODEOWNERS                # Senior engineer review on k8s/, infra/, .github/
│   └── workflows/
│       ├── security-scan.yml     # Reusable: Stages 1-4
│       ├── ci.yml                # PR pipeline: Stages 1-11
│       └── deploy.yml            # Deploy (main only): Stages 12-13
├── infrastructure/
│   ├── terraform.tf              # Provider + backend config
│   ├── variables.tf              # Global variables
│   ├── modules/
│   │   ├── networking/           # VPC, subnets, IGW, security groups, flow logs
│   │   ├── compute/              # EC2 t2.micro, key pair, EIP, user-data k3s bootstrap
│   │   ├── iam/                  # k3s node role, GitHub OIDC, deployment role
│   │   ├── ecr/                  # Repository, lifecycle policy, image scanning
│   │   └── observability/        # CloudWatch logs, SNS alerts, alarms
│   ├── environments/
│   │   ├── dev/                  # Dev tfvars, backend.hcl
│   │   └── prod/                 # Prod tfvars, backend.hcl
│   ├── kyverno-policies/         # 3 ClusterPolicies (Enforce mode)
│   └── conftest-policies/        # OPA guardrails (liveness probe, namespace, LB)
├── k8s/
│   ├── namespace.yaml
│   ├── rollout.yaml              # Argo Rollouts (canary steps)
│   ├── analysis-template.yaml   # PromQL gate: error rate ≤ 2% to promote
│   ├── service.yaml              # Stable + canary services + ServiceMonitor
│   ├── prometheus-rules.yaml    # Fast/slow burn rate alerts
│   └── grafana-dashboard-configmap.yaml
├── slo/
│   └── genesis-platform-api-slo.yaml    # 99.9% availability SLO
├── docs/
│   ├── drift-detection-design.md
│   ├── dr-design.md              # 5-section DR document with CLI runbook
│   ├── slo-rationale.md
│   └── datadog-strategy.md
├── reports/
│   ├── checkov_report.json
│   └── iam_simulation.txt
├── ai-usage-log.md
└── README.md
```

---

## Quick Start

### Prerequisites

- AWS CLI ≥ 2.x, Terraform ≥ 1.7, kubectl, Helm ≥ 3.x, Docker with Buildx, Python 3.12+

### 1. Bootstrap Terraform State Backend (once)

```bash
# Replace ACCOUNT_ID throughout
aws s3api create-bucket --bucket genesis-devsecops-terraform-state-ACCOUNT_ID --region us-east-1
aws s3api put-bucket-versioning --bucket genesis-devsecops-terraform-state-ACCOUNT_ID \
  --versioning-configuration Status=Enabled
aws s3api put-bucket-encryption --bucket genesis-devsecops-terraform-state-ACCOUNT_ID \
  --server-side-encryption-configuration \
  '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'
aws s3api put-public-access-block --bucket genesis-devsecops-terraform-state-ACCOUNT_ID \
  --public-access-block-configuration \
  "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"
aws dynamodb create-table --table-name genesis-terraform-state-lock \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST --region us-east-1
```

### 2. Deploy Dev Environment

```bash
cd infrastructure/environments/dev
# Edit terraform.tfvars — replace all REPLACE_ placeholders
terraform init -backend-config=backend.hcl
terraform plan -var-file=terraform.tfvars
terraform apply -var-file=terraform.tfvars
terraform output k3s_public_ip
```

### 3. Run Application Tests Locally

```bash
cd app && pip install -r requirements.txt && pytest --cov=. --cov-report=term-missing
```

### 4. Validate Policies

```bash
# OPA/Conftest (non-compliant file should produce 3 deny messages)
conftest test --policy infrastructure/conftest-policies/ \
  infrastructure/conftest-policies/test/non_compliant_deployment.yaml

# Kyverno offline
kyverno apply infrastructure/kyverno-policies/ --resource k8s/
```

---

## API Reference

| Method | Endpoint | Response |
|--------|----------|----------|
| GET | `/health` | `{"status":"ok","version":"1.0.0","namespace":"<K8s_namespace>"}` |
| POST | `/platform/units` | 201 `{unit_id, created_at}` or 409 conflict |
| GET | `/platform/units/{unit_id}` | 200 unit record or 404 `{error, code, request_id}` |
| GET | `/metrics` | Prometheus scrape endpoint |

---

## Canary Rollout

```
10% → pause 2m → PromQL analysis (error rate ≤ 2%) → 25% → pause 2m → 50% → 100%
                                ↓ error rate > 2%
                           ABORT + auto-rollback
```

```bash
kubectl argo rollouts get rollout genesis-platform-api -n staging --watch
```

---

## SLO

| | |
|---|---|
| Target | 99.9% availability (30-day window) |
| Error budget | 43.8 minutes/month |
| Fast burn alert | 14× rate over 1h → P1 page |
| Slow burn alert | 6× rate over 6h → warning |
| Canary gate | Error rate ≤ 2% to promote |

---

## Security Controls

| Control | Tool |
|---------|------|
| Secret scanning | Gitleaks (gate) |
| Dependency CVEs | pip-audit (gate) |
| SAST | Semgrep OWASP (gate) |
| Image scanning | Trivy CRITICAL (gate) |
| Image signing | Cosign keyless OIDC |
| IaC security | Checkov (gate) |
| Admission control | Kyverno: no-root, resource limits, ECR-only |
| Manifest guardrails | OPA/Conftest: liveness, namespace, LB annotation |
| AWS auth | OIDC only — zero static credentials |
| IAM | Least-privilege, simulate-principal-policy verified |

---

## Required GitHub Secrets

| Secret | Purpose |
|--------|---------|
| `AWS_DEPLOY_ROLE_ARN` | OIDC deployment role ARN |
| `ARGOCD_SERVER` | Argo CD address (`IP:30080`) |
| `ARGOCD_PASSWORD` | Argo CD admin password |
| `K3S_PUBLIC_IP` | k3s node Elastic IP (smoke test) |
| `SEMGREP_APP_TOKEN` | Semgrep cloud token (optional) |

> `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` are **never used**. All AWS auth is OIDC-federated.
