#!/usr/bin/env bash
##############################################################################
# scripts/bootstrap.sh
#
# ONE-TIME setup script. Run this BEFORE `terraform init`.
#
# This script solves the chicken-and-egg problem:
#   - Terraform needs an S3 bucket for remote state
#   - But Terraform manages all other infrastructure
#   - So the state backend must be created imperatively via AWS CLI first
#
# What this creates:
#   1. S3 bucket for Terraform state (versioned, encrypted, access-logged)
#   2. Separate S3 bucket for access logs
#   3. DynamoDB table for state locking (PAY_PER_REQUEST = free tier)
#
# Prerequisites:
#   - AWS CLI >= 2.x
#   - Credentials with: s3:CreateBucket, s3:PutBucketVersioning,
#     s3:PutBucketEncryption, s3:PutPublicAccessBlock,
#     s3:PutBucketLogging, dynamodb:CreateTable
#
# Usage:
#   export AWS_REGION=ap-south-1
#   export PROJECT=genesis
#   bash scripts/bootstrap.sh
##############################################################################
set -euo pipefail

# ── Configuration ─────────────────────────────────────────────────────────
REGION="${AWS_REGION:-ap-south-1}"
PROJECT="${PROJECT:-genesis}"

ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
STATE_BUCKET="${PROJECT}-devsecops-terraform-state-${ACCOUNT_ID}"
LOGS_BUCKET="${STATE_BUCKET}-access-logs"
LOCK_TABLE="${PROJECT}-terraform-state-lock"

echo "=========================================="
echo "  Genesis Platform — Terraform Bootstrap"
echo "=========================================="
echo "Account  : ${ACCOUNT_ID}"
echo "Region   : ${REGION}"
echo "Project  : ${PROJECT}"
echo "S3 bucket: ${STATE_BUCKET}"
echo "DynamoDB : ${LOCK_TABLE}"
echo ""
read -r -p "Proceed? [y/N] " CONFIRM
[[ "${CONFIRM,,}" == "y" ]] || { echo "Aborted."; exit 0; }

# ── Helper: bucket exists check ────────────────────────────────────────────
bucket_exists() {
  aws s3api head-bucket --bucket "$1" 2>/dev/null
}

# ── Step 1: Create access-logs bucket ─────────────────────────────────────
echo ""
echo "[1/8] Creating access-logs bucket: ${LOGS_BUCKET}"
if bucket_exists "${LOGS_BUCKET}"; then
  echo "      Already exists — skipping."
else
  if [ "${REGION}" = "ap-south-1" ]; then
    aws s3api create-bucket \
      --bucket "${LOGS_BUCKET}" \
      --region "${REGION}"
  else
    aws s3api create-bucket \
      --bucket "${LOGS_BUCKET}" \
      --region "${REGION}" \
      --create-bucket-configuration "LocationConstraint=${REGION}"
  fi
fi

# Block public access on logs bucket
aws s3api put-public-access-block \
  --bucket "${LOGS_BUCKET}" \
  --public-access-block-configuration \
  "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

# Enable encryption on logs bucket
aws s3api put-bucket-encryption \
  --bucket "${LOGS_BUCKET}" \
  --server-side-encryption-configuration \
  '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"},"BucketKeyEnabled":true}]}'

# ── Step 2: Create state bucket ───────────────────────────────────────────
echo "[2/8] Creating state bucket: ${STATE_BUCKET}"
if bucket_exists "${STATE_BUCKET}"; then
  echo "      Already exists — skipping."
else
  if [ "${REGION}" = "ap-south-1" ]; then
    aws s3api create-bucket \
      --bucket "${STATE_BUCKET}" \
      --region "${REGION}"
  else
    aws s3api create-bucket \
      --bucket "${STATE_BUCKET}" \
      --region "${REGION}" \
      --create-bucket-configuration "LocationConstraint=${REGION}"
  fi
fi

# ── Step 3: Enable versioning ─────────────────────────────────────────────
echo "[3/8] Enabling versioning on state bucket"
aws s3api put-bucket-versioning \
  --bucket "${STATE_BUCKET}" \
  --versioning-configuration Status=Enabled

# ── Step 4: Enable server-side encryption (AES-256) ───────────────────────
echo "[4/8] Enabling AES-256 encryption"
aws s3api put-bucket-encryption \
  --bucket "${STATE_BUCKET}" \
  --server-side-encryption-configuration \
  '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"},"BucketKeyEnabled":true}]}'

# ── Step 5: Block all public access ───────────────────────────────────────
echo "[5/8] Blocking all public access"
aws s3api put-public-access-block \
  --bucket "${STATE_BUCKET}" \
  --public-access-block-configuration \
  "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

# ── Step 6: Enable access logging ─────────────────────────────────────────
echo "[6/8] Enabling access logging → ${LOGS_BUCKET}"

# Grant S3 Log Delivery write permission on the logs bucket
aws s3api put-bucket-acl \
  --bucket "${LOGS_BUCKET}" \
  --grant-write "URI=http://acs.amazonaws.com/groups/s3/LogDelivery" \
  --grant-read-acp "URI=http://acs.amazonaws.com/groups/s3/LogDelivery" 2>/dev/null || true

aws s3api put-bucket-logging \
  --bucket "${STATE_BUCKET}" \
  --bucket-logging-status "{
    \"LoggingEnabled\": {
      \"TargetBucket\": \"${LOGS_BUCKET}\",
      \"TargetPrefix\": \"state-access/\"
    }
  }"

# ── Step 7: Tag the state bucket ──────────────────────────────────────────
echo "[7/8] Tagging state bucket"
aws s3api put-bucket-tagging \
  --bucket "${STATE_BUCKET}" \
  --tagging "TagSet=[
    {Key=Project,Value=${PROJECT}},
    {Key=ManagedBy,Value=bootstrap-script},
    {Key=Purpose,Value=terraform-state},
    {Key=Owner,Value=platform-team}
  ]"

# ── Step 8: Create DynamoDB lock table ────────────────────────────────────
echo "[8/8] Creating DynamoDB lock table: ${LOCK_TABLE}"
if aws dynamodb describe-table --table-name "${LOCK_TABLE}" --region "${REGION}" 2>/dev/null; then
  echo "      Already exists — skipping."
else
  aws dynamodb create-table \
    --table-name "${LOCK_TABLE}" \
    --attribute-definitions AttributeName=LockID,AttributeType=S \
    --key-schema AttributeName=LockID,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST \
    --region "${REGION}" \
    --tags \
      Key=Project,Value="${PROJECT}" \
      Key=ManagedBy,Value=bootstrap-script \
      Key=Purpose,Value=terraform-state-lock \
      Key=Owner,Value=platform-team

  echo "      Waiting for DynamoDB table to become ACTIVE..."
  aws dynamodb wait table-exists --table-name "${LOCK_TABLE}" --region "${REGION}"
fi

# ── Output backend configuration ──────────────────────────────────────────
echo ""
echo "=========================================="
echo "  Bootstrap Complete!"
echo "=========================================="
echo ""
echo "Update your backend.hcl files with these values:"
echo ""
echo "  bucket         = \"${STATE_BUCKET}\""
echo "  region         = \"${REGION}\""
echo "  dynamodb_table = \"${LOCK_TABLE}\""
echo "  encrypt        = true"
echo ""
echo "Also update terraform.tfvars:"
echo "  state_bucket_name     = \"${STATE_BUCKET}\""
echo "  state_lock_table_name = \"${LOCK_TABLE}\""
echo ""
echo "Then initialise each environment:"
echo "  cd infrastructure/environments/dev"
echo "  terraform init -backend-config=backend.hcl"
echo "  terraform plan -var-file=terraform.tfvars"
echo ""
