# Setup Guide — Genesis DevSecOps Platform
# Complete Step-by-Step: Every Command, Every Folder, Every Placeholder

> **How to read this guide:**
> - Every command block starts with a `# FOLDER:` comment — that is where you must be before running the command.
> - `LOCAL>` means run on your Windows machine (PowerShell).
> - `EC2>` means run inside the EC2 SSH session (bash).
> - Never skip a verify step — each verify confirms the previous command actually worked before you proceed.

---

## MASTER PLACEHOLDER LIST — Fill These In Before Anything Else

Before running a single command, collect these four values. Every REPLACE_ string in this repo uses exactly one of them.

| Your value | What it is | Example |
|---|---|---|
| `YOUR_ACCOUNT_ID` | Your 12-digit AWS account ID | `320644184091` |
| `YOUR_GITHUB_USERNAME` | Your GitHub username or org | `papun-dev` |
| `YOUR_EMAIL` | Your email for SNS alert notifications | `papun@example.com` |
| `YOUR_SSH_PUBLIC_KEY` | Full content of your EC2 SSH public key (Step 3.4 generates this) | `ssh-ed25519 AAAA...` |

---

## COMPLETE PLACEHOLDER REPLACEMENT MAP

Every file that contains a placeholder is listed below. You will replace them in Part 3.

### File 1 — `infrastructure/environments/dev/terraform.tfvars`

| Line | Placeholder | Replace with |
|---|---|---|
| 21 | `REPLACE_WITH_YOUR_PUBLIC_SSH_KEY` | Full contents of your SSH public key (generated in Step 3.4) |
| 24 | `REPLACE_WITH_GITHUB_ORG` | Your GitHub username, e.g. `papun-dev` |
| 32 | `genesis-devsecops-terraform-state-320644184091` | `genesis-devsecops-terraform-state-320644184091` |
| 37 | `REPLACE_WITH_YOUR_EMAIL@example.com` | Your real email address |

### File 2 — `infrastructure/environments/dev/backend.hcl`

| Line | Placeholder | Replace with |
|---|---|---|
| 5 | `genesis-devsecops-terraform-state-320644184091` | `genesis-devsecops-terraform-state-320644184091` |

### File 3 — `infrastructure/environments/prod/terraform.tfvars`

| Line | Placeholder | Replace with |
|---|---|---|
| 12 | `REPLACE_WITH_VPN_OR_BASTION_CIDR` | Your IP with /32, e.g. `203.0.113.10/32` (or `0.0.0.0/0` for dev testing) |
| 15 | `REPLACE_WITH_YOUR_PUBLIC_SSH_KEY` | Same SSH public key as above |
| 17 | `REPLACE_WITH_GITHUB_ORG` | Your GitHub username |
| 23 | `genesis-devsecops-terraform-state-320644184091` | `genesis-devsecops-terraform-state-320644184091` |
| 27 | `REPLACE_WITH_OPS_EMAIL@example.com` | Your real email address |

### File 4 — `infrastructure/environments/prod/backend.hcl`

| Line | Placeholder | Replace with |
|---|---|---|
| 2 | `genesis-devsecops-terraform-state-320644184091` | `genesis-devsecops-terraform-state-320644184091` |

### File 5 — `infrastructure/kyverno-policies/ecr-only-images.yaml`

| Lines | Placeholder | Replace with |
|---|---|---|
| 38, 44, 65 | `320644184091` (appears 3 times) | Your 12-digit account ID `320644184091` |

### File 6 — `infrastructure/conftest-policies/test/compliant_deployment.yaml`

| Line | Placeholder | Replace with |
|---|---|---|
| 19 | `320644184091` | Your 12-digit account ID |

### File 7 — `k8s/rollout.yaml`

| Line | Placeholder | Replace with |
|---|---|---|
| 50 | `320644184091` | Your 12-digit account ID |
| 50 | `REPLACE_GIT_SHA` | The git SHA of the image you will push in Part 14 |

### File 8 — `k8s/argocd-app.yaml`

| Lines | Placeholder | Replace with |
|---|---|---|
| 44 | `REPLACE_GITHUB_ORG` | Your GitHub username |
| 87 | `REPLACE_GITHUB_ORG` | Your GitHub username |

### File 9 — `k8s/prometheus-rules.yaml`

| Line | Placeholder | Replace with |
|---|---|---|
| 45 | `REPLACE_GITHUB_ORG` | Your GitHub username |

### File 10 — `.github/CODEOWNERS`

| Lines | Placeholder | Replace with |
|---|---|---|
| 7, 10, 11, 14, 17, 20, 23 | `REPLACE_GITHUB_ORG` (appears 7 times) | Your GitHub username |

**Total: 10 files, ~25 placeholder instances. Part 3 handles all of them with PowerShell one-liners.**

---

## PART 1 — INSTALL TOOLS ON YOUR LOCAL MACHINE

Run everything in this part from **any PowerShell window** (open as Administrator).

### Step 1.1 — Install AWS CLI v2

```powershell
# FOLDER: anywhere (Administrator PowerShell)
msiexec.exe /i https://awscli.amazonaws.com/AWSCLIV2.msi /quiet
```

Close PowerShell completely, open a new one, then verify:
```powershell
# FOLDER: anywhere
aws --version
# Expected output: aws-cli/2.x.x Python/3.x.x Windows/...
# If "command not found" — reopen PowerShell and try again
```

### Step 1.2 — Install Terraform 1.8+

```powershell
# FOLDER: anywhere (Administrator PowerShell)
winget install HashiCorp.Terraform
```

Verify:
```powershell
# FOLDER: anywhere
terraform version
# Expected output: Terraform v1.8.x (or higher, e.g. v1.9.x)
```

### Step 1.3 — Install Git

```powershell
# FOLDER: anywhere (Administrator PowerShell)
winget install Git.Git
```

Verify:
```powershell
# FOLDER: anywhere
git --version
# Expected output: git version 2.x.x
```

### Step 1.4 — Verify Python

```powershell
# FOLDER: anywhere
py --version
# Expected output: Python 3.14.0
```

### Step 1.5 — Install Docker Desktop

1. Download installer from https://www.docker.com/products/docker-desktop/
2. Run the installer, accept defaults, restart when prompted
3. After restart, Docker Desktop opens automatically — wait for the whale icon in system tray to stop animating

Verify:
```powershell
# FOLDER: anywhere
docker --version
# Expected output: Docker version 26.x.x
```

---

## PART 2 — CONNECT TO AWS FROM THE CLI

### Step 2.1 — Get your AWS credentials

1. Browser → https://console.aws.amazon.com → sign in
2. Click your name top-right → **Security credentials**
3. Scroll to **Access keys** section → **Create access key**
4. Select **Command Line Interface (CLI)** → **Next** → **Create access key**
5. You see the Access key ID and Secret access key — **copy both now** (secret shown only once)

### Step 2.2 — Configure AWS CLI

```powershell
# FOLDER: anywhere
aws configure
```

The command prompts you for four values, one at a time. Type each and press Enter:
```
AWS Access Key ID [None]:     paste-your-access-key-id-here
AWS Secret Access Key [None]: paste-your-secret-access-key-here
Default region name [None]:   ap-south-1
Default output format [None]: json
```

### Step 2.3 — Verify the connection works

```powershell
# FOLDER: anywhere
aws sts get-caller-identity
```

Expected output:
```json
{
    "UserId": "AIDA...",
    "Account": "320644184091",
    "Arn": "arn:aws:iam::320644184091:user/your-iam-username"
}
```

The `"Account"` value is your 12-digit AWS account ID. Write it down.

### Step 2.4 — Save account ID and region as variables (do this every new PowerShell session)

```powershell
# FOLDER: anywhere
# These variables live only for this PowerShell session.
# If you close and reopen PowerShell, run these two lines again before any AWS commands.
$ACCOUNT_ID = (aws sts get-caller-identity --query Account --output text)
$REGION     = "ap-south-1"

Write-Host "Account ID : $ACCOUNT_ID"
Write-Host "Region     : $REGION"
```

Expected: prints your real 12-digit account ID.

---

## PART 3 — REPLACE ALL PLACEHOLDERS IN THE REPO

Run every command in this part from the repo root folder.

```powershell
# FOLDER: C:\Clouddev\devsecops-papun
cd C:\Clouddev\devsecops-papun
```

### Step 3.1 — Generate the SSH public key you will paste into tfvars

```powershell
# FOLDER: anywhere
# Create the SSH key pair for EC2 access
aws ec2 create-key-pair `
  --key-name genesis-dev-key `
  --key-type ed25519 `
  --query 'KeyMaterial' `
  --output text > "$env:USERPROFILE\.ssh\genesis-dev-key.pem"

# Set correct permissions on the private key
icacls "$env:USERPROFILE\.ssh\genesis-dev-key.pem" /inheritance:r /grant:r "$($env:USERNAME):(R)"
```

Verify the key was created in AWS:
```powershell
# FOLDER: anywhere
aws ec2 describe-key-pairs --key-names genesis-dev-key --query 'KeyPairs[0].KeyName' --output text
# Expected output: genesis-dev-key
```

Now get the public key content to paste into tfvars.
Because AWS only gives you the private key, derive the public key from it:
```powershell
# FOLDER: anywhere
# Requires OpenSSH (installed by default on Windows 10/11)
ssh-keygen -y -f "$env:USERPROFILE\.ssh\genesis-dev-key.pem"
# Expected output: ssh-ed25519 AAAA... (a long single line starting with ssh-ed25519)
# Copy this entire output — you need it in Step 3.2
```

### Step 3.2 — Replace all placeholders in dev/terraform.tfvars

```powershell
# FOLDER: C:\Clouddev\devsecops-papun

# Get your SSH public key string
$SSH_PUB_KEY = (ssh-keygen -y -f "$env:USERPROFILE\.ssh\genesis-dev-key.pem")

# Set your GitHub username
$GITHUB_ORG = "your-github-username"   # <-- change this to your actual username

# Set your email
$YOUR_EMAIL = "your@email.com"         # <-- change this to your actual email

# Now replace all four placeholders in one go
$content = Get-Content infrastructure/environments/dev/terraform.tfvars -Raw
$content = $content -replace 'REPLACE_WITH_YOUR_PUBLIC_SSH_KEY', $SSH_PUB_KEY
$content = $content -replace 'REPLACE_WITH_GITHUB_ORG', $GITHUB_ORG
$content = $content -replace "genesis-devsecops-terraform-state-320644184091", "genesis-devsecops-terraform-state-$ACCOUNT_ID"
$content = $content -replace 'REPLACE_WITH_YOUR_EMAIL@example\.com', $YOUR_EMAIL
Set-Content infrastructure/environments/dev/terraform.tfvars -Value $content -Encoding utf8
```

Verify no REPLACE_ strings remain in this file:
```powershell
# FOLDER: C:\Clouddev\devsecops-papun
Select-String -Path infrastructure/environments/dev/terraform.tfvars -Pattern "REPLACE_"
# Expected: no output (zero lines printed)
```

### Step 3.3 — Replace placeholder in dev/backend.hcl

```powershell
# FOLDER: C:\Clouddev\devsecops-papun
(Get-Content infrastructure/environments/dev/backend.hcl) `
  -replace "320644184091", $ACCOUNT_ID | `
  Set-Content infrastructure/environments/dev/backend.hcl -Encoding utf8
```

Verify:
```powershell
# FOLDER: C:\Clouddev\devsecops-papun
Get-Content infrastructure/environments/dev/backend.hcl
# Expected: bucket line shows your real account ID, no REPLACE_ anywhere
```

### Step 3.4 — Replace all placeholders in prod/terraform.tfvars

```powershell
# FOLDER: C:\Clouddev\devsecops-papun
$content = Get-Content infrastructure/environments/prod/terraform.tfvars -Raw
$content = $content -replace 'REPLACE_WITH_VPN_OR_BASTION_CIDR', '0.0.0.0/0'       # use your IP/32 for real prod
$content = $content -replace 'REPLACE_WITH_YOUR_PUBLIC_SSH_KEY', $SSH_PUB_KEY
$content = $content -replace 'REPLACE_WITH_GITHUB_ORG', $GITHUB_ORG
$content = $content -replace "genesis-devsecops-terraform-state-320644184091", "genesis-devsecops-terraform-state-$ACCOUNT_ID"
$content = $content -replace 'REPLACE_WITH_OPS_EMAIL@example\.com', $YOUR_EMAIL
Set-Content infrastructure/environments/prod/terraform.tfvars -Value $content -Encoding utf8
```

Verify:
```powershell
# FOLDER: C:\Clouddev\devsecops-papun
Select-String -Path infrastructure/environments/prod/terraform.tfvars -Pattern "REPLACE_"
# Expected: no output
```

### Step 3.5 — Replace placeholder in prod/backend.hcl

```powershell
# FOLDER: C:\Clouddev\devsecops-papun
(Get-Content infrastructure/environments/prod/backend.hcl) `
  -replace "320644184091", $ACCOUNT_ID | `
  Set-Content infrastructure/environments/prod/backend.hcl -Encoding utf8
```

Verify:
```powershell
# FOLDER: C:\Clouddev\devsecops-papun
Select-String -Path infrastructure/environments/prod/backend.hcl -Pattern "REPLACE_"
# Expected: no output
```

### Step 3.6 — Replace placeholders in ecr-only-images.yaml (3 occurrences)

```powershell
# FOLDER: C:\Clouddev\devsecops-papun
(Get-Content infrastructure/kyverno-policies/ecr-only-images.yaml) `
  -replace "320644184091", $ACCOUNT_ID | `
  Set-Content infrastructure/kyverno-policies/ecr-only-images.yaml -Encoding utf8
```

Verify:
```powershell
# FOLDER: C:\Clouddev\devsecops-papun
Select-String -Path infrastructure/kyverno-policies/ecr-only-images.yaml -Pattern "REPLACE_"
# Expected: no output (3 replacements were made)
```

### Step 3.7 — Replace placeholder in compliant_deployment.yaml

```powershell
# FOLDER: C:\Clouddev\devsecops-papun
(Get-Content infrastructure/conftest-policies/test/compliant_deployment.yaml) `
  -replace "320644184091", $ACCOUNT_ID | `
  Set-Content infrastructure/conftest-policies/test/compliant_deployment.yaml -Encoding utf8
```

Verify:
```powershell
# FOLDER: C:\Clouddev\devsecops-papun
Select-String -Path infrastructure/conftest-policies/test/compliant_deployment.yaml -Pattern "REPLACE_"
# Expected: no output
```

### Step 3.8 — Replace 320644184091 in rollout.yaml (leave REPLACE_GIT_SHA — Part 14 sets it)

```powershell
# FOLDER: C:\Clouddev\devsecops-papun
# IMPORTANT: only replace 320644184091 here, NOT REPLACE_GIT_SHA
# REPLACE_GIT_SHA gets replaced in Part 14 when you build and push the image
(Get-Content k8s/rollout.yaml) `
  -replace "320644184091", $ACCOUNT_ID | `
  Set-Content k8s/rollout.yaml -Encoding utf8
```

Verify 320644184091 is gone but REPLACE_GIT_SHA still exists:
```powershell
# FOLDER: C:\Clouddev\devsecops-papun
Select-String -Path k8s/rollout.yaml -Pattern "320644184091"
# Expected: no output (replaced)

Select-String -Path k8s/rollout.yaml -Pattern "REPLACE_GIT_SHA"
# Expected: one match (this is correct — it gets set in Part 14)
```

### Step 3.9 — Replace REPLACE_GITHUB_ORG in argocd-app.yaml (2 occurrences)

```powershell
# FOLDER: C:\Clouddev\devsecops-papun
(Get-Content k8s/argocd-app.yaml) `
  -replace "REPLACE_GITHUB_ORG", $GITHUB_ORG | `
  Set-Content k8s/argocd-app.yaml -Encoding utf8
```

Verify:
```powershell
# FOLDER: C:\Clouddev\devsecops-papun
Select-String -Path k8s/argocd-app.yaml -Pattern "REPLACE_"
# Expected: no output
```

### Step 3.10 — Replace REPLACE_GITHUB_ORG in prometheus-rules.yaml

```powershell
# FOLDER: C:\Clouddev\devsecops-papun
(Get-Content k8s/prometheus-rules.yaml) `
  -replace "REPLACE_GITHUB_ORG", $GITHUB_ORG | `
  Set-Content k8s/prometheus-rules.yaml -Encoding utf8
```

Verify:
```powershell
# FOLDER: C:\Clouddev\devsecops-papun
Select-String -Path k8s/prometheus-rules.yaml -Pattern "REPLACE_"
# Expected: no output
```

### Step 3.11 — Replace REPLACE_GITHUB_ORG in CODEOWNERS (7 occurrences)

```powershell
# FOLDER: C:\Clouddev\devsecops-papun
(Get-Content .github/CODEOWNERS) `
  -replace "REPLACE_GITHUB_ORG", $GITHUB_ORG | `
  Set-Content .github/CODEOWNERS -Encoding utf8
```

Verify:
```powershell
# FOLDER: C:\Clouddev\devsecops-papun
Select-String -Path .github/CODEOWNERS -Pattern "REPLACE_"
# Expected: no output (7 replacements made)
```

### Step 3.12 — Final check: zero REPLACE_ strings across entire repo

```powershell
# FOLDER: C:\Clouddev\devsecops-papun
Select-String -Path infrastructure/, k8s/, .github/ -Pattern "320644184091|REPLACE_GITHUB_ORG|REPLACE_WITH_" -Recurse
# Expected: absolutely no output
# If any matches appear, go back to the step for that file and fix it
```

---

## PART 4 — BOOTSTRAP: CREATE S3 BUCKET + DYNAMODB TABLE

> **Why:** Terraform needs S3 and DynamoDB before it can store its own state. You create them with raw AWS CLI once. After this, Terraform manages everything else.

The S3 bucket name used in your `backend.hcl` is: `genesis-devsecops-terraform-state-YOUR_ACCOUNT_ID`

### Step 4.1 — Create the S3 state bucket

```powershell
# FOLDER: anywhere
aws s3api create-bucket `
  --bucket "genesis-devsecops-terraform-state-$ACCOUNT_ID" `
  --region ap-south-1
```

Expected output: `{"Location": "/genesis-devsecops-terraform-state-320644184091"}`
If you see `BucketAlreadyExists` — the bucket already exists, continue to Step 4.2.

### Step 4.2 — Enable versioning

```powershell
# FOLDER: anywhere
aws s3api put-bucket-versioning `
  --bucket "genesis-devsecops-terraform-state-$ACCOUNT_ID" `
  --versioning-configuration Status=Enabled
```

No output = success. Verify:
```powershell
# FOLDER: anywhere
aws s3api get-bucket-versioning --bucket "genesis-devsecops-terraform-state-$ACCOUNT_ID"
# Expected: {"Status": "Enabled"}
```

### Step 4.3 — Enable AES-256 encryption

```powershell
# FOLDER: anywhere
aws s3api put-bucket-encryption `
  --bucket "genesis-devsecops-terraform-state-$ACCOUNT_ID" `
  --server-side-encryption-configuration '{
    "Rules": [{"ApplyServerSideEncryptionByDefault": {"SSEAlgorithm": "AES256"}}]
  }'
```

Verify:
```powershell
# FOLDER: anywhere
aws s3api get-bucket-encryption --bucket "genesis-devsecops-terraform-state-$ACCOUNT_ID"
# Expected: JSON with SSEAlgorithm: AES256
```

### Step 4.4 — Block all public access

```powershell
# FOLDER: anywhere
aws s3api put-public-access-block `
  --bucket "genesis-devsecops-terraform-state-$ACCOUNT_ID" `
  --public-access-block-configuration "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"
```

Verify:
```powershell
# FOLDER: anywhere
aws s3api get-public-access-block --bucket "genesis-devsecops-terraform-state-$ACCOUNT_ID"
# Expected: all four booleans = true
```

### Step 4.5 — Create access logging bucket

```powershell
# FOLDER: anywhere
aws s3api create-bucket `
  --bucket "genesis-tf-state-logs-$ACCOUNT_ID" `
  --region ap-south-1
```

### Step 4.6 — Enable access logging on the state bucket pointing to logs bucket

```powershell
# FOLDER: anywhere
aws s3api put-bucket-logging `
  --bucket "genesis-devsecops-terraform-state-$ACCOUNT_ID" `
  --bucket-logging-status "{`"LoggingEnabled`":{`"TargetBucket`":`"genesis-tf-state-logs-$ACCOUNT_ID`",`"TargetPrefix`":`"access-logs/`"}}"
```

Verify:
```powershell
# FOLDER: anywhere
aws s3api get-bucket-logging --bucket "genesis-devsecops-terraform-state-$ACCOUNT_ID"
# Expected: JSON with LoggingEnabled.TargetBucket set to your logs bucket
```

### Step 4.7 — Create DynamoDB table for Terraform state locking

The table name must match what is in `backend.hcl`: `genesis-terraform-state-lock`

```powershell
# FOLDER: anywhere
aws dynamodb create-table `
  --table-name genesis-terraform-state-lock `
  --attribute-definitions AttributeName=LockID,AttributeType=S `
  --key-schema AttributeName=LockID,KeyType=HASH `
  --billing-mode PAY_PER_REQUEST `
  --region ap-south-1
```

Wait 15 seconds, then verify it is ACTIVE:
```powershell
# FOLDER: anywhere
aws dynamodb describe-table `
  --table-name genesis-terraform-state-lock `
  --query 'Table.TableStatus' --output text
# Expected: ACTIVE
# If CREATING: wait 10 more seconds and run again
```

---

## PART 5 — TERRAFORM: CREATE OIDC PROVIDER AND IAM ROLES

> **Why:** The OIDC provider lets GitHub Actions authenticate to AWS without any stored credentials. This must exist before the pipeline can create EC2.

### Step 5.1 — Go to the dev environment folder

```powershell
# FOLDER: C:\Clouddev\devsecops-papun\infrastructure\environments\dev
cd C:\Clouddev\devsecops-papun\infrastructure\environments\dev
```

Verify you are in the right folder:
```powershell
pwd
# Expected: C:\Clouddev\devsecops-papun\infrastructure\environments\dev
```

### Step 5.2 — Initialize Terraform with the S3 backend

```powershell
# FOLDER: C:\Clouddev\devsecops-papun\infrastructure\environments\dev
terraform init -backend-config=backend.hcl
```

Expected final line:
```
Terraform has been successfully initialized!
```

If you see `Error: Failed to get existing workspaces: ... NoSuchBucket` — your S3 bucket name in `backend.hcl` does not match what was created. Check both match exactly.

### Step 5.3 — Plan only the IAM module

```powershell
# FOLDER: C:\Clouddev\devsecops-papun\infrastructure\environments\dev
terraform plan -target=module.iam -out=iam.tfplan
```

Verify the plan shows these resources to be created:
```
# module.iam.aws_iam_openid_connect_provider.github_actions will be created
# module.iam.aws_iam_role.github_actions_deploy will be created
# module.iam.aws_iam_role.k3s_node will be created
# module.iam.aws_iam_instance_profile.k3s_node will be created
```

If you see errors about missing variable values — check `terraform.tfvars` for any remaining REPLACE_ strings (Part 3 should have caught them all).

### Step 5.4 — Apply only the IAM module

```powershell
# FOLDER: C:\Clouddev\devsecops-papun\infrastructure\environments\dev
terraform apply iam.tfplan
```

Type `yes` when prompted. Expected final line:
```
Apply complete! Resources: X added, 0 changed, 0 destroyed.
```

### Step 5.5 — Verify the OIDC provider was created

```powershell
# FOLDER: anywhere
aws iam list-open-id-connect-providers --query 'OpenIDConnectProviderList[*].Arn' --output table
# Expected: shows arn:aws:iam::YOUR_ACCOUNT_ID:oidc-provider/token.actions.githubusercontent.com
```

### Step 5.6 — Save the GitHub Actions role ARN

```powershell
# FOLDER: anywhere
$GITHUB_ROLE_ARN = (aws iam get-role --role-name genesis-github-actions-deploy --query 'Role.Arn' --output text)
Write-Host "GitHub Actions Role ARN: $GITHUB_ROLE_ARN"
# This looks like: arn:aws:iam::320644184091:role/genesis-github-actions-deploy
# Copy and save this — you need it in Part 6 Step 6.2
```

---

## PART 6 — GITHUB REPOSITORY SETUP

### Step 6.1 — Create the GitHub repository

1. Browser → https://github.com/new
2. Repository name: `devsecops-papun` (must match `github_repo` in tfvars)
3. Visibility: **Public** (required for 2,000 free Actions minutes per month)
4. Do NOT check "Add a README file" — you already have files
5. Click **Create repository**

Go to: `https://github.com/YOUR_GITHUB_USERNAME/devsecops-papun/settings/secrets/actions`

Click the **Secrets** tab → **New repository secret** — add ALL of these:

| Secret Name | How to get the value | Used by |
|---|---|---|
| `AWS_DEPLOY_ROLE_ARN` | The full ARN from Step 5.6 (e.g. `arn:aws:iam::320644184091:role/genesis-github-actions-deploy`) | All AWS steps in ci.yml, deploy.yml, terraform.yml |
| `ARGOCD_SERVER` | `YOUR_EC2_IP:30080` — set after EC2 is up in Part 7 | deploy.yml Stage 12 (argocd-sync) |
| `ARGOCD_PASSWORD` | kubectl command below — set after Part 11 | deploy.yml Stage 12 (argocd-sync) |
| `K3S_KUBECONFIG_B64` | Base64-encoded kubeconfig — instructions below, set after Part 8 | deploy.yml Stage 12 (argocd-sync) |
| `K3S_PUBLIC_IP` | Your EC2 public IP — set after Part 7 Step 7.5 | deploy.yml Stage 13 (smoke-test) |
| `SEMGREP_APP_TOKEN` | From https://semgrep.dev/orgs/-/settings/tokens (OPTIONAL — leave empty if no account) | security-scan.yml Stage 3 |

> **IMPORTANT:** The secret is named `AWS_DEPLOY_ROLE_ARN` (not `AWS_ROLE_ARN`). Both `ci.yml`, `deploy.yml`, and `terraform.yml` look for exactly `AWS_DEPLOY_ROLE_ARN`.

**Getting `ARGOCD_PASSWORD`** (run this command after Part 11 Step 11.3):
```bash
# EC2 FOLDER: ~
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d
# Copy the output — paste it as the value of ARGOCD_PASSWORD
```

**Getting `K3S_KUBECONFIG_B64`** (run this after Part 8 Step 8.5):
```bash
# EC2 FOLDER: ~
# Replace 127.0.0.1 with the EC2 public IP so GitHub Actions (external) can reach k3s API
EC2_IP="YOUR_EC2_PUBLIC_IP"
sed "s|127.0.0.1|$EC2_IP|g" /etc/rancher/k3s/k3s.yaml | base64 -w 0
# Copy the long single-line output — paste as K3S_KUBECONFIG_B64
```

> **Port 6443 note:** GitHub Actions runners have dynamic IPs.
> You may need to open port 6443 to `0.0.0.0/0` in the EC2 security group temporarily.
> Tighten it back to your own IP after the initial setup.

> **Critical:** Do NOT add `AWS_ACCESS_KEY_ID` or `AWS_SECRET_ACCESS_KEY`. The pipeline uses OIDC — those keys are forbidden.


### Step 6.3 — Create GitHub Environments (manual approval gates)

Go to: `https://github.com/YOUR_GITHUB_USERNAME/devsecops-papun/settings/environments`

**Environment 1 — `staging`:**
1. New environment → Name: `staging`
2. Check **Required reviewers** → add yourself → **Save protection rules**

**Environment 2 — `dev-terraform`:**
1. New environment → Name: `dev-terraform`
2. Check **Required reviewers** → add yourself → **Save protection rules**

### Step 6.4 — Update IAM trust policy for your repo

```powershell
# FOLDER: anywhere
$GITHUB_ORG  = "your-github-username"
$REPO_NAME   = "devsecops-papun"
$OIDC_ARN    = "arn:aws:iam::${ACCOUNT_ID}:oidc-provider/token.actions.githubusercontent.com"
$SUB_PATTERN = "repo:${GITHUB_ORG}/${REPO_NAME}:*"
$TRUST = '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Federated":"' + $OIDC_ARN + '"},"Action":"sts:AssumeRoleWithWebIdentity","Condition":{"StringEquals":{"token.actions.githubusercontent.com:aud":"sts.amazonaws.com"},"StringLike":{"token.actions.githubusercontent.com:sub":"' + $SUB_PATTERN + '"}}}]}'
aws iam update-assume-role-policy --role-name genesis-github-actions-deploy --policy-document $TRUST
```

### Step 6.5 — Push the repo to GitHub

```powershell
# FOLDER: C:\Clouddev\devsecops-papun
cd C:\Clouddev\devsecops-papun
git init
git branch -M main
git remote add origin https://github.com/$GITHUB_ORG/devsecops-papun.git
git add .
git commit -m "Initial commit: complete DevSecOps platform"
git push -u origin main
```

After push check Actions tab — nothing should run for a docs/initial commit.
`deploy.yml` WILL trigger on future `app/**` changes to main (that is correct per instructions).

---

## PART 7 — CREATE EC2 VIA TERRAFORM PIPELINE

1. GitHub → Actions → **Terraform IaC Pipeline** → **Run workflow** → Branch `main`
2. Approve `dev-terraform` gate when plan completes
3. Wait for apply (~8 min)

```powershell
# FOLDER: anywhere
$EC2_IP = (aws ec2 describe-instances `
  --filters "Name=tag:Project,Values=genesis" "Name=instance-state-name,Values=running" `
  --query "Reservations[0].Instances[0].PublicIpAddress" --output text)
Write-Host "EC2 IP: $EC2_IP"
```

**Add remaining GitHub secrets now:**
- `K3S_PUBLIC_IP` = value of `$EC2_IP`
- `ARGOCD_SERVER` = `YOUR_EC2_IP:30080`

---

## PART 8 — SSH INTO EC2 AND SET UP k3s

```powershell
# FOLDER: anywhere
ssh -i "$env:USERPROFILE\.ssh\genesis-dev-key.pem" ec2-user@$EC2_IP
```

**All bash commands below run INSIDE the EC2 SSH session.**

```bash
# EC2 FOLDER: ~
sudo systemctl status k3s
# If NOT running: curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="--disable traefik" sh -
```

Configure kubectl:
```bash
# EC2 FOLDER: ~
mkdir -p ~/.kube
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown ec2-user:ec2-user ~/.kube/config
export KUBECONFIG=~/.kube/config
echo 'export KUBECONFIG=~/.kube/config' >> ~/.bashrc
kubectl get nodes  # Must show Ready
```

Get K3S_KUBECONFIG_B64 (add to GitHub secrets):
```bash
# EC2 FOLDER: ~
EC2_IP="YOUR_EC2_PUBLIC_IP"
sed "s|127.0.0.1|$EC2_IP|g" /etc/rancher/k3s/k3s.yaml | base64 -w 0
# Copy the long output line → GitHub secret K3S_KUBECONFIG_B64
```

### Install nginx ingress controller — REQUIRED for canary traffic splitting

> rollout.yaml uses `trafficRouting.nginx.stableIngress`. Without nginx-ingress,
> Argo Rollouts cannot control exact traffic percentages (10%, 25%, 50%).
> Traefik is disabled (`--disable traefik`) so we install nginx-ingress.

```bash
# EC2 FOLDER: ~
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
helm install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx --create-namespace \
  --set controller.service.type=NodePort \
  --set controller.service.nodePorts.http=30081 \
  --set controller.service.nodePorts.https=30444 \
  --wait --timeout 5m
```

Verify:
```bash
# EC2 FOLDER: ~
kubectl get pods -n ingress-nginx
# Expected: ingress-nginx-controller-xxx   1/1   Running
```

---

## PART 9 — CLONE REPO AND CREATE NAMESPACES

```bash
# EC2 FOLDER: ~
git clone https://github.com/YOUR_GITHUB_USERNAME/devsecops-papun.git ~/devsecops-papun
cd ~/devsecops-papun
kubectl apply -f k8s/namespace.yaml
kubectl create namespace argocd        --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace argo-rollouts --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace monitoring    --dry-run=client -o yaml | kubectl apply -f -
kubectl create namespace kyverno       --dry-run=client -o yaml | kubectl apply -f -
kubectl get namespaces
```

---

## PART 10 — INSTALL KYVERNO (MUST BE BEFORE APP DEPLOYMENT)

```bash
# EC2 FOLDER: ~/devsecops-papun
helm repo add kyverno https://kyverno.github.io/kyverno/
helm repo update
helm install kyverno kyverno/kyverno \
  --namespace kyverno \
  --set replicaCount=1 \
  --set resources.requests.cpu=100m \
  --set resources.requests.memory=128Mi \
  --wait --timeout 5m

kubectl apply -f infrastructure/kyverno-policies/no-root-containers.yaml
kubectl apply -f infrastructure/kyverno-policies/require-resource-limits.yaml
kubectl apply -f infrastructure/kyverno-policies/ecr-only-images.yaml
kubectl get clusterpolicies
# All three must show READY=True

kubectl apply -f k8s/flawed-deployment.yaml
# MUST fail with admission webhook denied
```

---

## PART 11 — INSTALL ARGO CD

```bash
# EC2 FOLDER: ~/devsecops-papun
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update
helm install argocd argo/argo-cd \
  --namespace argocd --create-namespace \
  -f k8s/argocd-values.yaml \
  --wait --timeout 10m

kubectl get pods -n argocd

# Get admin password (add to GitHub secret ARGOCD_PASSWORD)
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d; echo

kubectl apply -f k8s/argocd-app.yaml
```

Browser: `https://YOUR_EC2_IP:30443` — login: `admin` / password above.

---

## PART 12 — INSTALL ARGO ROLLOUTS

```bash
# EC2 FOLDER: ~/devsecops-papun
helm install argo-rollouts argo/argo-rollouts \
  --namespace argo-rollouts --set controller.replicas=1 --wait --timeout 5m
kubectl get pods -n argo-rollouts

# Install kubectl plugin
curl -LO https://github.com/argoproj/argo-rollouts/releases/latest/download/kubectl-argo-rollouts-linux-amd64
chmod +x kubectl-argo-rollouts-linux-amd64
sudo mv kubectl-argo-rollouts-linux-amd64 /usr/local/bin/kubectl-argo-rollouts
kubectl argo rollouts version
```

---

## PART 13 — INSTALL PROMETHEUS + GRAFANA

```bash
# EC2 FOLDER: ~/devsecops-papun
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm install kube-prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false \
  --set grafana.adminPassword='admin123!' \
  --set grafana.service.type=NodePort \
  --set grafana.service.nodePort=32000 \
  --set prometheus.service.type=NodePort \
  --set prometheus.service.nodePort=32001 \
  --wait --timeout 10m

kubectl apply -f k8s/prometheus-rules.yaml
kubectl apply -f k8s/grafana-dashboard-configmap.yaml
kubectl apply -f k8s/service.yaml
```

Browser: `http://YOUR_EC2_IP:32000` — login: `admin` / `admin123!`

---

## PART 14 — BUILD AND PUSH DOCKER IMAGE TO ECR

```powershell
# FOLDER: C:\Clouddev\devsecops-papun
$ACCOUNT_ID = (aws sts get-caller-identity --query Account --output text)
$REGION     = "ap-south-1"
$ECR_URI    = "$ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/genesis-platform-api"
$GIT_SHA    = (git rev-parse --short HEAD)

aws ecr get-login-password --region $REGION | `
  docker login --username AWS --password-stdin "$ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com"

docker buildx build --platform linux/amd64 -t "${ECR_URI}:${GIT_SHA}" app/
docker push "${ECR_URI}:${GIT_SHA}"

# Replace REPLACE_GIT_SHA with the real SHA
(Get-Content k8s/rollout.yaml) -replace "REPLACE_GIT_SHA", $GIT_SHA | Set-Content k8s/rollout.yaml -Encoding utf8

git add k8s/rollout.yaml
git commit -m "chore: set ECR image SHA $GIT_SHA in rollout manifest"
git push origin main
# Note: k8s/rollout.yaml is in paths-ignore so this push does NOT trigger deploy.yml
```

---

## PART 15 — DEPLOY APP VIA ARGO CD

```bash
# EC2 FOLDER: ~/devsecops-papun
git pull origin main
grep "image:" k8s/rollout.yaml   # Verify real SHA is present

kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/app-deployment.yaml
kubectl apply -f k8s/analysis-template.yaml
kubectl apply -f k8s/rollout.yaml
kubectl apply -f k8s/service.yaml
kubectl apply -f k8s/ingress.yaml

ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d)
argocd login localhost:30080 --username admin --password "$ARGOCD_PASSWORD" --insecure
argocd app sync genesis-platform-api

kubectl get pods -n staging
# Wait until all 3 pods show Running
```

Test all three endpoints:
```bash
# EC2 FOLDER: ~/devsecops-papun
kubectl port-forward service/genesis-platform-api-stable 8080:80 -n staging &
sleep 3

curl -s http://localhost:8080/health
# Expected: {"status":"ok","version":"1.0.0","namespace":"staging"}

curl -s -X POST http://localhost:8080/platform/units \
  -H "Content-Type: application/json" \
  -d '{"unit_id":"u-001","status":"active","tenant_id":"t-a"}'
# Expected: {"unit_id":"u-001","created_at":"..."}  HTTP 201

curl -s http://localhost:8080/platform/units/u-001
# Expected: full unit record

curl -s http://localhost:8080/platform/units/nonexistent
# Expected: {"detail":{"error":"...","code":"UNIT_NOT_FOUND","request_id":"..."}}

curl -s http://localhost:8080/metrics | grep genesis_units_created_total
# Expected: genesis_units_created_total{tenant_id="t-a"} 1.0

kill %1
```

---

## PART 16 — RUN ALL 13 PIPELINE STAGES

**Stages 1-11 (CI — PR):**
```powershell
# FOLDER: C:\Clouddev\devsecops-papun
git checkout -b feature/test-pipeline
"# pipeline trigger $(Get-Date)" | Add-Content README.md
git add README.md
git commit -m "test: trigger all 13 CI pipeline stages"
git push origin feature/test-pipeline
```

Open a PR on GitHub. Stages 1-11 run automatically.

| Stage | Tool | Expected result |
|---|---|---|
| 1 | Gitleaks | PASSES (allowlist covers app/flaws/) |
| 2 | pip-audit | PASSES, artifact uploaded |
| 3 | Semgrep | PASSES, flaw2_sast.py in SARIF |
| 4 | pytest | PASSES, coverage >= 75% |
| 5 | Docker build | PASSES, non-root verified |
| 6 | Trivy | PASSES or CRITICAL block |
| 7 | SBOM | PASSES, CycloneDX artifact |
| 8 | Cosign | dry-run PASSES |
| 9 | tflint | PASSES, zero errors |
| 10 | Checkov | PASSES, CRITICAL findings block |
| 11 | Kyverno offline | PASSES clean manifests; flawed blocked |

**Stages 12-13 (Deploy — push to main app change):**

Merge the PR. Then make an app code change and push to main:
```powershell
# FOLDER: C:\Clouddev\devsecops-papun
git checkout main && git pull
"# trigger deploy" | Add-Content app/main.py
git add app/main.py
git commit -m "feat: trigger deploy pipeline"
git push origin main
```

`deploy.yml` triggers automatically (push to main, `app/**` path matches). Approve the `staging` environment gate.

| Stage | Expected |
|---|---|
| 12 | Argo CD sync: Synced + Healthy |
| 13 | GET /health returns 200 with namespace=staging |

---

## PART 17 — WATCH THE CANARY ROLLOUT

deploy.yml commits an updated rollout.yaml (new image SHA) and pushes to main.
Argo CD detects it → applies to cluster → Argo Rollouts runs the canary.

```bash
# EC2 FOLDER: ~/devsecops-papun
kubectl argo rollouts get rollout genesis-platform-api -n staging --watch
```

Expected steps (exact progression from instruction.md):
1. setWeight: 10 — 10% traffic to canary
2. pause: 2m — observation window
3. AnalysisRun — Prometheus queries error_rate. ≤2% → promote; >2% → abort+rollback
4. setWeight: 25 — 25% canary, pause 2m
5. setWeight: 50 — 50% canary
6. setWeight: 100 — full rollout

---

## PART 18 — VERIFY ALL 6 GRAFANA PANELS

Browser: `http://YOUR_EC2_IP:32000` → Dashboards → Genesis Platform API

Generate load:
```bash
# EC2 FOLDER: ~/devsecops-papun
kubectl port-forward service/genesis-platform-api-stable 8080:80 -n staging &
sleep 3
for i in $(seq 1 50); do curl -s http://localhost:8080/health > /dev/null; done
for i in $(seq 1 10); do
  curl -s -X POST http://localhost:8080/platform/units \
    -H "Content-Type: application/json" \
    -d "{\"unit_id\":\"a$i\",\"status\":\"active\",\"tenant_id\":\"alpha\"}" > /dev/null
done
kill %1
```

| Panel | Verify |
|---|---|
| HTTP Request Rate | Lines for each endpoint visible |
| Error Rate % (SLI) | Non-zero from 404s |
| Latency P50 / P99 | Two distinct lines |
| Pod CPU Actual vs Limit | Bars for 3 pods |
| Pod Memory Actual vs Limit | Bars for 3 pods |
| Canary vs Stable | Traffic split visible |
| genesis_units_created_total | Line for tenant=alpha at 10 |

---

## PART 19 — VERIFY OPA/CONFTEST POLICIES

```powershell
# FOLDER: anywhere (install conftest)
$CV = "0.51.0"
Invoke-WebRequest -Uri "https://github.com/open-policy-agent/conftest/releases/download/v$CV/conftest_${CV}_Windows_x86_64.zip" -OutFile "$env:TEMP\conftest.zip"
Expand-Archive "$env:TEMP\conftest.zip" -DestinationPath "$env:USERPROFILE\bin" -Force
$env:PATH += ";$env:USERPROFILE\bin"
conftest --version
```

```powershell
# FOLDER: C:\Clouddev\devsecops-papun
# Non-compliant MUST fail
conftest test k8s/flawed-deployment.yaml --policy infrastructure/conftest-policies/kubernetes.rego
# Expected: 1 test, 0 passed, 1 failure

# Compliant MUST pass
conftest test infrastructure/conftest-policies/test/compliant_deployment.yaml `
  --policy infrastructure/conftest-policies/kubernetes.rego
# Expected: 1 test, 1 passed, 0 failures
```

---

## PART 20 — RUN LOCAL TESTS

```powershell
# FOLDER: C:\Clouddev\devsecops-papun\app
cd C:\Clouddev\devsecops-papun\app
py -m pip install -r requirements.txt
py -m pytest tests/ -v --tb=short --cov=. --cov-report=term-missing --cov-fail-under=75
```

Expected: 23+ tests PASSED, coverage ≥ 75%.

---

## PART 21 — GENERATE IAM SIMULATION REPORT

```powershell
# FOLDER: C:\Clouddev\devsecops-papun
$GITHUB_ROLE_ARN = (aws iam get-role --role-name genesis-github-actions-deploy --query 'Role.Arn' --output text)
"=== GitHub Actions Role: $GITHUB_ROLE_ARN ===" | Out-File reports/iam_simulation.txt -Encoding utf8

"--- ECR Push (expected: allowed) ---" | Out-File reports/iam_simulation.txt -Append
aws iam simulate-principal-policy `
  --policy-source-arn $GITHUB_ROLE_ARN `
  --action-names "ecr:GetAuthorizationToken" "ecr:PutImage" `
  --query 'EvaluationResults[*].{Action:EvalActionName,Decision:EvalDecision}' `
  --output table | Out-File reports/iam_simulation.txt -Append

"--- IAM admin (expected: denied) ---" | Out-File reports/iam_simulation.txt -Append
aws iam simulate-principal-policy `
  --policy-source-arn $GITHUB_ROLE_ARN `
  --action-names "iam:CreateUser" "iam:DeleteUser" `
  --query 'EvaluationResults[*].{Action:EvalActionName,Decision:EvalDecision}' `
  --output table | Out-File reports/iam_simulation.txt -Append

$K3S_ROLE_ARN = (aws iam get-role --role-name genesis-k3s-node --query 'Role.Arn' --output text)
"=== k3s Node Role ===" | Out-File reports/iam_simulation.txt -Append
"--- ECR Pull (expected: allowed) ---" | Out-File reports/iam_simulation.txt -Append
aws iam simulate-principal-policy `
  --policy-source-arn $K3S_ROLE_ARN `
  --action-names "ecr:GetAuthorizationToken" "ecr:BatchGetImage" `
  --query 'EvaluationResults[*].{Action:EvalActionName,Decision:EvalDecision}' `
  --output table | Out-File reports/iam_simulation.txt -Append

git add reports/iam_simulation.txt
git commit -m "reports: IAM policy simulation output"
git push origin main
```

---

## PART 22 — RUN CHECKOV AND SAVE REPORT

```powershell
# FOLDER: C:\Clouddev\devsecops-papun
py -m pip install checkov
checkov -d infrastructure/ --output json --compact 2>&1 | Out-File reports/checkov_report.json -Encoding utf8
checkov -d infrastructure/ --compact --quiet
git add reports/checkov_report.json
git commit -m "reports: Checkov IaC static analysis"
git push origin main
```

---

## PART 23 — FINAL VERIFICATION CHECKLIST

```powershell
# S3 bucket compliance
aws s3api get-bucket-versioning --bucket "genesis-devsecops-terraform-state-$ACCOUNT_ID"
# Expected: {"Status": "Enabled"}
aws s3api get-bucket-encryption --bucket "genesis-devsecops-terraform-state-$ACCOUNT_ID"
# Expected: SSEAlgorithm: AES256
aws s3api get-public-access-block --bucket "genesis-devsecops-terraform-state-$ACCOUNT_ID"
# Expected: all four booleans = true

# ECR compliance
aws ecr describe-repositories --repository-names genesis-platform-api `
  --query 'repositories[0].{Mutability:imageTagMutability,ScanOnPush:imageScanningConfiguration.scanOnPush}'
# Expected: {"Mutability": "IMMUTABLE", "ScanOnPush": true}

# Zero REPLACE_ strings remaining
Select-String -Path infrastructure/, k8s/, .github/ -Pattern "320644184091|REPLACE_GITHUB_ORG|REPLACE_WITH_" -Recurse
# Expected: no output

# Zero AWS credentials in workflow files
Select-String -Path .github/workflows/ -Pattern "AWS_ACCESS_KEY_ID" -Recurse
# Expected: no output

# SLO and AnalysisTemplate use same PromQL
Select-String -Path slo/genesis-platform-api-slo.yaml -Pattern "http_requests_total"
Select-String -Path k8s/analysis-template.yaml -Pattern "http_requests_total"
# Expected: both show status_code=~"5.." error rate expression (same base query)
```

---

## QUICK REFERENCE

```powershell
# LOCAL: Restore session variables (run at start of every new PowerShell session)
$ACCOUNT_ID = (aws sts get-caller-identity --query Account --output text)
$REGION     = "ap-south-1"
$ECR_URI    = "$ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/genesis-platform-api"
$GITHUB_ORG = "your-github-username"
$EC2_IP     = (aws ec2 describe-instances --filters "Name=tag:Project,Values=genesis" "Name=instance-state-name,Values=running" --query 'Reservations[0].Instances[0].PublicIpAddress' --output text)

# SSH into EC2
ssh -i "$env:USERPROFILE\.ssh\genesis-dev-key.pem" ec2-user@$EC2_IP

# Build and push (from C:\Clouddev\devsecops-papun)
$SHA = git rev-parse --short HEAD
docker buildx build --platform linux/amd64 -t "${ECR_URI}:${SHA}" app/
docker push "${ECR_URI}:${SHA}"

# Run tests (from C:\Clouddev\devsecops-papun\app)
py -m pytest tests/ -v --cov=. --cov-report=term-missing --cov-fail-under=75
```

```bash
# EC2: Most used commands
kubectl argo rollouts get rollout genesis-platform-api -n staging --watch
kubectl port-forward service/genesis-platform-api-stable 8080:80 -n staging
kubectl get pods -n staging && kubectl get pods -n monitoring && kubectl get pods -n argocd
kubectl get clusterpolicies
argocd app sync genesis-platform-api
cd ~/devsecops-papun && git pull origin main
```

**Browser URLs:**
- Grafana:    `http://EC2_IP:32000`    login: `admin` / `admin123!`
- Argo CD:    `https://EC2_IP:30443`  login: `admin` / (kubectl secret — Part 11)
- Prometheus: `http://EC2_IP:32001`


