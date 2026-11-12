# CoverOps Marketplace kit: AWS startup landing zone with cost guardrails.
# One account, set up the way the CoverOps Platform would like to find it:
# every resource tagged, a budget with alerts, cost-anomaly alerts, and safe
# account-wide security defaults. Apache 2.0.

data "aws_caller_identity" "this" {}
data "aws_partition" "this" {}
data "aws_region" "this" {}

locals {
  # The mandatory tags. Use them on your own resources too: the provider's
  # default_tags block (see README) applies them to everything you create.
  tags = merge(var.extra_tags, {
    Project     = var.project
    Environment = var.environment
    Owner       = var.owner
    CostCentre  = var.cost_centre
    ManagedBy   = "terraform"
    Kit         = "coverops/aws-startup-landing-zone"
  })
  account_id = data.aws_caller_identity.this.account_id
  name       = "${var.project}-${var.environment}"
  # One AWS-services monitor per account: reuse it if the account already has one.
  anomaly_monitor_arn = var.enable_cost_guardrails ? coalesce(var.anomaly_monitor_arn, one(aws_ce_anomaly_monitor.services[*].arn)) : null
}

# --- Cost guardrails -------------------------------------------------------
# The same resources as the aws-cost-guardrails kit. Applying both to one account clashes on names:
# use one, or set enable_cost_guardrails = false here (#7).

resource "aws_budgets_budget" "monthly" {
  count        = var.enable_cost_guardrails ? 1 : 0
  name         = "${local.name}-monthly"
  budget_type  = "COST"
  limit_amount = tostring(var.monthly_budget_usd)
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = var.alert_emails
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = var.alert_emails
  }

  tags = local.tags
}

resource "aws_ce_anomaly_monitor" "services" {
  count             = var.enable_cost_guardrails && var.anomaly_monitor_arn == null ? 1 : 0
  name              = "${local.name}-services"
  monitor_type      = "DIMENSIONAL"
  monitor_dimension = "SERVICE"
  tags              = local.tags
}

resource "aws_ce_anomaly_subscription" "email" {
  count            = var.enable_cost_guardrails ? 1 : 0
  name             = "${local.name}-anomalies"
  frequency        = "DAILY"
  monitor_arn_list = [local.anomaly_monitor_arn]

  dynamic "subscriber" {
    for_each = toset(var.alert_emails)
    content {
      type    = "EMAIL"
      address = subscriber.value
    }
  }

  threshold_expression {
    dimension {
      key           = "ANOMALY_TOTAL_IMPACT_ABSOLUTE"
      match_options = ["GREATER_THAN_OR_EQUAL"]
      values        = [tostring(var.anomaly_threshold_usd)]
    }
  }

  tags = local.tags
}

# --- Account-wide security defaults ----------------------------------------
# Account singletons: one per account (EBS encryption: per region). `terraform destroy` switches
# them back OFF. Turn a switch off if something else already manages it (#8); to keep them after
# removing the kit, run `terraform state rm` on them before destroy (README, "Before you destroy").

# No bucket in this account can be made public by accident.
resource "aws_s3_account_public_access_block" "this" {
  count                   = var.manage_s3_public_access_block ? 1 : 0
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Every new EBS volume and snapshot is encrypted, in this region.
resource "aws_ebs_encryption_by_default" "this" {
  count   = var.manage_ebs_encryption ? 1 : 0
  enabled = true
}

resource "aws_iam_account_password_policy" "this" {
  count                          = var.manage_password_policy ? 1 : 0
  minimum_password_length        = 14
  require_lowercase_characters   = true
  require_uppercase_characters   = true
  require_numbers                = true
  require_symbols                = true
  allow_users_to_change_password = true
  password_reuse_prevention      = 24
  max_password_age               = 0 # rotation by age is not required; use MFA
}

# Free: tells you when a resource is shared outside the account.
resource "aws_accessanalyzer_analyzer" "account" {
  analyzer_name = "${local.name}-access"
  type          = "ACCOUNT"
  tags          = local.tags
}

# --- Audit trail (optional, on by default) ---------------------------------

resource "aws_s3_bucket" "trail" {
  count         = var.enable_cloudtrail ? 1 : 0
  bucket        = "${local.name}-trail-${local.account_id}" # fits the 63-character limit
  force_destroy = var.cloudtrail_force_destroy
  tags          = local.tags
}

resource "aws_s3_bucket_public_access_block" "trail" {
  count                   = var.enable_cloudtrail ? 1 : 0
  bucket                  = aws_s3_bucket.trail[0].id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "trail" {
  count  = var.enable_cloudtrail ? 1 : 0
  bucket = aws_s3_bucket.trail[0].id
  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_versioning" "trail" {
  count  = var.enable_cloudtrail ? 1 : 0
  bucket = aws_s3_bucket.trail[0].id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "trail" {
  count  = var.enable_cloudtrail ? 1 : 0
  bucket = aws_s3_bucket.trail[0].id
  rule {
    id     = "expire-logs"
    status = "Enabled"
    filter {}
    expiration {
      days = var.cloudtrail_retention_days
    }
    noncurrent_version_expiration {
      noncurrent_days = 30
    }
  }
}

data "aws_iam_policy_document" "trail" {
  count = var.enable_cloudtrail ? 1 : 0

  statement {
    sid       = "AWSCloudTrailAclCheck"
    actions   = ["s3:GetBucketAcl"]
    resources = [aws_s3_bucket.trail[0].arn]
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceArn"
      values   = ["arn:${data.aws_partition.this.partition}:cloudtrail:${data.aws_region.this.region}:${local.account_id}:trail/${local.name}"]
    }
  }

  statement {
    sid       = "AWSCloudTrailWrite"
    actions   = ["s3:PutObject"]
    resources = ["${aws_s3_bucket.trail[0].arn}/AWSLogs/${local.account_id}/*"]
    principals {
      type        = "Service"
      identifiers = ["cloudtrail.amazonaws.com"]
    }
    condition {
      test     = "StringEquals"
      variable = "s3:x-amz-acl"
      values   = ["bucket-owner-full-control"]
    }
    condition {
      test     = "StringEquals"
      variable = "aws:SourceArn"
      values   = ["arn:${data.aws_partition.this.partition}:cloudtrail:${data.aws_region.this.region}:${local.account_id}:trail/${local.name}"]
    }
  }

  statement {
    sid       = "DenyInsecureTransport"
    effect    = "Deny"
    actions   = ["s3:*"]
    resources = [aws_s3_bucket.trail[0].arn, "${aws_s3_bucket.trail[0].arn}/*"]
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "trail" {
  count  = var.enable_cloudtrail ? 1 : 0
  bucket = aws_s3_bucket.trail[0].id
  policy = data.aws_iam_policy_document.trail[0].json
}

resource "aws_cloudtrail" "this" {
  count                         = var.enable_cloudtrail ? 1 : 0
  name                          = local.name
  s3_bucket_name                = aws_s3_bucket.trail[0].id
  is_multi_region_trail         = true
  include_global_service_events = true
  enable_log_file_validation    = true
  tags                          = local.tags

  depends_on = [aws_s3_bucket_policy.trail]
}
