##############################################################################
# scripts/bootstrap.ps1
# Windows PowerShell equivalent of bootstrap.sh
# Run ONCE before `terraform init`.
##############################################################################
[CmdletBinding()]
param(
    [string]$Region  = $env:AWS_REGION  ?? "ap-south-2",
    [string]$Project = $env:PROJECT     ?? "genesis"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$AccountId   = (aws sts get-caller-identity --query Account --output text)
$StateBucket = "$Project-devsecops-terraform-state-$AccountId"
$LogsBucket  = "$StateBucket-access-logs"
$LockTable   = "$Project-terraform-state-lock"

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  Genesis Platform — Terraform Bootstrap"  -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "Account  : $AccountId"
Write-Host "Region   : $Region"
Write-Host "S3 bucket: $StateBucket"
Write-Host "DynamoDB : $LockTable"
Write-Host ""
$Confirm = Read-Host "Proceed? [y/N]"
if ($Confirm.ToLower() -ne "y") { Write-Host "Aborted."; exit 0 }

function New-BucketIfNotExists([string]$BucketName) {
    try {
        aws s3api head-bucket --bucket $BucketName 2>$null
        Write-Host "      Bucket $BucketName already exists — skipping."
        return $false
    } catch {
        if ($Region -eq "ap-south-2") {
            aws s3api create-bucket --bucket $BucketName --region $Region
        } else {
            aws s3api create-bucket --bucket $BucketName --region $Region `
                --create-bucket-configuration "LocationConstraint=$Region"
        }
        return $true
    }
}

Write-Host "[1/8] Creating access-logs bucket: $LogsBucket"
New-BucketIfNotExists $LogsBucket | Out-Null
aws s3api put-public-access-block --bucket $LogsBucket `
    --public-access-block-configuration `
    "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

Write-Host "[2/8] Creating state bucket: $StateBucket"
New-BucketIfNotExists $StateBucket | Out-Null

Write-Host "[3/8] Enabling versioning"
aws s3api put-bucket-versioning --bucket $StateBucket `
    --versioning-configuration Status=Enabled

Write-Host "[4/8] Enabling AES-256 encryption"
$EncConfig = '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"},"BucketKeyEnabled":true}]}'
aws s3api put-bucket-encryption --bucket $StateBucket `
    --server-side-encryption-configuration $EncConfig

Write-Host "[5/8] Blocking public access"
$PubAccess = "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"
aws s3api put-public-access-block --bucket $StateBucket `
    --public-access-block-configuration $PubAccess

Write-Host "[6/8] Enabling access logging"
$LogConfig = "{`"LoggingEnabled`":{`"TargetBucket`":`"$LogsBucket`",`"TargetPrefix`":`"state-access/`"}}"
aws s3api put-bucket-logging --bucket $StateBucket --bucket-logging-status $LogConfig

Write-Host "[7/8] Tagging state bucket"
aws s3api put-bucket-tagging --bucket $StateBucket `
    --tagging "TagSet=[{Key=Project,Value=$Project},{Key=ManagedBy,Value=bootstrap-script},{Key=Purpose,Value=terraform-state}]"

Write-Host "[8/8] Creating DynamoDB lock table: $LockTable"
try {
    aws dynamodb describe-table --table-name $LockTable --region $Region 2>$null
    Write-Host "      Table already exists — skipping."
} catch {
    aws dynamodb create-table `
        --table-name $LockTable `
        --attribute-definitions AttributeName=LockID,AttributeType=S `
        --key-schema AttributeName=LockID,KeyType=HASH `
        --billing-mode PAY_PER_REQUEST `
        --region $Region `
        --tags Key=Project,Value=$Project Key=ManagedBy,Value=bootstrap-script
    aws dynamodb wait table-exists --table-name $LockTable --region $Region
}

Write-Host ""
Write-Host "==========================================" -ForegroundColor Green
Write-Host "  Bootstrap Complete!"                      -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
Write-Host ""
Write-Host "Update backend.hcl with:"
Write-Host "  bucket         = `"$StateBucket`""
Write-Host "  region         = `"$Region`""
Write-Host "  dynamodb_table = `"$LockTable`""
Write-Host "  encrypt        = true"
Write-Host ""
Write-Host "Then:"
Write-Host "  cd infrastructure/environments/dev"
Write-Host "  terraform init -backend-config=backend.hcl"
Write-Host "  terraform plan -var-file=terraform.tfvars"
