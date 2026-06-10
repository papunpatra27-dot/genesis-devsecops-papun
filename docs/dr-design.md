# Disaster Recovery Design — Genesis Platform API

---

## Section 1 — Current State Inventory

| Component | Location | Lost in ap-south-1 failure? | Recoverable without DR setup? |
|---|---|---|---|
| EC2 t3.micro (k3s host) | ap-south-1, single AZ | Yes — instance terminated | No — must be re-provisioned |
| k3s runtime + config | EC2 root volume (EBS, gp3, encrypted) | Yes — EBS is AZ-local | No — must reinstall from scratch |
| Kubernetes workload state (etcd) | EC2 root volume | Yes | Partially — Argo CD resync restores declared state; transient in-flight data lost |
| In-memory units_db | Application process memory | Yes | No — data is ephemeral; no persistence layer |
| ECR container images | ap-south-1 ECR | Yes — ECR is regional | No — images must be rebuilt from source or pulled from a secondary registry |
| Terraform state file | S3 bucket (ap-south-1) | Availability impact only (S3 99.99%) | Mostly — S3 multi-AZ but not multi-region; if ap-south-1 is fully dark, state is inaccessible |
| DynamoDB state lock table | ap-south-1 DynamoDB | Availability impact only | Mostly — same caveat as S3 |
| Kubernetes manifests | GitHub (multi-region CDN) | No — GitHub is globally distributed | Yes — manifests survive any single region failure |
| Kyverno ClusterPolicies | Git + running cluster | In-cluster policies lost; Git copy survives | Yes — policies re-applied from Git via Argo CD |
| Argo CD configuration | In-cluster + argocd-secret | In-cluster state lost; app definitions in Git survive | Partially — Argo CD must be reinstalled; apps re-registered from Git |
| Grafana dashboards | Git (ConfigMap in k8s/) | In-cluster state lost; Git copy survives | Yes — re-applied from Git |
| Prometheus alert rules | Git (PrometheusRule CRD) | In-cluster state lost; Git copy survives | Yes — re-applied from Git |

---

## Section 2 — RTO and RPO Targets

**Service context:** The Genesis Platform API is an internal operations tool with indirect revenue dependency (tenant pipelines fail if the API is unavailable). It is not a direct customer-facing SaaS but has a real impact on downstream systems.

**SLO-constrained RTO:**

At 99.9% availability over 30 days, the allowed downtime is:

$$\text{Allowed downtime} = 30 \times 24 \times 60 \times (1 - 0.999) = 43.8 \text{ minutes/month}$$

A full regional failure is a force-majeure event that invokes a separate DR budget, but recovery must complete within the RTO before normal SLO counting resumes.

| Target | Value | Justification |
|---|---|---|
| RTO | 4 hours | Time to: provision EC2 (10 min) + k3s bootstrap (15 min) + Argo CD install (15 min) + GitOps sync all apps (20 min) + smoke test (5 min) + buffer for unexpected issues (115 min). Total estimated happy path: ~65 minutes; 4 hours covers the P95 case including DNS propagation. |
| RPO | ~0 for configuration and code | All manifests, policies, and application code live in Git. Zero data loss for declared state. |
| RPO | Unbounded for in-memory unit records | The API uses an in-memory dict. Any units created before the failure are lost. This is a known gap — see Section 5. |

**Calculation note:** A 4-hour RTO allows up to 4 × 60 = 240 minutes of downtime in a single incident. This consumes 240/43.8 = 5.5× the entire monthly error budget in one event. This is acceptable under DR (force majeure) but would trigger a mandatory post-mortem and a freeze on non-critical deployments for the remainder of the month.

---

## Section 3 — Kubernetes-Specific Recovery Strategy

### k3s Cluster Recovery

The EC2 instance is re-provisioned by running `terraform apply` in `infrastructure/environments/prod/`. Terraform creates a new EC2 t3.micro from the Amazon Linux 2023 AMI in the target region. The user-data script (`modules/compute/userdata.sh.tpl`) automatically installs k3s and all in-cluster tooling on first boot. Recovery time for this step: approximately 15-20 minutes.

### Kubernetes Manifests

Manifests live in GitHub. Recovery sequence:
1. Argo CD is installed first (before any app manifests — see Runbook).
2. The Argo CD `Application` CRD pointing to the Git repository is re-applied.
3. Argo CD performs a full sync, applying all manifests in dependency order.

The critical detail: **Argo CD itself is not yet running when recovery starts.** The first sync is bootstrapped manually using `argocd app create` or by applying the Application manifest with `kubectl apply`. Once Argo CD is running, all subsequent syncs are automatic.

### Kyverno Policy Order

Kyverno must be installed **before** application deployments are synced. If application pods are scheduled before Kyverno's admission webhook is running, pods bypass the `no-root-containers` and `require-resource-limits` policies. The runbook enforces this ordering explicitly: `helm install kyverno` completes and webhook is healthy before `argocd app sync` runs for the application.

### Container Images in ECR

ECR is regional. In a ap-south-1 outage, images are unavailable. Strategies evaluated:

- **Rebuild from source**: if GitHub Actions is accessible and a secondary ECR in us-west-2 is configured, CI can push a new build there. Build time ~5 minutes. Requires updating the Rollout manifest image reference — adds complexity during an incident.
- **ECR cross-region replication** (recommended for production budget): enable replication to us-west-2 with a replication rule for `genesis-platform-api`. Images are mirrored automatically. No additional build time during DR.
- **Public fallback registry**: not acceptable — violates the `ecr-only-images` Kyverno policy and introduces supply-chain risk.

**Current choice (free tier):** rebuild from source during DR. The Dockerfile and requirements.txt are in Git. A 5-minute CI run produces a new image. This adds ~10 minutes to the RTO.

### Terraform State in S3

S3 provides 99.99% availability but is regional. In a full ap-south-1 outage, the state bucket is inaccessible. However:
- The state file itself is not needed to provision a new environment — `terraform apply` with a fresh backend (empty state) re-creates all resources.
- Cross-region S3 replication (e.g., to us-west-2) solves the access problem but introduces state divergence risk: if the primary bucket gets a write during a partial outage and the replica is used for `apply`, the state files diverge. This is resolved by keeping the replica read-only (no writes until primary is confirmed lost).
- **Current gap**: cross-region replication is not configured. See Section 5.

---

## Section 4 — DR Runbook (Numbered, Command-Level)

**Prerequisite:** A workstation with AWS CLI, kubectl, Helm, and Terraform installed. AWS credentials are obtained via OIDC or a break-glass IAM user.

### Phase 1: Provision Infrastructure

```
# Step 1: Configure AWS CLI for the recovery region
aws configure set region ap-south-1
aws sts get-caller-identity   # Verify credentials are valid

# Step 2: Ensure Terraform state backend is accessible
# If ap-south-1 S3 is down, update backend.hcl to a us-west-2 replica bucket
cd infrastructure/environments/prod

# Step 3: Initialise Terraform (connects to remote state)
terraform init -backend-config=backend.hcl

# Step 4: Review the plan — confirm resources to be created
terraform plan -var-file=terraform.tfvars -out=dr-recovery.tfplan

# Step 5: Apply (creates VPC, EC2, ECR, IAM in ~10 minutes)
terraform apply dr-recovery.tfplan

# Step 6: Capture the new k3s public IP
K3S_IP=$(terraform output -raw k3s_public_ip)
echo "k3s node IP: $K3S_IP"
```

### Phase 2: Wait for k3s Bootstrap

```
# Step 7: Wait for k3s to finish bootstrapping via user-data (~15 minutes)
# Monitor cloud-init log:
ssh -i ~/.ssh/genesis-k3s.pem ec2-user@$K3S_IP \
  "sudo tail -f /var/log/cloud-init-output.log"

# Step 8: Verify k3s is ready
ssh -i ~/.ssh/genesis-k3s.pem ec2-user@$K3S_IP \
  "sudo k3s kubectl get nodes"
# Expected: node in Ready state
```

### Phase 3: Copy kubeconfig

```
# Step 9: Copy kubeconfig to local workstation
scp -i ~/.ssh/genesis-k3s.pem \
  ec2-user@$K3S_IP:/etc/rancher/k3s/k3s.yaml \
  ~/.kube/genesis-dr-config

# Replace the server address in the kubeconfig
sed -i "s|127.0.0.1|$K3S_IP|g" ~/.kube/genesis-dr-config
export KUBECONFIG=~/.kube/genesis-dr-config

# Step 10: Verify cluster connectivity
kubectl get nodes
kubectl get namespaces
```

### Phase 4: Install Kyverno (BEFORE any app manifests)

```
# Step 11: Add Helm repos
helm repo add kyverno    https://kyverno.github.io/kyverno/
helm repo add argo       https://argoproj.github.io/argo-helm
helm repo add prometheus https://prometheus-community.github.io/helm-charts
helm repo update

# Step 12: Install Kyverno (admission webhook must be running before apps)
helm install kyverno kyverno/kyverno \
  --namespace kyverno \
  --create-namespace \
  --wait

# Step 13: Verify Kyverno webhook is active
kubectl get validatingwebhookconfigurations | grep kyverno
# Must show kyverno-resource-validating-webhook-cfg as registered

# Step 14: Apply Kyverno ClusterPolicies from Git
kubectl apply -f infrastructure/kyverno-policies/
kubectl get clusterpolicies
# Expected: no-root-containers, require-resource-limits, ecr-only-images — all READY
```

### Phase 5: Install Argo CD and Sync Applications

```
# Step 15: Create staging namespace
kubectl apply -f k8s/namespace.yaml

# Step 16: Install Argo CD
helm install argocd argo/argo-cd \
  --namespace argocd \
  --create-namespace \
  --set server.service.type=NodePort \
  --wait

# Step 17: Get Argo CD initial admin password
ARGOCD_PASS=$(kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d)
echo "Argo CD password: $ARGOCD_PASS"

# Step 18: Create ECR pull secret in staging namespace
aws ecr get-login-password --region ap-south-1 | \
  kubectl create secret docker-registry ecr-credentials \
    --docker-server=$(terraform output -raw ecr_repository_url | cut -d/ -f1) \
    --docker-username=AWS \
    --docker-password="$(aws ecr get-login-password --region ap-south-1)" \
    --namespace staging

# Step 19: Register the platform application in Argo CD
argocd login $K3S_IP:30080 --username admin --password "$ARGOCD_PASS" --insecure

argocd app create genesis-platform-api \
  --repo https://github.com/REPLACE_GITHUB_ORG/genesis-devsecops-papun.git \
  --path k8s \
  --dest-server https://kubernetes.default.svc \
  --dest-namespace staging \
  --sync-policy automated \
  --self-heal

# Step 20: Trigger initial sync
argocd app sync genesis-platform-api --prune --timeout 300

# Step 21: Wait for healthy status
argocd app wait genesis-platform-api --health --timeout 300
```

### Phase 6: Install Monitoring Stack

```
# Step 22: Install kube-prometheus-stack
helm install kube-prometheus-stack prometheus/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false \
  --wait

# Step 23: Apply PrometheusRules and Grafana dashboard
kubectl apply -f k8s/prometheus-rules.yaml
kubectl apply -f k8s/grafana-dashboard-configmap.yaml
```

### Phase 7: Install Argo Rollouts

```
# Step 24: Install Argo Rollouts controller
helm install argo-rollouts argo/argo-rollouts \
  --namespace argo-rollouts \
  --create-namespace \
  --wait

# Step 25: Verify rollout is progressing
kubectl argo rollouts get rollout genesis-platform-api -n staging
```

### Phase 8: Validate Recovery

```
# Step 26: Run smoke test — this is the validation gate
curl -s -o /dev/null -w "%{http_code}" http://$K3S_IP/health
# Expected output: 200

# Full validation command with assertion:
curl -sf http://$K3S_IP/health | python3 -c "
import sys, json
body = json.load(sys.stdin)
assert body['status'] == 'ok', f'Bad status: {body}'
assert body['namespace'] == 'staging', f'Wrong namespace: {body}'
print('RECOVERY VALIDATED:', json.dumps(body))
"
# Expected: RECOVERY VALIDATED: {"status": "ok", "version": "1.0.0", "namespace": "staging"}
```

---

## Section 5 — Gap Analysis and Production DR Investment

| Gap | Impact | Production Fix | Estimated Effort |
|---|---|---|---|
| **ECR images are regional** | In a ap-south-1 failure, no images available; must rebuild from source. Adds 10-15 min to RTO. | Enable ECR replication to a secondary region (`aws ecr put-replication-configuration`). Replicate to us-west-2 with read-only access during DR. | 1 day to implement + policy update |
| **S3 state bucket not cross-region replicated** | Terraform state inaccessible during regional failure; must use empty state and risk re-creating or importing existing resources. | Enable S3 Cross-Region Replication to a us-west-2 bucket. Keep replica read-only (no-write bucket policy) until primary is confirmed lost. Add a state export step to the weekly DR drill. | 0.5 days + monitoring |
| **No automated DR drill** | RTO is estimated, not tested. The runbook may have errors or missing steps discovered only during a real incident. | Build a quarterly DR drill automation: a GitHub Actions workflow that provisions a parallel environment in us-west-2, runs the full runbook, executes the smoke test, captures the elapsed time, then tears down. Failures produce a drill report. | 3-5 days |
| **k3s etcd not backed up** | If the EC2 instance root volume is corrupted (not just unavailable), etcd data is lost. Kubernetes manifests are safe in Git but any CRD state not reflected in Git (e.g., manually created Secrets, ConfigMaps) is gone. | Use `etcdctl snapshot save` daily to S3. Velero for Kubernetes object backup of the staging namespace. | 2 days |
| **In-memory unit records** | All platform units created before the failure are permanently lost. No persistence layer means RPO is unbounded for business data. | Replace the in-memory dict with a managed database (RDS PostgreSQL, DynamoDB, or Redis). Scope and cost depend on data model requirements. | 1-2 weeks |
| **Single-node k3s** | No HA control plane. k3s itself going down (OOM, disk full) causes a full cluster outage. | Run k3s in embedded etcd HA mode with 3 t3.micro nodes (still free-tier if within 750h total). Or use k3s with an external datastore (RDS PostgreSQL). | 2-3 days |
| **RTO unmeasured (estimated, not tested)** | The 4-hour RTO estimate is based on component timings but has never been drilled end-to-end. The real RTO is unknown. | Automated quarterly drill (see above). Record actual elapsed time per runbook step and update the SLO documentation. | Included in drill effort |
| **No secondary region Argo CD** | If ap-south-1 is unavailable, GitOps synchronisation cannot be initiated until a new Argo CD is installed in the recovery region. | Pre-install Argo CD in a warm-standby secondary region cluster (even a t3.micro k3s node, stopped when not needed — costs nothing). On DR, start the instance, update the Git remote, and sync. | 1 day setup, ~$0/month if stopped |
