##############################################################################
# modules/iam/main.tf
# Creates least-privilege IAM resources:
#   1. k3s EC2 node role — ECR pull, CloudWatch logs, SSM (no SSH needed)
#   2. GitHub Actions OIDC provider + deployment role — ECR push, S3, ArgoCD
##############################################################################

data "aws_caller_identity" "current" {}
data "aws_region" "current" {}

##############################################################################
# k3s EC2 Node Role
##############################################################################
resource "aws_iam_role" "k3s_node" {
  name = "${var.project}-${var.environment}-k3s-node-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })

  tags = merge(var.common_tags, {
    Name = "${var.project}-${var.environment}-k3s-node-role"
  })
}

# ECR read — pull images during pod scheduling
resource "aws_iam_policy" "k3s_ecr_pull" {
  name        = "${var.project}-${var.environment}-k3s-ecr-pull"
  description = "Allow k3s node to pull images from ECR."

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ECRLogin"
        Effect = "Allow"
        Action = ["ecr:GetAuthorizationToken"]
        Resource = "*"
      },
      {
        Sid    = "ECRImagePull"
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:DescribeImages"
        ]
        Resource = "arn:aws:ecr:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:repository/${var.ecr_repository_name}"
      }
    ]
  })
}

# CloudWatch Logs — publish k3s and application logs
resource "aws_iam_policy" "k3s_cloudwatch" {
  name        = "${var.project}-${var.environment}-k3s-cloudwatch"
  description = "Allow k3s node to publish logs to CloudWatch."

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "CloudWatchLogs"
      Effect = "Allow"
      Action = [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents",
        "logs:DescribeLogStreams"
      ]
      Resource = "arn:aws:logs:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:log-group:/genesis/*"
    }]
  })
}

# SSM Session Manager — secure shell without open port 22
resource "aws_iam_role_policy_attachment" "k3s_ssm" {
  role       = aws_iam_role.k3s_node.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy_attachment" "k3s_ecr" {
  role       = aws_iam_role.k3s_node.name
  policy_arn = aws_iam_policy.k3s_ecr_pull.arn
}

resource "aws_iam_role_policy_attachment" "k3s_cw" {
  role       = aws_iam_role.k3s_node.name
  policy_arn = aws_iam_policy.k3s_cloudwatch.arn
}

##############################################################################
# GitHub Actions OIDC Provider
##############################################################################
resource "aws_iam_openid_connect_provider" "github_actions" {
  url = "https://token.actions.githubusercontent.com"

  client_id_list = ["sts.amazonaws.com"]

  # GitHub's OIDC thumbprint (stable — GitHub rotates cert but thumbprint
  # check is effectively disabled for token.actions.githubusercontent.com
  # per AWS documentation; keeping a valid value here for form.)
  thumbprint_list = ["6938fd4d98bab03faadb97b34396831e3780aea1"]

  tags = merge(var.common_tags, {
    Name = "${var.project}-github-actions-oidc"
  })
}

##############################################################################
# GitHub Actions Deployment Role
##############################################################################
resource "aws_iam_role" "github_actions" {
  name                 = "${var.project}-${var.environment}-github-actions-role"
  max_session_duration = 3600

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = aws_iam_openid_connect_provider.github_actions.arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com"
        }
        StringLike = {
          # Restrict to the specific repository and branch patterns
          "token.actions.githubusercontent.com:sub" = "repo:${var.github_org}/${var.github_repo}:*"
        }
      }
    }]
  })

  tags = merge(var.common_tags, {
    Name = "${var.project}-${var.environment}-github-actions-role"
  })
}

# ECR push permissions for CI/CD pipeline
resource "aws_iam_policy" "github_actions_ecr" {
  name        = "${var.project}-${var.environment}-github-actions-ecr"
  description = "Allow GitHub Actions to build and push images to ECR."

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "ECRLogin"
        Effect = "Allow"
        Action = ["ecr:GetAuthorizationToken"]
        Resource = "*"
      },
      {
        Sid    = "ECRPush"
        Effect = "Allow"
        Action = [
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload",
          "ecr:PutImage",
          "ecr:DescribeImages",
          "ecr:DescribeRepositories",
          "ecr:ListImages"
        ]
        Resource = "arn:aws:ecr:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:repository/${var.ecr_repository_name}"
      }
    ]
  })
}

# S3 read/write for Terraform state (CI validates IaC)
resource "aws_iam_policy" "github_actions_s3" {
  name        = "${var.project}-${var.environment}-github-actions-s3"
  description = "Allow GitHub Actions to read Terraform state from S3."

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "TerraformState"
      Effect = "Allow"
      Action = [
        "s3:GetObject",
        "s3:PutObject",
        "s3:ListBucket"
      ]
      Resource = [
        "arn:aws:s3:::${var.state_bucket_name}",
        "arn:aws:s3:::${var.state_bucket_name}/*"
      ]
    }]
  })
}

# DynamoDB state locking
resource "aws_iam_policy" "github_actions_dynamodb" {
  name = "${var.project}-${var.environment}-github-actions-dynamodb"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "dynamodb:GetItem",
        "dynamodb:PutItem",
        "dynamodb:DeleteItem"
      ]
      Resource = "arn:aws:dynamodb:${data.aws_region.current.name}:${data.aws_caller_identity.current.account_id}:table/${var.state_lock_table_name}"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "github_ecr" {
  role       = aws_iam_role.github_actions.name
  policy_arn = aws_iam_policy.github_actions_ecr.arn
}

resource "aws_iam_role_policy_attachment" "github_s3" {
  role       = aws_iam_role.github_actions.name
  policy_arn = aws_iam_policy.github_actions_s3.arn
}

resource "aws_iam_role_policy_attachment" "github_dynamodb" {
  role       = aws_iam_role.github_actions.name
  policy_arn = aws_iam_policy.github_actions_dynamodb.arn
}
