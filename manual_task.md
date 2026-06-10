# Genesis DevSecOps Platform — Complete Operational Manual

> **Who this is for**: Someone starting from zero — a fresh laptop, a new AWS account, and this repository.  
> **What it covers**: Every command, every click, every placeholder to replace, in the exact order that makes them work.  
> **What it does NOT do**: Skip steps. Every dependency is explicit.

---

## Table of Contents

1. [Tools You Must Install First](#phase-0-tools--prerequisites)
2. [**LOCAL TESTING** — Verify Everything Before Touching AWS](#phase-0b-local-testing--verify-everything-before-touching-aws)
   - [A. Python Unit Tests (pytest)](#section-a-python-unit-tests-pytest)
   - [B. Docker Build and Run Tests](#section-b-docker-build-and-run-tests)
   - [C. Terraform Static Analysis — tflint, Checkov, Conftest](#section-c-terraform-static-analysis-local)
   - [D. Kyverno Offline Policy Validation](#section-d-kyverno-offline-policy-validation)
   - [E. Security Tool Scans — Gitleaks, pip-audit, Semgrep](#section-e-security-tool-scans-local)
   - [F. Single-Command Local CI Simulation](#section-f-run-all-local-checks-with-a-single-script)
3. [AWS Account Setup](#phase-1-aws-account-setup)
4. [GitHub Repository Setup](#phase-2-github-repository-setup)
5. [Replace Every Placeholder Value](#phase-3-replace-all-placeholder-values)
6. [Bootstrap AWS State Backend (one-time)](#phase-4-bootstrap-aws-state-backend)
7. [Terraform First Run — Provision All Infrastructure](#phase-5-terraform-first-run)
8. [Connect to the k3s Cluster](#phase-6-connect-to-k3s-cluster)
9. [Verify All In-Cluster Components](#phase-7-verify-in-cluster-components)
10. [Install Missing Helm Components Manually (if userdata failed)](#phase-8-manual-helm-installs-fallback)
11. [Apply Kyverno Policies](#phase-9-apply-kyverno-policies)
12. [Push the First Image to ECR Manually](#phase-10-push-first-image-to-ecr)
13. [Configure GitHub Actions Secrets](#phase-11-github-actions-secrets)
14. [Wire Argo CD GitOps](#phase-12-wire-argo-cd-gitops)
15. [Apply k8s Supporting Resources](#phase-13-apply-k8s-supporting-resources)
16. [Run the Full CI Pipeline (PR → merge)](#phase-14-first-full-pipeline-run)
17. [Test a Canary Deployment End-to-End](#phase-15-test-canary-deployment)
18. [Access Grafana and Verify Observability](#phase-16-grafana--prometheus-verification)
19. [Demo All Three Planted Flaws](#phase-17-demo-all-three-planted-flaws)
20. [SLO and Alert Verification](#phase-18-slo-and-alert-verification)
21. [DR Runbook Quick Test](#phase-19-dr-runbook-quick-test)

---

## Phase 0: Tools & Prerequisites

Install all of the following before doing anything else. Versions specified are minimum required.

### 0.1 — AWS CLI v2

```bash
# Linux / macOS
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip && sudo ./aws/install

# Windows (PowerShell)
msiexec.exe /i https://awscli.amazonaws.com/AWSCLIV2.msi

# Verify
aws --version
# Expected: aws-cli/2.x.x
```

### 0.2 — Terraform >= 1.8

```bash
# Linux (tfenv — recommended)
git clone https://github.com/tfutils/tfenv.git ~/.tfenv
echo 'export PATH="$HOME/.tfenv/bin:$PATH"' >> ~/.bashrc && source ~/.bashrc
tfenv install 1.8.5
tfenv use 1.8.5
terraform --version
# Expected: Terraform v1.8.5

# Windows — download from https://developer.hashicorp.com/terraform/downloads
# Unzip, add to PATH, restart terminal
```

### 0.3 — kubectl

```bash
# Linux
curl -LO "https://dl.k8s.io/release/$(curl -sL https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
kubectl version --client

# macOS
brew install kubectl

# Windows (PowerShell as Admin)
winget install -e --id Kubernetes.kubectl
```

### 0.4 — Helm >= 3.14

```bash
# Linux / macOS
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
helm version

# Windows
winget install Helm.Helm
```

### 0.5 — Docker

```bash
# Linux (Docker Engine)
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER
# Log out and back in for group change to take effect
docker --version

# Windows / macOS — install Docker Desktop from https://www.docker.com/products/docker-desktop
```

### 0.6 — Python 3.12 + pip

```bash
# Ubuntu / Debian
sudo apt install python3.12 python3.12-pip python3.12-venv -y
python3.12 --version

# macOS
brew install python@3.12

# Windows
winget install Python.Python.3.12
```

### 0.7 — tflint

```bash
# Linux / macOS
curl -s https://raw.githubusercontent.com/terraform-linters/tflint/master/install_linux.sh | bash
tflint --version

# Windows (PowerShell)
winget install terraform-linters.tflint
```

### 0.8 — Cosign

```bash
# Linux
curl -O -L "https://github.com/sigstore/cosign/releases/latest/download/cosign-linux-amd64"
sudo install -m 0755 cosign-linux-amd64 /usr/local/bin/cosign
cosign version

# macOS
brew install cosign
```

### 0.9 — Argo CD CLI

```bash
# Linux
curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
sudo install -m 0755 argocd-linux-amd64 /usr/local/bin/argocd
argocd version --client

# macOS
brew install argocd

# Windows (PowerShell)
choco install argocd-cli
```

### 0.10 — Kyverno CLI

```bash
# Linux
curl -sL "https://github.com/kyverno/kyverno/releases/download/v1.12.0/kyverno-cli_linux_amd64.tar.gz" \
  -o /tmp/kyverno.tar.gz
tar -xzf /tmp/kyverno.tar.gz -C /tmp kyverno
sudo install -m 0755 /tmp/kyverno /usr/local/bin/kyverno
kyverno version

# macOS
brew install kyverno
```

### 0.11 — GitHub CLI (optional but helpful)

```bash
# Linux
sudo apt install gh -y

# macOS
brew install gh

# Authenticate
gh auth login
```

### 0.12 — Semgrep

```bash
# Linux / macOS
pip install semgrep
semgrep --version

# Windows
pip install semgrep
semgrep --version
```

### 0.13 — Gitleaks

```bash
# Linux
curl -sSfL https://github.com/gitleaks/gitleaks/releases/download/v8.18.4/gitleaks_8.18.4_linux_x64.tar.gz \
  | tar -xz -C /tmp && sudo install -m 0755 /tmp/gitleaks /usr/local/bin/gitleaks
gitleaks version

# Windows (PowerShell)
winget install gitleaks.gitleaks
```

### 0.14 — Checkov

```bash
pip install checkov
checkov --version
```

### 0.15 — OPA / Conftest

```bash
# Conftest (wraps OPA for structured policy testing)
# Linux
curl -sSfL https://github.com/open-policy-agent/conftest/releases/download/v0.52.0/conftest_0.52.0_Linux_x86_64.tar.gz \
  | tar -xz -C /tmp && sudo install -m 0755 /tmp/conftest /usr/local/bin/conftest
conftest --version

# Windows
winget install open-policy-agent.conftest
```

---

## Phase 0B: Local Testing — Verify Everything Before Touching AWS

> **Do this entire phase before you create any AWS resources.**  
> Every test here runs on your laptop with zero cloud dependency.  
> If all tests below pass, you have confidence the codebase is correct.

---

### Section A: Python Unit Tests (pytest)

This verifies the FastAPI application, all three endpoints, Prometheus metrics export, and confirms ≥75% code coverage.

#### A.1 — Set up Python virtual environment

```bash
cd app/

# Create isolated venv (avoids polluting system Python)
# Linux / macOS
python3 -m venv .venv
source .venv/bin/activate

# Windows PowerShell
py -m venv .venv
.venv\Scripts\Activate.ps1

# Confirm which python is active
which python       # Linux/macOS: should point to .venv/bin/python
python --version   # Expected: Python 3.12.x (or whichever you installed)
```

#### A.2 — Install all dependencies

```bash
# Still in app/ with venv active

pip install --upgrade pip
pip install -r requirements.txt

# Verify key packages installed
pip show fastapi pytest pytest-cov prometheus-client httpx
# Expected: each shows Version: x.x.x (no "not found" errors)
```

#### A.3 — Set required environment variables

```bash
# These env vars are needed for the FastAPI app to start
# The pytest.ini injects K8S_NAMESPACE=test-namespace automatically via the test module

# Linux / macOS (not required — tests inject it, but good to know)
export K8S_NAMESPACE=test-namespace
export APP_VERSION=1.0.0

# Windows PowerShell
$env:K8S_NAMESPACE = "test-namespace"
$env:APP_VERSION = "1.0.0"
```

#### A.4 — Run pytest with full output

```bash
# Must be in app/ directory (NOT the repo root)
# The pytest.ini has: testpaths = tests, pythonpath = .

py -m pytest tests/ -v --tb=short --cov=. --cov-report=term-missing --cov-fail-under=75

# If using python3:
python3 -m pytest tests/ -v --tb=short --cov=. --cov-report=term-missing --cov-fail-under=75
```

**Expected output** (full annotated):

```
======================================== test session starts =========================================
platform linux -- Python 3.12.x, pytest-8.3.4, pluggy-1.5.0
rootdir: /path/to/devsecops-papun/app
configfile: pytest.ini
plugins: cov-6.0.0, asyncio-0.24.0

collected 30 items

tests/test_main.py::TestHealth::test_health_returns_200 PASSED                                [  3%]
tests/test_main.py::TestHealth::test_health_body_shape PASSED                                 [  6%]
tests/test_main.py::TestHealth::test_health_content_type_json PASSED                          [  9%]
tests/test_main.py::TestCreateUnit::test_create_unit_returns_201 PASSED                       [ 12%]
tests/test_main.py::TestCreateUnit::test_create_unit_response_body PASSED                     [ 16%]
tests/test_main.py::TestCreateUnit::test_create_unit_conflict_returns_409 PASSED              [ 19%]
tests/test_main.py::TestCreateUnit::test_create_unit_conflict_error_code PASSED               [ 22%]
tests/test_main.py::TestCreateUnit::test_create_unit_missing_field_returns_422 PASSED         [ 25%]
tests/test_main.py::TestCreateUnit::test_create_unit_blank_tenant_id_returns_422 PASSED       [ 29%]
tests/test_main.py::TestCreateUnit::test_create_unit_blank_unit_id_returns_422 PASSED         [ 32%]
tests/test_main.py::TestGetUnit::test_get_unit_returns_200 PASSED                             [ 35%]
tests/test_main.py::TestGetUnit::test_get_unit_body_contains_fields PASSED                    [ 38%]
tests/test_main.py::TestGetUnit::test_get_unit_not_found_returns_404 PASSED                   [ 41%]
tests/test_main.py::TestGetUnit::test_get_unit_not_found_error_structure PASSED               [ 45%]
tests/test_main.py::TestMetrics::test_metrics_endpoint_returns_200 PASSED                     [ 48%]
tests/test_main.py::TestMetrics::test_metrics_content_type_is_prometheus_text PASSED          [ 51%]
tests/test_main.py::TestMetrics::test_metrics_contains_http_requests_total PASSED             [ 54%]
tests/test_main.py::TestMetrics::test_metrics_contains_http_request_duration_seconds PASSED   [ 58%]
tests/test_main.py::TestMetrics::test_metrics_contains_genesis_units_created_total PASSED     [ 61%]
tests/test_main.py::TestMetrics::test_metrics_genesis_counter_increments_per_tenant PASSED    [ 64%]
tests/test_main.py::TestMetrics::test_metrics_counter_value_increases_after_post PASSED       [ 67%]
tests/test_main.py::TestMetrics::test_http_requests_total_increments_on_health_call PASSED    [ 70%]
tests/test_main.py::TestMiddleware::test_404_request_still_recorded_in_metrics PASSED         [ 74%]
tests/test_main.py::TestMiddleware::test_post_conflict_409_recorded_in_metrics PASSED         [ 77%]

---------- coverage: platform linux, python 3.12.x -----------
Name        Stmts   Miss  Cover   Missing
------------------------------------------
main.py        85      12    86%   145-148, 167-172, 182
------------------------------------------
TOTAL          85      12    86%

PASSED (coverage: 86% >= 75% required)

======================================== 24 passed in 1.23s =========================================
```

**What to do if tests fail:**

- `ModuleNotFoundError: No module named 'main'`:  
  You are NOT in the `app/` directory. Run `cd app/` first.

- `ModuleNotFoundError: No module named 'app'`:  
  The old import `from app.main import ...` is still in the file.  
  Fix: `grep -n "app.main" tests/test_main.py` — if found, change to `from main import`.

- `pytest: error: unrecognized argument --cov`:  
  pytest-cov not installed. Run: `pip install pytest-cov`.

- Coverage `XX% < 75%`:  
  Some test class is not running. Check `collected N items` — should be ≥ 24.

#### A.5 — View the HTML coverage report (optional)

```bash
py -m pytest tests/ --cov=. --cov-report=html

# Open in browser:
# Linux: xdg-open htmlcov/index.html
# macOS: open htmlcov/index.html
# Windows: start htmlcov\index.html

# The report shows exactly which lines are NOT covered
# Click on main.py to see highlighted uncovered lines
```

#### A.6 — Verify the XML coverage report is generated (for CI)

```bash
ls -la coverage.xml          # Linux / macOS
Get-Item coverage.xml        # Windows

# Expected: coverage.xml exists (CI uploads this to Codecov/SonarCloud)
# Preview first 5 lines:
head -5 coverage.xml         # Linux / macOS
Get-Content coverage.xml | Select-Object -First 5   # Windows
```

---

### Section B: Docker Build and Run Tests

This verifies the Dockerfile is correct — multi-stage build, non-root user, correct port, metrics exposed.

#### B.1 — Build the Docker image

```bash
# Must be in app/ directory
cd app/

docker build -t genesis-platform-api:test-local .
```

**Expected output:**

```
[+] Building 45.2s (12/12) FINISHED
 => [internal] load build definition from Dockerfile
 => [builder 1/5] FROM docker.io/library/python:3.12-slim
 => [builder 2/5] WORKDIR /build
 => [builder 3/5] COPY requirements.txt .
 => [builder 4/5] RUN pip install --no-cache-dir -r requirements.txt
 => [builder 5/5] COPY . .
 => [runtime 1/4] FROM docker.io/library/python:3.12-slim
 => [runtime 2/4] RUN groupadd -r appuser && useradd -r -g appuser -u 1000 appuser
 => [runtime 3/4] COPY --from=builder /build /app
 => [runtime 4/4] WORKDIR /app
 => exporting to image
 => => writing image sha256:abc123...

Successfully built abc123def456
Successfully tagged genesis-platform-api:test-local
```

**If the build fails:**
- `COPY . .` fails: make sure you are in `app/` (where the `Dockerfile` lives)
- `pip install` timeout: try `docker build --network=host -t genesis-platform-api:test-local .`

#### B.2 — Verify the image does NOT run as root

This is a mandatory security check. The Dockerfile creates `appuser` (UID 1000) and switches to it.

```bash
# Check the user the container runs as (must be 1000, NOT 0)
docker run --rm --entrypoint="" genesis-platform-api:test-local id

# Expected output:
# uid=1000(appuser) gid=1000(appuser) groups=1000(appuser)

# If you see uid=0(root): the Dockerfile USER instruction is missing or wrong
# Fix: open app/Dockerfile and verify the last USER line is: USER appuser
```

#### B.3 — Run the container

```bash
# Run in the background, map port 8000, inject required env vars
docker run -d \
  --name genesis-api-test \
  -p 8000:8000 \
  -e K8S_NAMESPACE=local-test \
  -e APP_VERSION=1.0.0 \
  genesis-platform-api:test-local

# Verify it started
docker ps
# Expected:
# CONTAINER ID   IMAGE                           STATUS         PORTS
# abc123def456   genesis-platform-api:test-local Up 5 seconds   0.0.0.0:8000->8000/tcp

# Check logs for startup message
docker logs genesis-api-test
# Expected last lines:
# INFO:     Started server process [1]
# INFO:     Waiting for application startup.
# INFO:     Application startup complete.
# INFO:     Uvicorn running on http://0.0.0.0:8000 (Press CTRL+C to quit)
```

**If the container exits immediately:**
```bash
docker logs genesis-api-test    # show error
# Common causes:
# - "No module named 'main'": COPY path wrong in Dockerfile
# - "Error: K8S_NAMESPACE not set": add -e K8S_NAMESPACE=local-test to docker run
```

#### B.4 — Test all three API endpoints with curl

Run all of these from a new terminal (container is running in background):

```bash
# ── Endpoint 1: GET /health ──────────────────────────────────────────────────
curl -s http://localhost:8000/health | python3 -m json.tool

# Expected HTTP 200 response body:
# {
#     "status": "ok",
#     "version": "1.0.0",
#     "namespace": "local-test"
# }

# ── Endpoint 2a: POST /platform/units (success 201) ──────────────────────────
curl -s -w "\nHTTP_STATUS:%{http_code}\n" \
  -X POST http://localhost:8000/platform/units \
  -H "Content-Type: application/json" \
  -d '{"unit_id":"unit-alpha","status":"active","tenant_id":"tenant-acme"}' \
  | python3 -m json.tool

# Expected HTTP 201 response body:
# {
#     "unit_id": "unit-alpha",
#     "status": "active",
#     "tenant_id": "tenant-acme",
#     "created_at": "2026-06-05T10:00:00.123456"
# }

# ── Endpoint 2b: POST /platform/units (duplicate → 409) ───────────────────────
curl -s -w "\nHTTP_STATUS:%{http_code}\n" \
  -X POST http://localhost:8000/platform/units \
  -H "Content-Type: application/json" \
  -d '{"unit_id":"unit-alpha","status":"active","tenant_id":"tenant-acme"}'

# Expected HTTP 409 response body:
# {"detail":{"error":"Unit already exists","code":"UNIT_CONFLICT","unit_id":"unit-alpha"}}

# ── Endpoint 2c: POST /platform/units (missing field → 422) ──────────────────
curl -s -w "\nHTTP_STATUS:%{http_code}\n" \
  -X POST http://localhost:8000/platform/units \
  -H "Content-Type: application/json" \
  -d '{"unit_id":"unit-beta","status":"active"}'

# Expected HTTP 422 response body:
# {"detail":[{"type":"missing","loc":["body","tenant_id"],"msg":"Field required",...}]}

# ── Endpoint 2d: POST /platform/units (blank tenant_id → 422) ────────────────
curl -s -w "\nHTTP_STATUS:%{http_code}\n" \
  -X POST http://localhost:8000/platform/units \
  -H "Content-Type: application/json" \
  -d '{"unit_id":"unit-gamma","status":"active","tenant_id":"   "}'
# Expected HTTP 422 (Pydantic strips and validates blank)

# ── Endpoint 3a: GET /platform/units/{unit_id} (exists → 200) ────────────────
curl -s -w "\nHTTP_STATUS:%{http_code}\n" \
  http://localhost:8000/platform/units/unit-alpha \
  | python3 -m json.tool

# Expected HTTP 200 response body:
# {
#     "unit_id": "unit-alpha",
#     "status": "active",
#     "tenant_id": "tenant-acme",
#     "created_at": "2026-06-05T10:00:00.123456"
# }

# ── Endpoint 3b: GET /platform/units/{unit_id} (missing → 404) ───────────────
curl -s -w "\nHTTP_STATUS:%{http_code}\n" \
  http://localhost:8000/platform/units/nonexistent-id

# Expected HTTP 404 response body:
# {"detail":{"error":"Unit not found","code":"UNIT_NOT_FOUND","request_id":"..."}}
```

#### B.5 — Test Prometheus metrics endpoint

```bash
# First create a unit so genesis_units_created_total appears
curl -s -X POST http://localhost:8000/platform/units \
  -H "Content-Type: application/json" \
  -d '{"unit_id":"metric-unit","status":"active","tenant_id":"tenant-metrics"}'

# Scrape /metrics
curl -s http://localhost:8000/metrics | grep -E "genesis_units|http_requests_total|http_request_duration"

# Expected output (subset):
# # HELP genesis_units_created_total Total number of platform units created
# # TYPE genesis_units_created_total counter
# genesis_units_created_total{tenant_id="tenant-acme"} 1.0
# genesis_units_created_total{tenant_id="tenant-metrics"} 1.0
# # HELP http_requests_total Total HTTP requests
# # TYPE http_requests_total counter
# http_requests_total{method="GET",path="/health",status_code="200"} 1.0
# http_requests_total{method="POST",path="/platform/units",status_code="201"} 2.0
# http_requests_total{method="POST",path="/platform/units",status_code="409"} 1.0
# # HELP http_request_duration_seconds HTTP request duration
# # TYPE http_request_duration_seconds histogram
# http_request_duration_seconds_bucket{...}

# CRITICAL CHECK: genesis_units_created_total MUST appear here.
# If it does NOT appear, the Grafana "Units Created by Tenant" panel will show "No data"
# and the AnalysisTemplate PromQL gate will not work during canary deploys.

# Check the content-type header (Prometheus scraper requirement)
curl -sI http://localhost:8000/metrics | grep -i content-type
# Expected: Content-Type: text/plain; version=0.0.4; charset=utf-8
```

#### B.6 — Stop and clean up the test container

```bash
docker stop genesis-api-test
docker rm genesis-api-test
```

---

### Section C: Terraform Static Analysis (Local)

Run these from the repo root, no AWS credentials needed.

#### C.1 — tflint (Terraform linting)

```bash
# Must be at repo root (where .tflint.hcl lives)
cd c:\Clouddev\devsecops-papun   # or your repo root

# Initialise tflint (downloads AWS plugin)
tflint --init

# Expected output:
# Installing "aws" plugin...
# Installed "aws" (source: github.com/terraform-linters/tflint-ruleset-aws, version: 0.32.0)
```

```bash
# Run tflint on the networking module
tflint --chdir infrastructure/modules/networking

# Expected output (if no issues):
# 3 issue(s) found:   ← OR no issues
# (issues will be about missing region, which is expected in modules — not an error)

# Run on all modules at once
for dir in infrastructure/modules/*/; do
  echo "=== $dir ==="
  tflint --chdir "$dir" 2>&1
done
# Windows PowerShell:
foreach ($dir in (Get-ChildItem infrastructure\modules -Directory)) {
  Write-Host "=== $($dir.Name) ===" -ForegroundColor Cyan
  tflint --chdir "infrastructure\modules\$($dir.Name)"
}
```

**Expected tflint output** (example for networking module):
```
1 issue(s) found:

Warning: Module source "../../modules/networking" is not pinned (terraform_module_pinned_source)
```
This warning about module pinning is expected in a monorepo (local modules don't need version pinning). Other rules (missing variable types, deprecated syntax) should show 0 issues.

#### C.2 — Checkov (IaC security scanning)

```bash
# Still at repo root

# Run checkov on all Terraform files
checkov -d infrastructure/ --framework terraform --output cli

# Expected output (summary at end):
# Passed checks: 45, Failed checks: 3, Skipped checks: 0
# 
# Check: CKV_AWS_79: "Ensure Instance Metadata Service Version 1 is not enabled"
# PASSED for resource: module.compute.aws_instance.k3s
# Check: CKV_AWS_8: "Ensure all data stored in the Launch configuration or instance Elastic Blocks are securely encrypted"
# PASSED for resource: module.compute.aws_instance.k3s
# ... etc
```

**What is acceptable:** Passing checks ≥ 70% is the CI threshold. Some failures on managed policies (like `AdministratorAccess` for bootstrap) are expected.

```bash
# Run with JSON output (same as CI artifact)
checkov -d infrastructure/ --framework terraform --output json > /tmp/checkov_report.json

# View summary only
python3 -c "
import json
r=json.load(open('/tmp/checkov_report.json'))
s=r['summary']
print(f'Passed: {s[\"passed\"]}  Failed: {s[\"failed\"]}  Skipped: {s[\"skipped\"]}')
"
```

#### C.3 — OPA/Conftest policy tests (Kubernetes manifest validation)

```bash
# Still at repo root
# conftest uses the policies in infrastructure/conftest-policies/

# Test COMPLIANT deployment (should pass all 4 guardrails)
conftest test \
  --policy infrastructure/conftest-policies/kubernetes.rego \
  infrastructure/conftest-policies/test/compliant_deployment.yaml

# Expected output:
# PASS - infrastructure/conftest-policies/test/compliant_deployment.yaml - data.kubernetes.deny

# Test NON-COMPLIANT deployment (should fail all 4 guardrails)
conftest test \
  --policy infrastructure/conftest-policies/kubernetes.rego \
  infrastructure/conftest-policies/test/non_compliant_deployment.yaml

# Expected output (4 failures):
# FAIL - infrastructure/conftest-policies/test/non_compliant_deployment.yaml - data.kubernetes.deny
#   Deployment test-bad in default namespace: missing liveness probe
#   Deployment test-bad in default namespace: deployed in default namespace
#   Deployment test-bad: LoadBalancer service is missing cost-centre annotation
#   Deployment test-bad: replicas must be >= 1
```

**If conftest fails with "no policies found":**
```bash
# Verify the policy file path
ls infrastructure/conftest-policies/kubernetes.rego

# Verify it has deny rules
grep "^deny" infrastructure/conftest-policies/kubernetes.rego
# Expected: lines starting with "deny[msg] {"
```

---

### Section D: Kyverno Offline Policy Validation

This uses the Kyverno CLI to validate Kubernetes manifests against ClusterPolicies without a running cluster. Same test as Stage 11 in the CI pipeline.

#### D.1 — Run against the clean manifests (must PASS all)

```bash
# From repo root
kyverno apply \
  infrastructure/kyverno-policies/ \
  --resource k8s/namespace.yaml \
  --resource k8s/service.yaml

# Expected output:
# Applying 3 policy rule(s) to 2 resource(s)...
# 
# pass: 2, fail: 0, warn: 0, error: 0, skip: 0
```

```bash
# Test the rollout (app deployment manifest)
kyverno apply \
  infrastructure/kyverno-policies/ \
  --resource k8s/rollout.yaml

# Expected:
# pass: 1, fail: 0, warn: 0, error: 0, skip: 0
# (rollout has: runAsNonRoot=true, resource limits set, ECR image — should pass all 3 policies)
```

#### D.2 — Run against the FLAWED manifest (must FAIL with 3 violations)

```bash
kyverno apply \
  infrastructure/kyverno-policies/ \
  --resource k8s/flawed-deployment.yaml

# Expected output (full):
# Applying 3 policy rule(s) to 1 resource(s)...
# 
# policy no-root-containers -> resource /Deployment/flawed-nginx-demo failed:
#   1. autogen-no-root-containers: validation error (line 1, column 1): rule autogen-no-root-containers
#      failed at path /spec/template/spec/containers/0/securityContext/runAsNonRoot/:
#      Containers must not run as root user. Set runAsNonRoot: true.
# 
# policy require-resource-limits -> resource /Deployment/flawed-nginx-demo failed:
#   1. autogen-require-cpu-limit: validation error: CPU limits required.
#   2. autogen-require-memory-limit: validation error: Memory limits required.
# 
# policy ecr-only-images -> resource /Deployment/flawed-nginx-demo failed:
#   1. ecr-registry-only: validation error: Images must come from the ECR registry.
#      Image 'nginx:latest' does not match pattern '320644184091.dkr.ecr.ap-south-1.amazonaws.com/*'
# 
# pass: 0, fail: 3, warn: 0, error: 0, skip: 0

# ── CRITICAL: If the flawed manifest PASSES, the CI gate (Stage 11) is broken ──
# This would mean Kyverno is not enforcing the policies correctly.
# Check that the policies have: validationFailureAction: Enforce (not Audit)
grep "validationFailureAction" infrastructure/kyverno-policies/*.yaml
# Expected: Enforce (3 lines, one per file)
```

#### D.3 — Test individual policies in isolation

```bash
# Test only the no-root policy
kyverno apply \
  infrastructure/kyverno-policies/no-root-containers.yaml \
  --resource k8s/flawed-deployment.yaml

# Expected: fail: 1 (just the root container violation)

# Test only the resource limits policy
kyverno apply \
  infrastructure/kyverno-policies/require-resource-limits.yaml \
  --resource k8s/flawed-deployment.yaml

# Expected: fail: 1 (missing limits violation)

# Test only the ECR policy
# NOTE: replace 320644184091 in the policy file first (Phase 3.6)
kyverno apply \
  infrastructure/kyverno-policies/ecr-only-images.yaml \
  --resource k8s/flawed-deployment.yaml

# Expected: fail: 1 (non-ECR image violation)
```

---

### Section E: Security Tool Scans (Local)

#### E.1 — Gitleaks (secret scanning)

```bash
# From repo root — scan all files
gitleaks detect --source . --config .gitleaks.toml --verbose

# Expected output on a clean scan (flaw1 is in the allowlist):
# ○  No leaks detected.

# Run specifically against the flaw file (with allowlist — should be clean)
gitleaks detect --source . --config .gitleaks.toml --verbose 2>&1 | grep -i "flaw\|secret\|key\|leak"

# To test that Gitleaks CAN detect the flaw (temporarily disable allowlist):
gitleaks detect --source . --no-git --verbose 2>&1 | grep "Finding"
# Expected: 1-2 findings in app/flaws/flaw1_secret.txt
#   Finding: "AKIAIOSFODNN7EXAMPLE" matched rule "aws-access-key-id"
```

#### E.2 — pip-audit (dependency vulnerability scanning)

```bash
# In app/ with venv active
cd app/
pip-audit -r requirements.txt --output-format json > /tmp/pip-audit-report.json

# View human-readable summary
pip-audit -r requirements.txt

# Expected: "No known vulnerabilities found" OR list of CVEs with remediation
# If vulnerabilities found: check if they have fixed versions in requirements.txt
```

#### E.3 — Semgrep (SAST — static application security testing)

```bash
# From repo root
# Scan the app/ directory with OWASP rules
semgrep scan \
  --config "p/owasp-top-ten" \
  --config "p/python" \
  app/ \
  --text

# Expected output:
# Findings:
#   app/flaws/flaw2_sast.py:8  [python.lang.security.dangerous-eval-use]
#     Use of eval() with user input (CWE-94: Code Injection)
#   app/flaws/flaw2_sast.py:12 [python.lang.security.audit.subprocess-shell-true]
#     subprocess.run() with shell=True (CWE-78: OS Command Injection)
#   app/flaws/flaw2_sast.py:15 [python.lang.security.hardcoded-password-string]
#     Hardcoded password string (CWE-798)
#
# Ran 450 rules. Findings: 3

# Verify main.py (production code) has ZERO findings:
semgrep scan --config "p/owasp-top-ten" app/main.py --text
# Expected: Ran 450 rules. Findings: 0

# Generate SARIF output (same format as CI pipeline)
semgrep scan \
  --config "p/owasp-top-ten" \
  app/ \
  --sarif \
  --output /tmp/semgrep-results.sarif
```

---

### Section F: Run All Local Checks with a Single Script

After completing Sections A–E individually to understand each tool, you can run all local checks together to simulate the CI pipeline locally:

```bash
# Create a local check script (run from repo root)
cat > /tmp/local-ci-check.sh << 'SCRIPT'
#!/bin/bash
set -e

REPO_ROOT=$(pwd)
PASS=0
FAIL=0
WARN=0

check() {
  local name="$1"
  local cmd="$2"
  echo -n "  [$name] ... "
  if eval "$cmd" > /tmp/check-output.txt 2>&1; then
    echo "PASS"
    PASS=$((PASS+1))
  else
    echo "FAIL"
    cat /tmp/check-output.txt | tail -5
    FAIL=$((FAIL+1))
  fi
}

echo ""
echo "═══════════════════════════════════════════════"
echo "  Genesis Platform — Local CI Simulation"
echo "═══════════════════════════════════════════════"
echo ""

echo "── Stage 1: Secret Scanning (Gitleaks) ────────"
check "gitleaks" "gitleaks detect --source . --config .gitleaks.toml"

echo ""
echo "── Stage 2: Dependency Audit (pip-audit) ───────"
check "pip-audit" "cd app && pip-audit -r requirements.txt"

echo ""
echo "── Stage 3: SAST (Semgrep) ─────────────────────"
check "semgrep-main" "semgrep scan --config p/owasp-top-ten app/main.py --error"
echo "  (flaw2_sast.py findings expected — not checked here)"

echo ""
echo "── Stage 4: Unit Tests (pytest ≥75%) ───────────"
check "pytest" "cd $REPO_ROOT/app && python3 -m pytest tests/ -q --cov=. --cov-fail-under=75"

echo ""
echo "── Stage 5: Docker Build ────────────────────────"
check "docker-build" "cd app && docker build -t genesis-api-ci-test:local . --quiet"

echo ""
echo "── Stage 9: tflint ─────────────────────────────"
check "tflint-networking" "tflint --chdir infrastructure/modules/networking"
check "tflint-compute" "tflint --chdir infrastructure/modules/compute"

echo ""
echo "── Stage 10: Checkov ────────────────────────────"
check "checkov" "checkov -d infrastructure/ --framework terraform --quiet"

echo ""
echo "── Stage 11: Kyverno Offline ────────────────────"
check "kyverno-clean" "kyverno apply infrastructure/kyverno-policies/ --resource k8s/rollout.yaml"
# Flawed manifest is EXPECTED to fail — a pass here means the demo is set up
echo "  (Verifying flawed-deployment.yaml FAILS as expected...)"
FLAWED_EXIT=0
kyverno apply infrastructure/kyverno-policies/ --resource k8s/flawed-deployment.yaml > /tmp/flawed-check.txt 2>&1 || FLAWED_EXIT=$?
if grep -q "fail: [1-9]" /tmp/flawed-check.txt; then
  echo "  [kyverno-flawed] PASS (correctly blocked — fail count > 0)"
  PASS=$((PASS+1))
else
  echo "  [kyverno-flawed] FAIL (flawed manifest was NOT blocked — check policies)"
  FAIL=$((FAIL+1))
fi

echo ""
echo "── Stage ∞: OPA/Conftest ───────────────────────"
check "conftest-compliant" "conftest test --policy infrastructure/conftest-policies/kubernetes.rego infrastructure/conftest-policies/test/compliant_deployment.yaml"

echo ""
echo "═══════════════════════════════════════════════"
echo "  Results: PASS=$PASS  FAIL=$FAIL  WARN=$WARN"
echo "═══════════════════════════════════════════════"
if [ "$FAIL" -gt 0 ]; then
  echo "  FIX failures above before pushing to GitHub."
  exit 1
else
  echo "  All local checks passed. Safe to push."
fi
SCRIPT

chmod +x /tmp/local-ci-check.sh
/tmp/local-ci-check.sh
```

**Windows PowerShell equivalent:**
```powershell
# Run from repo root

$pass=0; $fail=0

function Check-Step([string]$name, [scriptblock]$cmd) {
  Write-Host "  [$name] ... " -NoNewline
  try {
    & $cmd *>$null
    if ($LASTEXITCODE -eq 0) { Write-Host "PASS" -ForegroundColor Green; $global:pass++ }
    else { throw "exit $LASTEXITCODE" }
  } catch {
    Write-Host "FAIL" -ForegroundColor Red; $global:fail++
  }
}

Write-Host "`n═══════════════ Local CI Simulation ══════════════"
Check-Step "gitleaks"        { gitleaks detect --source . --config .gitleaks.toml }
Check-Step "pip-audit"       { Set-Location app; pip-audit -r requirements.txt }
Check-Step "pytest"          { Set-Location app; py -m pytest tests/ -q --cov=. --cov-fail-under=75 }
Check-Step "docker-build"    { Set-Location app; docker build -t genesis-api-ci-test:local . --quiet }
Check-Step "tflint"          { tflint --chdir infrastructure\modules\networking }
Check-Step "checkov"         { checkov -d infrastructure --framework terraform --quiet }
Check-Step "kyverno-clean"   { kyverno apply infrastructure\kyverno-policies\ --resource k8s\rollout.yaml }
Check-Step "conftest"        { conftest test --policy infrastructure\conftest-policies\kubernetes.rego infrastructure\conftest-policies\test\compliant_deployment.yaml }

Write-Host "══════════════ Results: PASS=$pass FAIL=$fail ═══════════"
if ($fail -gt 0) { Write-Host "Fix failures before pushing." -ForegroundColor Red; exit 1 }
else { Write-Host "All local checks passed. Safe to push." -ForegroundColor Green }
```

---



### 1.1 — Find your AWS Account ID

Log in to the AWS Console → click your username (top right) → **Account ID** is the 12-digit number shown.

**Write this down — you will use it many times:**
```
YOUR_ACCOUNT_ID = 320644184091    ← replace with your real 12-digit ID
```

### 1.2 — Create a Bootstrap IAM User (one-time only)

This user is needed only for the initial Terraform run. After Terraform creates the OIDC role, GitHub Actions uses OIDC and this user is no longer needed.

1. AWS Console → **IAM** → **Users** → **Create user**
2. Username: `terraform-bootstrap`
3. Attach policy: `AdministratorAccess` (temporary — for bootstrap only)
4. Create user → **Security credentials** tab → **Create access key** → CLI use case
5. Download the CSV or copy the Access Key ID and Secret Access Key

### 1.3 — Configure AWS CLI

```bash
aws configure --profile terraform-bootstrap
# AWS Access Key ID: <paste from step 1.2>
# AWS Secret Access Key: <paste from step 1.2>
# Default region: ap-south-1
# Default output: json

# Verify
aws sts get-caller-identity --profile terraform-bootstrap
# Expected output:
# {
#   "UserId": "AIDAIOSFODNN7EXAMPLE",
#   "Account": "320644184091",
#   "Arn": "arn:aws:iam::320644184091:user/terraform-bootstrap"
# }
```

### 1.4 — Create an EC2 SSH Key Pair

This is the SSH key you will use to connect to your k3s EC2 instance.

**Option A — Generate locally and import to AWS:**
```bash
# Generate key pair
ssh-keygen -t ed25519 -C "genesis-k3s" -f ~/.ssh/genesis-k3s
# Press Enter twice for no passphrase (or set one — you'll need it every SSH)

# View the public key (you need this for terraform.tfvars)
cat ~/.ssh/genesis-k3s.pub
# Output: ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAA... genesis-k3s

# Import to AWS
aws ec2 import-key-pair \
  --key-name "genesis-k3s" \
  --public-key-material fileb://~/.ssh/genesis-k3s.pub \
  --region ap-south-1 \
  --profile terraform-bootstrap

# Verify
aws ec2 describe-key-pairs --key-names genesis-k3s --region ap-south-1 --profile terraform-bootstrap
```

The `k3s_ssh_public_key` value for `terraform.tfvars` is the full content of `~/.ssh/genesis-k3s.pub`:
```
ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIxxxxxxxx genesis-k3s
```

### 1.5 — Confirm Free-Tier Region

Verify you are working in `ap-south-1` (North Virginia). All resources in this project are in that region. The EC2 t3.micro free tier applies to a single region.

```bash
aws ec2 describe-regions --region-names ap-south-1 --profile terraform-bootstrap
```

---

## Phase 2: GitHub Repository Setup

### 2.1 — Create the Repository

```bash
# Option A — GitHub CLI
gh repo create genesis-devsecops-papun --public --description "DevSecOps Platform"
cd /path/to/your/local/project

# Option B — GitHub UI
# Go to https://github.com/new
# Repository name: genesis-devsecops-papun
# Visibility: Public (required for free Actions minutes)
# Do NOT initialise with README (you already have files)
```

### 2.2 — Push the codebase

```bash
cd c:\Clouddev\devsecops-papun   # or wherever your project is

# Initialise git if not already done
git init
git remote add origin https://github.com/YOUR_GITHUB_USERNAME/genesis-devsecops-papun.git

# Initial commit — all files EXCEPT the flaws (add those in a later branch for demo)
git add .
git commit -m "feat: initial DevSecOps platform implementation"
git branch -M main
git push -u origin main
```

**Important**: Note your GitHub username/org. It appears in many places:
```
YOUR_GITHUB_ORG = myusername    ← your GitHub username or org name
```

### 2.3 — Enable GitHub Actions

1. Repository → **Settings** → **Actions** → **General**
2. Set: **Allow all actions and reusable workflows**
3. Under **Workflow permissions**: select **Read and write permissions**
4. Check **Allow GitHub Actions to create and approve pull requests**
5. Click **Save**

### 2.4 — Set Branch Protection on `main`

1. Repository → **Settings** → **Branches** → **Add branch protection rule**
2. Branch name pattern: `main`
3. Check all of the following:
   - ✅ Require a pull request before merging
   - ✅ Require approvals: 1
   - ✅ Require status checks to pass before merging
   - ✅ Require branches to be up to date
   - ✅ Require signed commits (optional but good practice)
   - ✅ Do not allow bypassing the above settings
4. Click **Save changes**

---

## Phase 3: Replace All Placeholder Values

**Do this before running any Terraform command.** Open each file below and replace the values as shown. Use your actual values from Phases 1 and 2.

### 3.1 — Master substitution table

| Placeholder | What to replace with | Example |
|-------------|---------------------|---------|
| `320644184091` | Your 12-digit AWS account ID | `320644184091` |
| `REPLACE_WITH_GITHUB_ORG` | Your GitHub username or org | `johndoe` |
| `REPLACE_GITHUB_ORG` | Same as above | `johndoe` |
| `REPLACE_WITH_YOUR_PUBLIC_SSH_KEY` | Full content of `~/.ssh/genesis-k3s.pub` | `ssh-ed25519 AAAA...` |
| `REPLACE_WITH_YOUR_EMAIL` | Your email for CloudWatch SNS alerts | `you@example.com` |
| `REPLACE_WITH_OPS_EMAIL` | Ops team email (prod) | `ops@example.com` |
| `REPLACE_WITH_VPN_OR_BASTION_CIDR` | Your IP or VPN CIDR for SSH in prod | `203.0.113.10/32` |

### 3.2 — `infrastructure/environments/dev/terraform.tfvars`

```bash
# Open the file and replace these 4 values:
k3s_ssh_public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIxxxxxx genesis-k3s"
github_org         = "johndoe"
alarm_email        = "you@example.com"
state_bucket_name  = "genesis-devsecops-terraform-state-320644184091"
```

Do NOT change `aws_region`, `project`, `environment`, `vpc_cidr` — they are already correct.

### 3.3 — `infrastructure/environments/dev/backend.hcl`

```
bucket         = "genesis-devsecops-terraform-state-320644184091"
key            = "dev/terraform.tfstate"
region         = "ap-south-1"
dynamodb_table = "genesis-terraform-state-lock"
encrypt        = true
```

### 3.4 — `infrastructure/environments/prod/terraform.tfvars`

Same pattern as dev but with prod values:
```bash
k3s_ssh_public_key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIxxxxxx genesis-k3s"
github_org         = "johndoe"
alarm_email        = "ops@example.com"
admin_cidr         = "203.0.113.10/32"   # Your office/VPN IP
state_bucket_name  = "genesis-devsecops-terraform-state-320644184091"
```

### 3.5 — `infrastructure/environments/prod/backend.hcl`

```
bucket = "genesis-devsecops-terraform-state-320644184091"
key    = "prod/terraform.tfstate"
```

### 3.6 — `infrastructure/kyverno-policies/ecr-only-images.yaml`

```bash
# Find the line with 320644184091 and replace it
# Before:
#   value: "320644184091.dkr.ecr.ap-south-1.amazonaws.com"
# After:
#   value: "320644184091.dkr.ecr.ap-south-1.amazonaws.com"

sed -i 's/320644184091/320644184091/g' infrastructure/kyverno-policies/ecr-only-images.yaml
# Windows PowerShell:
(Get-Content infrastructure\kyverno-policies\ecr-only-images.yaml) -replace '320644184091','320644184091' | Set-Content infrastructure\kyverno-policies\ecr-only-images.yaml
```

### 3.7 — `k8s/argocd-app.yaml`

```bash
# Change repoURL to your actual GitHub repo
# Before:
#   repoURL: https://github.com/REPLACE_GITHUB_ORG/genesis-devsecops-papun.git
# After:
#   repoURL: https://github.com/johndoe/genesis-devsecops-papun.git

sed -i 's/REPLACE_GITHUB_ORG/johndoe/g' k8s/argocd-app.yaml
# Windows:
(Get-Content k8s\argocd-app.yaml) -replace 'REPLACE_GITHUB_ORG','johndoe' | Set-Content k8s\argocd-app.yaml
```

### 3.8 — `k8s/rollout.yaml`

The `REPLACE_GIT_SHA` in rollout.yaml is expected — the pipeline replaces it at deploy time. Leave it.  
Replace only `320644184091`:

```bash
sed -i 's/320644184091/320644184091/g' k8s/rollout.yaml
# Windows:
(Get-Content k8s\rollout.yaml) -replace '320644184091','320644184091' | Set-Content k8s\rollout.yaml
```

### 3.9 — `k8s/prometheus-rules.yaml`

```bash
sed -i 's/REPLACE_GITHUB_ORG/johndoe/g' k8s/prometheus-rules.yaml
# Windows:
(Get-Content k8s\prometheus-rules.yaml) -replace 'REPLACE_GITHUB_ORG','johndoe' | Set-Content k8s\prometheus-rules.yaml
```

### 3.10 — `.github/CODEOWNERS`

```bash
# Replace REPLACE_GITHUB_ORG with your GitHub org/username
# Example: @johndoe/senior-platform-engineers → if working alone, use just @johndoe
# Change all occurrences in the file

# Windows:
(Get-Content .github\CODEOWNERS) -replace 'REPLACE_GITHUB_ORG','johndoe' | Set-Content .github\CODEOWNERS
```

### 3.11 — `infrastructure/conftest-policies/test/compliant_deployment.yaml`

```bash
(Get-Content infrastructure\conftest-policies\test\compliant_deployment.yaml) -replace '320644184091','320644184091' | Set-Content infrastructure\conftest-policies\test\compliant_deployment.yaml
```

### 3.12 — Commit all replacements

```bash
git add -A
git commit -m "chore: replace all placeholder values with real configuration"
git push origin main
```

### 3.13 — Verify zero remaining REPLACE_ placeholders

```bash
# Linux/macOS
grep -rn '320644184091\|REPLACE_WITH_GITHUB_ORG\|REPLACE_WITH_YOUR' \
  infrastructure/ k8s/ .github/

# Windows PowerShell
Get-ChildItem -Recurse -File | Where-Object{$_.FullName -notmatch '\\\.git\\'} | `
  ForEach-Object{ Select-String -Path $_.FullName -Pattern "320644184091|REPLACE_WITH_GITHUB_ORG|REPLACE_WITH_YOUR" } | `
  Select-Object Filename, LineNumber, Line

# Expected: no output (zero results)
# Exception: k8s/rollout.yaml REPLACE_GIT_SHA is OK — pipeline sets it at deploy time
```

---

## Phase 4: Bootstrap AWS State Backend

The S3 bucket and DynamoDB table must exist BEFORE you run `terraform init`. This is the chicken-and-egg problem: Terraform needs a backend, but the backend is not yet created. The bootstrap scripts create both without Terraform.

### 4.1 — Run the bootstrap script

```bash
# Linux / macOS
chmod +x scripts/bootstrap.sh
AWS_PROFILE=terraform-bootstrap ./scripts/bootstrap.sh

# Windows PowerShell
$env:AWS_PROFILE = "terraform-bootstrap"
.\scripts\bootstrap.ps1
```

The script will create:
- S3 bucket: `genesis-devsecops-terraform-state-320644184091` (versioning + AES-256 + public access blocked)
- S3 bucket for access logs: `genesis-devsecops-terraform-state-320644184091-logs`
- DynamoDB table: `genesis-terraform-state-lock` (PAY_PER_REQUEST)

### 4.2 — Verify backend was created

```bash
aws s3 ls s3://genesis-devsecops-terraform-state-320644184091 --profile terraform-bootstrap
# Expected: (empty — no files yet, but no error)

aws dynamodb describe-table \
  --table-name genesis-terraform-state-lock \
  --region ap-south-1 \
  --profile terraform-bootstrap \
  --query 'Table.TableStatus'
# Expected: "ACTIVE"
```

---

## Phase 5: Terraform First Run

### 5.1 — Navigate to the dev environment

```bash
cd infrastructure/environments/dev
```

### 5.2 — Export the bootstrap profile

```bash
# Linux / macOS
export AWS_PROFILE=terraform-bootstrap

# Windows PowerShell
$env:AWS_PROFILE = "terraform-bootstrap"
```

### 5.3 — Initialise Terraform with the remote backend

```bash
terraform init -backend-config=backend.hcl
```

Expected output:
```
Initializing the backend...
Successfully configured the backend "s3"!
Initializing modules...
Initializing provider plugins...
Terraform has been successfully initialized!
```

If you see `Error: Failed to get existing workspaces`: the S3 bucket does not exist yet. Go back to Phase 4.

### 5.4 — Validate configuration

```bash
terraform validate
# Expected: Success! The configuration is valid.
```

### 5.5 — Check formatting

```bash
terraform fmt -check -recursive
# Expected: no output (already formatted)
# If files are listed: run terraform fmt -recursive to fix them
```

### 5.6 — Generate and review the plan

```bash
terraform plan -var-file=terraform.tfvars -out=tfplan.binary 2>&1 | tee /tmp/tfplan.txt

# Review what will be created — expected resources:
# + module.networking.aws_vpc.main
# + module.networking.aws_subnet.public[0,1]
# + module.networking.aws_subnet.private[0,1]
# + module.networking.aws_internet_gateway.main
# + module.networking.aws_security_group.k3s
# + module.iam.aws_iam_role.k3s_node
# + module.iam.aws_iam_role.github_actions
# + module.iam.aws_iam_openid_connect_provider.github
# + module.ecr.aws_ecr_repository.app
# + module.compute.aws_instance.k3s
# + module.compute.aws_eip.k3s
# + module.observability.aws_cloudwatch_log_group.k3s
# + module.observability.aws_sns_topic.alerts
# (approximately 25-30 resources)
```

### 5.7 — Apply infrastructure

```bash
terraform apply tfplan.binary
# This takes 3-8 minutes. The EC2 instance boots and runs userdata.sh.tpl
# which installs k3s, Helm, Argo CD, Kyverno, etc. That takes another 10-15 minutes.
```

Expected final output:
```
Apply complete! Resources: 28 added, 0 changed, 0 destroyed.

Outputs:
k3s_public_ip      = "54.123.45.67"
ecr_repository_url = "320644184091.dkr.ecr.ap-south-1.amazonaws.com/genesis-platform-api"
github_actions_role_arn = "arn:aws:iam::320644184091:role/genesis-dev-github-actions-role"
```

**Save these output values** — you need them in Phase 11.

### 5.8 — Wait for EC2 userdata to complete

The userdata script (k3s + Helm installs) runs in the background after Terraform completes. Wait 10-15 minutes before SSH-ing in. You can monitor it:

```bash
K3S_IP=$(terraform output -raw k3s_public_ip)

# Wait for SSH to be available
until ssh -i ~/.ssh/genesis-k3s -o StrictHostKeyChecking=no \
  ec2-user@$K3S_IP "echo ready" 2>/dev/null; do
  echo "Waiting for EC2 to be ready..."
  sleep 10
done
echo "EC2 is reachable!"

# Then check userdata progress
ssh -i ~/.ssh/genesis-k3s ec2-user@$K3S_IP \
  "sudo cat /var/log/cloud-init-output.log | tail -30"
```

Wait until you see: `k3s bootstrap complete for genesis-dev`

---

## Phase 6: Connect to k3s Cluster

### 6.1 — SSH into the EC2 instance

```bash
K3S_IP=54.123.45.67    # replace with your Terraform output value

ssh -i ~/.ssh/genesis-k3s ec2-user@$K3S_IP
```

### 6.2 — Verify k3s is running (on the EC2 instance)

```bash
# All commands below run ON the EC2 instance (after SSH)

sudo k3s kubectl get nodes
# Expected:
# NAME              STATUS   ROLES                  AGE   VERSION
# ip-10-0-1-xxx     Ready    control-plane,master   15m   v1.29.x+k3s1

sudo systemctl status k3s
# Expected: Active: active (running)
```

### 6.3 — Copy kubeconfig to your local machine

```bash
# On the EC2 instance — get the kubeconfig
sudo cat /etc/rancher/k3s/k3s.yaml
# Copy the entire output

# BACK ON YOUR LOCAL MACHINE:
mkdir -p ~/.kube

# Paste the kubeconfig content into a temp file
cat > /tmp/k3s-config.yaml << 'EOF'
<paste the full content of /etc/rancher/k3s/k3s.yaml here>
EOF

# The server IP in kubeconfig will be 127.0.0.1:6443 — replace with public IP
sed "s/127.0.0.1/$K3S_IP/g" /tmp/k3s-config.yaml > ~/.kube/config-genesis-k3s
chmod 600 ~/.kube/config-genesis-k3s

# Set this as your active kubeconfig
export KUBECONFIG=~/.kube/config-genesis-k3s

# Windows PowerShell:
$env:KUBECONFIG = "$HOME\.kube\config-genesis-k3s"
```

### 6.4 — Verify kubectl works from your local machine

```bash
kubectl get nodes
# Expected:
# NAME              STATUS   ROLES                  AGE   VERSION
# ip-10-0-1-xxx     Ready    control-plane,master   20m   v1.29.x+k3s1

kubectl get namespaces
# Expected (created by userdata):
# NAME              STATUS   AGE
# default           Active   20m
# kube-system       Active   20m
# argocd            Active   15m
# argo-rollouts     Active   15m
# kyverno           Active   15m
# monitoring        Active   15m
```

### 6.5 — Encode kubeconfig for GitHub Secrets

```bash
# Linux / macOS
cat ~/.kube/config-genesis-k3s | base64 -w 0
# Copy this output — you'll need it as the K3S_KUBECONFIG_B64 secret in Phase 11

# Windows PowerShell
[Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes((Get-Content ~/.kube/config-genesis-k3s -Raw)))
```

---

## Phase 7: Verify All In-Cluster Components

All commands run from your local machine with `KUBECONFIG` set as above.

### 7.1 — Argo CD

```bash
kubectl get pods -n argocd
# Expected (all pods Running):
# argocd-application-controller-0         1/1     Running
# argocd-dex-server-xxxxxxx               0/1     ... (OK if not running — dex disabled)
# argocd-redis-xxxxxxx                    1/1     Running
# argocd-repo-server-xxxxxxx              1/1     Running
# argocd-server-xxxxxxx                   1/1     Running

# Get the Argo CD NodePort
kubectl get svc argocd-server -n argocd
# Expected:
# NAME            TYPE       CLUSTER-IP    EXTERNAL-IP   PORT(S)                      AGE
# argocd-server   NodePort   10.43.x.x     <none>        80:30080/TCP,443:30443/TCP   15m
```

Access Argo CD in browser: `http://YOUR_K3S_IP:30080`

Get the initial admin password:
```bash
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d && echo
# Copy this password — you will need it to:
# 1. Log in to the Argo CD UI
# 2. Set as ARGOCD_PASSWORD GitHub Secret (Phase 11)
```

### 7.2 — Kyverno

```bash
kubectl get pods -n kyverno
# Expected (all Running):
# kyverno-admission-controller-xxxxxxx    1/1     Running
# kyverno-background-controller-xxxxxxx  1/1     Running
# kyverno-cleanup-controller-xxxxxxx     1/1     Running
# kyverno-reports-controller-xxxxxxx     1/1     Running

# Verify Kyverno webhook is active
kubectl get validatingwebhookconfigurations | grep kyverno
# Expected: 2-3 webhook entries
```

### 7.3 — Argo Rollouts

```bash
kubectl get pods -n argo-rollouts
# Expected:
# argo-rollouts-xxxxxxx    1/1     Running

# Install the kubectl argo rollouts plugin
curl -LO https://github.com/argoproj/argo-rollouts/releases/latest/download/kubectl-argo-rollouts-linux-amd64
sudo install -m 0755 kubectl-argo-rollouts-linux-amd64 /usr/local/bin/kubectl-argo-rollouts
kubectl argo rollouts version
```

### 7.4 — Prometheus + Grafana

```bash
kubectl get pods -n monitoring
# Expected (all Running):
# alertmanager-kube-prometheus-stack-alertmanager-0   2/2   Running
# kube-prometheus-stack-grafana-xxxxxxx               3/3   Running
# kube-prometheus-stack-operator-xxxxxxx              1/1   Running
# kube-prometheus-stack-prometheus-0                  2/2   Running
# (plus several kube-state-metrics and node-exporter pods)

# Get Grafana NodePort (if exposed)
kubectl get svc -n monitoring | grep grafana
```

If Grafana is not exposed via NodePort, port-forward:
```bash
kubectl port-forward svc/kube-prometheus-stack-grafana 3000:80 -n monitoring &
# Access: http://localhost:3000
# Username: admin
# Password:
kubectl get secret kube-prometheus-stack-grafana \
  -n monitoring \
  -o jsonpath="{.data.admin-password}" | base64 -d && echo
```

---

## Phase 8: Manual Helm Installs (Fallback)

Run this section ONLY if Phase 7 shows pods not running. The userdata script should have done all of this automatically, but EC2 userdata can fail silently.

```bash
# Export kubeconfig
export KUBECONFIG=~/.kube/config-genesis-k3s

# Add Helm repos (if not already added)
helm repo add argo       https://argoproj.github.io/argo-helm
helm repo add kyverno    https://kyverno.github.io/kyverno/
helm repo add prometheus https://prometheus-community.github.io/helm-charts
helm repo update

# Install Argo CD (if not running)
helm install argocd argo/argo-cd \
  --namespace argocd \
  --create-namespace \
  --values k8s/argocd-values.yaml \
  --wait --timeout 10m

# Install Argo Rollouts (if not running)
helm install argo-rollouts argo/argo-rollouts \
  --namespace argo-rollouts \
  --create-namespace \
  --set dashboard.enabled=true \
  --wait --timeout 5m

# Install Kyverno (if not running)
helm install kyverno kyverno/kyverno \
  --namespace kyverno \
  --create-namespace \
  --wait --timeout 10m

# Install kube-prometheus-stack (if not running)
helm install kube-prometheus-stack prometheus/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false \
  --set grafana.service.type=NodePort \
  --set grafana.service.nodePort=32000 \
  --wait --timeout 15m
```

---

## Phase 9: Apply Kyverno Policies

The Kyverno pods must be running (Phase 7.2) before applying policies. The admission webhook must be active or policy application will fail.

### 9.1 — Apply the three ClusterPolicies

```bash
kubectl apply -f infrastructure/kyverno-policies/no-root-containers.yaml
kubectl apply -f infrastructure/kyverno-policies/require-resource-limits.yaml
kubectl apply -f infrastructure/kyverno-policies/ecr-only-images.yaml

# Wait for policies to be ready
kubectl get clusterpolicies
# Expected:
# NAME                    ADMISSION   BACKGROUND   READY   AGE
# ecr-only-images         true        true         True    10s
# no-root-containers      true        true         True    10s
# require-resource-limits true        true         True    10s
```

### 9.2 — Verify policies are in Enforce mode

```bash
kubectl get clusterpolicy no-root-containers -o jsonpath='{.spec.validationFailureAction}'
# Expected: Enforce

kubectl get clusterpolicy require-resource-limits -o jsonpath='{.spec.validationFailureAction}'
# Expected: Enforce

kubectl get clusterpolicy ecr-only-images -o jsonpath='{.spec.validationFailureAction}'
# Expected: Enforce
```

### 9.3 — Quick policy smoke test

```bash
# Test no-root policy: try to create a root container (should be BLOCKED)
kubectl run test-root \
  --image=nginx:alpine \
  --namespace=staging \
  --overrides='{"spec":{"securityContext":{"runAsNonRoot":false}}}' \
  --dry-run=server 2>&1

# Expected: Error from server: ... violation: no-root-containers

# Test allow: valid manifest should pass
kubectl run test-valid \
  --image=320644184091.dkr.ecr.ap-south-1.amazonaws.com/genesis-platform-api:test \
  --namespace=staging \
  --dry-run=server \
  --overrides='{"spec":{"securityContext":{"runAsNonRoot":true},"containers":[{"name":"test-valid","resources":{"limits":{"cpu":"100m","memory":"128Mi"}}}]}}' 2>&1
```

---

## Phase 10: Push the First Image to ECR

Argo CD will try to pull the image referenced in `rollout.yaml`. The image must exist in ECR before the first sync, or pods will fail with `ImagePullBackOff`. Push a first image manually now.

### 10.1 — Authenticate Docker to ECR

```bash
ECR_REGISTRY="320644184091.dkr.ecr.ap-south-1.amazonaws.com"

aws ecr get-login-password \
  --region ap-south-1 \
  --profile terraform-bootstrap | \
docker login \
  --username AWS \
  --password-stdin $ECR_REGISTRY

# Expected: Login Succeeded
```

### 10.2 — Build and push the initial image

```bash
cd app/

# Build
docker build -t genesis-platform-api:initial .

# Tag with SHA (use 'initial' as first tag)
docker tag genesis-platform-api:initial \
  $ECR_REGISTRY/genesis-platform-api:sha-initial

# Push
docker push $ECR_REGISTRY/genesis-platform-api:sha-initial

# Verify in ECR
aws ecr list-images \
  --repository-name genesis-platform-api \
  --region ap-south-1 \
  --profile terraform-bootstrap
# Expected: shows sha-initial tag
```

### 10.3 — Update rollout.yaml with the initial image tag

```bash
# Replace REPLACE_GIT_SHA with sha-initial for the first deploy
sed -i 's/REPLACE_GIT_SHA/sha-initial/g' k8s/rollout.yaml

# Verify
grep "image:" k8s/rollout.yaml
# Expected:
# image: 320644184091.dkr.ecr.ap-south-1.amazonaws.com/genesis-platform-api:sha-initial

cd ..
git add k8s/rollout.yaml
git commit -m "chore: set initial ECR image tag for first Argo CD sync"
git push origin main
```

### 10.4 — Create the ECR pull secret in the staging namespace

```bash
# First create the staging namespace
kubectl create namespace staging --dry-run=client -o yaml | kubectl apply -f -

# Create ECR pull secret
ECR_PASSWORD=$(aws ecr get-login-password --region ap-south-1 --profile terraform-bootstrap)

kubectl create secret docker-registry ecr-credentials \
  --docker-server=320644184091.dkr.ecr.ap-south-1.amazonaws.com \
  --docker-username=AWS \
  --docker-password="$ECR_PASSWORD" \
  --namespace=staging

# Verify
kubectl get secret ecr-credentials -n staging
```

---

## Phase 11: GitHub Actions Secrets

Navigate to: `https://github.com/YOUR_GITHUB_USERNAME/genesis-devsecops-papun/settings/secrets/actions`

Add each of the following secrets using the **New repository secret** button:

### 11.1 — AWS_DEPLOY_ROLE_ARN

```
Name:  AWS_DEPLOY_ROLE_ARN
Value: arn:aws:iam::320644184091:role/genesis-dev-github-actions-role
       ↑ Get this from: terraform output github_actions_role_arn
```

### 11.2 — ARGOCD_SERVER

```
Name:  ARGOCD_SERVER
Value: 54.123.45.67:30080
       ↑ format: YOUR_K3S_IP:30080 (no http://, no trailing slash)
```

### 11.3 — ARGOCD_PASSWORD

```
Name:  ARGOCD_PASSWORD
Value: <the initial admin password from Phase 7.1>
       ↑ kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

### 11.4 — K3S_PUBLIC_IP

```
Name:  K3S_PUBLIC_IP
Value: 54.123.45.67
       ↑ Just the IP, no port
```

### 11.5 — K3S_KUBECONFIG_B64

```
Name:  K3S_KUBECONFIG_B64
Value: <base64-encoded kubeconfig from Phase 6.5>
```

### 11.6 — SEMGREP_APP_TOKEN (optional)

```
Name:  SEMGREP_APP_TOKEN
Value: <get from https://semgrep.dev/orgs/-/settings/tokens>
       ↑ If you skip this, remove the SEMGREP_APP_TOKEN env line from security-scan.yml
       ↑ Semgrep still runs without a token — just without cloud dashboard
```

### 11.7 — Verify all secrets are set

Go to `Settings → Secrets and variables → Actions` — you should see 5-6 secrets listed (values are hidden, that is expected).

---

## Phase 12: Wire Argo CD GitOps

### 12.1 — Log in to Argo CD UI

Open browser: `http://YOUR_K3S_IP:30080`
- Username: `admin`
- Password: from Phase 7.1

### 12.2 — Log in with Argo CD CLI

```bash
argocd login YOUR_K3S_IP:30080 \
  --username admin \
  --password "$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d)" \
  --insecure \
  --grpc-web

# Expected: 'admin:login' logged in successfully
```

### 12.3 — Add your GitHub repo to Argo CD (for private repos)

If your repo is **public**, skip this step. For private repos:

```bash
# Create a GitHub Personal Access Token first:
# GitHub → Settings → Developer settings → Personal access tokens → Tokens (classic)
# → Generate new token → Scopes: repo (full control)

argocd repo add https://github.com/YOUR_GITHUB_USERNAME/genesis-devsecops-papun.git \
  --username YOUR_GITHUB_USERNAME \
  --password YOUR_GITHUB_PAT \
  --insecure-skip-server-verification

# Verify
argocd repo list
```

### 12.4 — Create the Argo CD Application

```bash
# Apply the Application CRD
kubectl apply -f k8s/argocd-app.yaml

# Verify it was created
kubectl get application -n argocd
# Expected:
# NAME                    SYNC STATUS   HEALTH STATUS
# genesis-platform-api    Unknown       Unknown     ← will change after first sync
```

### 12.5 — Trigger initial sync

```bash
argocd app sync genesis-platform-api

# Watch sync progress
argocd app wait genesis-platform-api --sync --health --timeout 120

# Check final status
argocd app get genesis-platform-api
# Expected:
# Name:       genesis-platform-api
# Sync Status: Synced
# Health Status: Healthy (or Progressing if pods are starting)
```

### 12.6 — Verify via UI

In the Argo CD browser UI, you should now see:
- `genesis-platform-api` application tile
- Green **Synced** and **Healthy** badges (may take 2-3 minutes for pods to start)

---

## Phase 13: Apply k8s Supporting Resources

### 13.1 — Apply all k8s manifests

Argo CD will apply them automatically once wired (Phase 12). But for the first time, verify they were applied:

```bash
# Check what Argo CD applied
kubectl get all -n staging

# Expected (after Argo CD sync):
# pod/genesis-platform-api-xxxxxxx   1/1   Running
# service/genesis-platform-api-stable    ClusterIP
# service/genesis-platform-api-canary    ClusterIP
# rollout.argoproj.io/genesis-platform-api
# analysistemplate.argoproj.io/genesis-api-error-rate
```

### 13.2 — Verify the Rollout is healthy

```bash
kubectl argo rollouts get rollout genesis-platform-api -n staging
# Expected:
# Name:            genesis-platform-api
# Namespace:       staging
# Status:          ✔ Healthy
# Strategy:        Canary
#   Step:          5/5  (all steps complete for initial deploy)
#   SetWeight:     100
#   ActualWeight:  100
```

### 13.3 — Apply Prometheus rules and Grafana dashboard

These are in the k8s/ directory and Argo CD applies them. If not synced:

```bash
kubectl apply -f k8s/prometheus-rules.yaml
kubectl apply -f k8s/grafana-dashboard-configmap.yaml

# Verify PrometheusRule
kubectl get prometheusrule -n staging
# Expected: genesis-platform-api-alerts

# Verify Grafana ConfigMap (Grafana sidecar picks this up automatically)
kubectl get configmap -n monitoring | grep genesis
```

### 13.4 — Apply ServiceMonitor

```bash
kubectl get servicemonitor -n staging
# Expected: genesis-platform-api
# If missing: kubectl apply -f k8s/service.yaml
```

### 13.5 — Test the API endpoint

```bash
K3S_IP=54.123.45.67

# Get the NodePort for the stable service (Ingress or NodePort)
kubectl get svc -n staging

# Port-forward if no ingress
kubectl port-forward svc/genesis-platform-api-stable 8080:80 -n staging &

curl http://localhost:8080/health
# Expected:
# {"status":"ok","version":"1.0.0","namespace":"staging"}

curl -X POST http://localhost:8080/platform/units \
  -H "Content-Type: application/json" \
  -d '{"unit_id":"unit-001","status":"active","tenant_id":"tenant-acme"}'
# Expected HTTP 201:
# {"unit_id":"unit-001","created_at":"2026-06-05T..."}

curl http://localhost:8080/platform/units/unit-001
# Expected HTTP 200:
# {"unit_id":"unit-001","status":"active","tenant_id":"tenant-acme","created_at":"..."}

curl http://localhost:8080/platform/units/nonexistent
# Expected HTTP 404:
# {"error":"Unit not found","code":"UNIT_NOT_FOUND","request_id":"..."}

curl http://localhost:8080/metrics | grep genesis_units_created_total
# Expected:
# genesis_units_created_total{tenant_id="tenant-acme"} 1.0
```

---

## Phase 14: First Full Pipeline Run

### 14.1 — Create a test branch

```bash
git checkout -b feat/pipeline-test
```

### 14.2 — Make a small code change

```bash
# Add a comment to trigger the pipeline
echo "# pipeline test $(date)" >> app/main.py
git add app/main.py
git commit -m "test: trigger CI pipeline"
git push origin feat/pipeline-test
```

### 14.3 — Open a Pull Request

```bash
# GitHub CLI
gh pr create \
  --title "test: verify 11-stage CI pipeline" \
  --body "Testing all pipeline stages. This PR should pass stages 1-11." \
  --base main \
  --head feat/pipeline-test

# Or go to GitHub UI and click "Compare & pull request"
```

### 14.4 — Watch each stage in GitHub Actions

Go to: `https://github.com/YOUR_USERNAME/genesis-devsecops-papun/actions`

You should see the CI Pipeline workflow running. Expected stage timeline:

| Stage | Job name | Expected duration | Gate result |
|-------|----------|------------------|-------------|
| 1-4 | `security-scan` | 2-3 min | ✅ PASS (no secrets in main app code) |
| 5 | `docker-build` | 3-5 min | ✅ PASS |
| 6 | `trivy-scan` | 2-3 min | ✅ PASS (no CRITICAL CVEs expected) |
| 7 | `sbom` | 1-2 min | ✅ PASS |
| 8 | `cosign-verify` | 30s | ✅ PASS |
| 9 | `tflint` | 1-2 min | ✅ PASS |
| 10 | `checkov` | 2-3 min | ✅ PASS |
| 11 | `kyverno-validate` | 1 min | ✅ PASS (clean) ✅ BLOCKED (flawed) |

**If Stage 1 fails** on a clean branch: Gitleaks is detecting something. Check the Gitleaks output — it may detect the `flaw1_secret.txt` file. Add it to `.gitleaks.toml` allowlist or move flaw demos to a separate branch.

### 14.5 — Download and inspect artifacts

After the pipeline completes, go to the Actions run → **Artifacts** section:
- `pip-audit-report` → JSON file showing dependency vulnerabilities
- `semgrep-sarif` → SARIF file (also visible in Security → Code scanning)
- `sbom-cyclonedx` → CycloneDX JSON SBOM
- `trivy-report` → Image vulnerability JSON
- `checkov-report` → IaC security findings
- `kyverno-validation` → Offline policy validation output

### 14.6 — Merge the PR (triggers deploy pipeline)

```bash
# Review and approve in GitHub UI first (branch protection requires 1 approval)
# Then merge:
gh pr merge --squash --delete-branch
```

### 14.7 — Watch the deploy pipeline

Go to Actions — you should now see **Deploy to Staging** workflow running:

| Stage | Job | Expected |
|-------|-----|----------|
| 1-4 | `security-gates` | ✅ Re-verified |
| 5+8 | `build-sign-push` | Builds + pushes to ECR + Cosign signs |
| 6+7 | `post-push-scan` | Trivy on ECR image + SBOM |
| GitOps | `update-manifest` | Commits updated image SHA to rollout.yaml |
| 12 | `argocd-sync` | Argo CD syncs, canary starts |
| 13 | `smoke-test` | GET /health returns 200 |

---

## Phase 15: Test Canary Deployment End-to-End

### 15.1 — Trigger a new deploy with an actual code change

```bash
git checkout -b feat/canary-test

# Make a visible change to the app
sed -i 's/version": "1.0.0"/version": "1.0.1"/' app/main.py

git add app/main.py
git commit -m "feat: bump version to 1.0.1 for canary test"
git push origin feat/canary-test

gh pr create --title "feat: canary test v1.0.1" --base main
# Approve + merge
```

### 15.2 — Watch the Argo Rollouts canary in real-time

```bash
# Open a watch on the rollout (updates every 2 seconds)
kubectl argo rollouts get rollout genesis-platform-api -n staging --watch

# Expected sequence:
# Status: ⟳ Progressing
# Step: 1/5 → SetWeight: 10
# (pauses 2 minutes)
# Step: 2/5 → Running AnalysisRun
# AnalysisRun:  genesis-platform-api-xxxx  Running
# (if error rate <= 2% → continues)
# Step: 3/5 → SetWeight: 25
# (pauses 2 minutes)
# Step: 4/5 → SetWeight: 50
# Step: 5/5 → SetWeight: 100
# Status: ✔ Healthy
```

### 15.3 — Generate load during the canary to see the traffic split panel

```bash
# In a separate terminal — generate traffic to both stable and canary
while true; do
  curl -s http://YOUR_K3S_IP/health > /dev/null
  curl -s -X POST http://YOUR_K3S_IP/platform/units \
    -H "Content-Type: application/json" \
    -d "{\"unit_id\":\"u-$(date +%s)\",\"status\":\"active\",\"tenant_id\":\"tenant-test\"}" > /dev/null
  sleep 0.5
done
```

Check Grafana → Genesis Platform API dashboard → **Canary vs Stable traffic split** panel — you should see ~10% to canary, ~90% to stable during the first step.

### 15.4 — Test auto-abort (optional demo)

To see the abort path work, temporarily lower the error rate threshold in `k8s/analysis-template.yaml` and deploy a bad version:

```bash
# Edit analysis-template.yaml — change successCondition to <= 0 (nothing passes)
# git commit + push → triggers a canary that will abort
# Watch: kubectl argo rollouts get rollout genesis-platform-api -n staging --watch
# Expected: ✖ Degraded after AnalysisRun fails → auto-rollback to stable version
```

---

## Phase 16: Grafana & Prometheus Verification

### 16.1 — Access Grafana

```bash
# Port-forward (if no NodePort ingress)
kubectl port-forward svc/kube-prometheus-stack-grafana 3000:80 -n monitoring

# Browse: http://localhost:3000
# User: admin
# Password:
kubectl get secret kube-prometheus-stack-grafana \
  -n monitoring \
  -o jsonpath="{.data.admin-password}" | base64 -d && echo
```

### 16.2 — Import the Genesis Platform dashboard

The dashboard is defined as a ConfigMap in `k8s/grafana-dashboard-configmap.yaml`. Grafana's sidecar picks it up automatically if labelled `grafana_dashboard: "1"`.

Verify it appears:
```bash
kubectl get configmap genesis-platform-api-dashboard -n monitoring
# Expected: shows the ConfigMap

# In Grafana UI: Dashboards → Browse → search "Genesis Platform API"
# All 7 panels should be visible:
# 1. HTTP Request Rate
# 2. Error Rate %
# 3. Request Latency P50/P99
# 4. Pod CPU Utilisation
# 5. Pod Memory Utilisation
# 6. Canary vs Stable Traffic Split
# 7. genesis_units_created_total (by tenant_id)
```

### 16.3 — Verify Prometheus is scraping the application

```bash
# Port-forward Prometheus
kubectl port-forward svc/kube-prometheus-stack-prometheus 9090:9090 -n monitoring

# Browse: http://localhost:9090
# Query: http_requests_total{namespace="staging"}
# Expected: time-series data if you ran load in Phase 15.3

# Query: genesis_units_created_total
# Expected: counter per tenant_id label
```

### 16.4 — Verify PrometheusRule alerts are loaded

```bash
# In Prometheus UI: Alerts tab
# You should see:
# - GenesisAPIHighErrorRateFast (fast burn — 1h window)
# - GenesisAPIHighErrorRateSlow (slow burn — 6h window)
# - GenesisAPICrashLoopDetected
# - GenesisAPIHighP99Latency

# Or via kubectl:
kubectl get prometheusrule -n staging
kubectl describe prometheusrule genesis-platform-api-alerts -n staging
```

---

## Phase 17: Demo All Three Planted Flaws

### Flaw 1 — Gitleaks (Stage 1 demo: secret scanning blocks pipeline)

```bash
# Create a demo branch
git checkout -b demo/flaw1-gitleaks

# The flaw file already exists: app/flaws/flaw1_secret.txt
# It contains AKIAIOSFODNN7EXAMPLE (AWS doc example key)
# Uncomment the allowlist entry in .gitleaks.toml first, then recomment it

# On this branch, temporarily REMOVE the allowlist entry in .gitleaks.toml
# so Gitleaks actually detects it
git add .
git commit -m "demo: flaw1 - planted secret for Gitleaks demo"
git push origin demo/flaw1-gitleaks

gh pr create --title "demo: Flaw 1 - Gitleaks stage 1 demo" --base main
```

**Expected result**: The `security-scan` job fails at Stage 1 (Gitleaks). ALL other stages (2-13) are **skipped** because they all `need: security-scan`. The PR cannot be merged.

In GitHub Actions → CI Pipeline run, you will see:
- `security-scan` → ❌ FAILED (Gitleaks detected secret)
- `docker-build` → ⏭ SKIPPED
- `trivy-scan` → ⏭ SKIPPED
- `tflint`, `checkov`, `kyverno-validate` → ⏭ SKIPPED

**This proves the fail-fast guarantee.** Clean up:
```bash
git checkout main
gh pr close   # close without merging
git push origin --delete demo/flaw1-gitleaks
```

### Flaw 2 — Semgrep (Stage 3 demo: SAST detects intentional code flaws)

The file `app/flaws/flaw2_sast.py` already contains:
- `eval(user_input)` → CWE-94 code injection
- `subprocess.run(cmd, shell=True)` → CWE-78 OS command injection
- Hardcoded password → CWE-798

```bash
# Flaw 2 is in the main branch already — Semgrep Stage 3 should detect it on EVERY PR.
# Check the semgrep-sarif artifact after any pipeline run:
# GitHub Actions → CI Pipeline run → Artifacts → semgrep-sarif → download

# Also visible in:
# GitHub repo → Security → Code scanning alerts
# Filter by "Semgrep" — you should see findings in app/flaws/flaw2_sast.py
```

**Expected result**: Stage 3 shows findings. The pipeline continues (Semgrep is gated but flaw2_sast.py findings may be in a non-blocking severity — check the semgrep config). The SARIF report is uploaded to GitHub Security tab. The evidence is the finding appearing in the report.

### Flaw 3 — Kyverno (Stage 11 demo: offline validation blocks non-compliant manifest)

The file `k8s/flawed-deployment.yaml` contains:
- `runAsNonRoot: false` → violates no-root-containers policy
- No `resources.limits` → violates require-resource-limits policy
- Image from `nginx:latest` (docker.io) → violates ecr-only-images policy

```bash
# Test offline (no cluster needed):
kyverno apply \
  infrastructure/kyverno-policies/ \
  --resource k8s/flawed-deployment.yaml

# Expected output:
# policy no-root-containers -> resource staging/Deployment/flawed-nginx-demo failed:
#   1. autogen-no-root-containers: validation error: Containers must not run as root.
# policy require-resource-limits -> resource staging/Deployment/flawed-nginx-demo failed:
#   1. autogen-require-cpu-limit: validation error: Resource limits required.
# policy ecr-only-images -> resource staging/Deployment/flawed-nginx-demo failed:
#   1. ecr-registry-only: validation error: Images must come from ECR.
# 
# pass: 0, fail: 3, warn: 0, error: 0, skip: 0

# Also test that clean manifests PASS:
kyverno apply \
  infrastructure/kyverno-policies/ \
  --resource k8s/rollout.yaml \
  --resource k8s/service.yaml

# Expected: pass: 2, fail: 0, warn: 0, error: 0, skip: 0
```

In the CI pipeline (Stage 11 in ci.yml), this test runs automatically on every PR:
- Clean manifests → PASS
- `flawed-deployment.yaml` → BLOCKED (if not blocked, pipeline fails with a gate error)

---

## Phase 18: SLO and Alert Verification

### 18.1 — Review the SLO definition

```bash
cat slo/genesis-platform-api-slo.yaml
# Review that all fields are filled:
# - slo.target_percent: 99.9
# - error_budget.allowed_failure_minutes: 43.8
# - rollout_gate.auto_abort_threshold: 2%
# - The PromQL query matches analysis-template.yaml
```

### 18.2 — Manually trigger an alert (test)

```bash
# Port-forward Prometheus
kubectl port-forward svc/kube-prometheus-stack-prometheus 9090:9090 -n monitoring &

# Send bad requests to increase error rate above 2% (triggers fast burn alert)
for i in $(seq 1 50); do
  # Send requests with bad data to trigger 422 validation errors
  curl -s -o /dev/null http://YOUR_K3S_IP/platform/units \
    -X POST \
    -H "Content-Type: application/json" \
    -d '{"bad":"data"}'
done

# In Prometheus UI → check the error rate query:
# sum(rate(http_requests_total{namespace="staging",status_code=~"5.."}[2m])) /
# sum(rate(http_requests_total{namespace="staging"}[2m]))
# If this returns > 0.02, the GenesisAPIHighErrorRateFast alert should fire
```

### 18.3 — Verify SNS email alert

After `terraform apply`, the SNS topic has your email subscribed. Check your email for the subscription confirmation — **you must click Confirm subscription** or you will not receive alerts.

```bash
# Check subscription status
aws sns list-subscriptions-by-topic \
  --topic-arn $(terraform -chdir=infrastructure/environments/dev output -raw sns_topic_arn) \
  --profile terraform-bootstrap
```

---

## Phase 19: DR Runbook Quick Test

This tests that you can recreate the environment from scratch. Do this in a separate AWS account or a different region.

### 19.1 — Quick validation (non-destructive)

```bash
# 1. Verify Git is the source of truth (all k8s manifests in Git)
git log --oneline k8s/ | head -10
# All changes should be tracked

# 2. Verify Terraform state is in S3 (not local)
terraform -chdir=infrastructure/environments/dev state list | wc -l
# Should list all resources (>20)

# 3. Verify ECR images exist (would be missing in a regional failure)
aws ecr list-images \
  --repository-name genesis-platform-api \
  --region ap-south-1 \
  --profile terraform-bootstrap
```

### 19.2 — Simulate the runbook (against us-west-2)

```bash
# Following docs/dr-design.md Section 4:

# Step 1: Use a different region
export AWS_DEFAULT_REGION=us-west-2

# Step 2: Run bootstrap script for new region
AWS_REGION=us-west-2 ./scripts/bootstrap.sh

# Step 3: Update backend.hcl for DR region
# (edit infrastructure/environments/dev/backend.hcl region to us-west-2)

# ... follow the full runbook in docs/dr-design.md

# Validate recovery:
curl http://DR_K3S_IP/health
# Expected: {"status":"ok","version":"1.0.0","namespace":"staging"}
```

---

## Quick Reference: All Exposed Ports & URLs

| Service | Access method | URL |
|---------|--------------|-----|
| API (GET /health) | NodePort or Ingress | `http://K3S_IP/health` |
| Argo CD UI | NodePort 30080 | `http://K3S_IP:30080` |
| Grafana | Port-forward 3000 | `http://localhost:3000` |
| Prometheus | Port-forward 9090 | `http://localhost:9090` |
| Argo Rollouts Dashboard | Port-forward 3100 | `kubectl argo rollouts dashboard -n argo-rollouts` → `http://localhost:3100` |

## Quick Reference: All GitHub Secrets Required

| Secret | Value source |
|--------|-------------|
| `AWS_DEPLOY_ROLE_ARN` | `terraform output github_actions_role_arn` |
| `ARGOCD_SERVER` | `K3S_IP:30080` |
| `ARGOCD_PASSWORD` | `kubectl -n argocd get secret argocd-initial-admin-secret ...` |
| `K3S_PUBLIC_IP` | `terraform output k3s_public_ip` |
| `K3S_KUBECONFIG_B64` | `cat ~/.kube/config-genesis-k3s \| base64` |
| `SEMGREP_APP_TOKEN` | https://semgrep.dev/orgs/-/settings/tokens |

## Quick Reference: Dependency Order (Why Order Matters)

```
1. AWS account + CLI profile          ← everything needs this
2. SSH key in AWS                     ← Terraform compute module needs it
3. Bootstrap (S3 + DynamoDB)          ← Terraform init needs the backend
4. terraform apply                    ← creates EC2, ECR, IAM role, OIDC
5. EC2 boots + installs k3s           ← k3s must exist before kubectl
6. kubectl configured locally         ← all k8s commands need this
7. Kyverno policies applied           ← must be BEFORE app pods start (admission webhook)
8. First ECR image pushed             ← Argo CD sync fails if image missing
9. GitHub Secrets set                 ← pipeline needs these to auth to AWS + Argo CD
10. Argo CD GitOps wired              ← argocd-app.yaml applied, repo added
11. First PR → CI pipeline            ← validates stages 1-11
12. Merge to main → deploy pipeline   ← stages 12-13, canary deployment
13. Grafana + Prometheus              ← data flows once app is deployed and receiving traffic
```

## Troubleshooting Common Issues

### "Error: Failed to get existing workspaces: S3 bucket does not exist"
→ Phase 4 (bootstrap) not completed. Run `./scripts/bootstrap.sh` first.

### "Error: No valid credential sources found"
→ AWS profile not set. Run `export AWS_PROFILE=terraform-bootstrap` before terraform commands.

### Kyverno blocking all pods
→ Policies applied before namespace had the `ecr-only-images` exemption. Check policy namespace selector. Temporarily switch policy to Audit mode: `kubectl patch clusterpolicy ecr-only-images -p '{"spec":{"validationFailureAction":"Audit"}}' --type=merge`

### "ImagePullBackOff" on genesis-platform-api pods
→ ECR image not yet pushed (Phase 10) OR ECR pull secret not created (Phase 10.4). Also check the image tag in rollout.yaml matches what was pushed.

### Argo CD sync stuck in "Progressing"
→ Pods may be failing admission. Check: `kubectl describe pod -n staging` and look for admission webhook errors. Also check: `kubectl get events -n staging --sort-by=.metadata.creationTimestamp`

### GitHub Actions OIDC auth fails ("Could not assume role")
→ The OIDC provider created by Terraform must match the GitHub repo exactly. Check: `aws iam get-open-id-connect-provider --open-id-connect-provider-arn arn:aws:iam::320644184091:oidc-provider/token.actions.githubusercontent.com` — the thumbprint and URL must match. Also verify the IAM role trust policy has `repo:YOUR_ORG/genesis-devsecops-papun:*` in the condition.

### Pipeline Stage 1 fails on clean branch
→ Gitleaks may be detecting `app/flaws/flaw1_secret.txt`. Add the allowlist entry in `.gitleaks.toml` for `app/flaws/` path on the main branch. The flaw1 demo should be done on a separate demo branch.

### Canary stuck at 0% after deploy
→ The Argo Rollouts ingress annotation approach requires NGINX ingress controller. Verify it is installed: `kubectl get pods -n ingress-nginx`. If not: `helm install ingress-nginx ingress-nginx/ingress-nginx --namespace ingress-nginx --create-namespace`

