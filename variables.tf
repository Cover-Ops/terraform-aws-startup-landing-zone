variable "project" {
  description = "Short name of the product or company, used in names and the Project tag (lowercase, digits, hyphens)."
  type        = string
  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{1,30}$", var.project))
    error_message = "Use 2-31 characters: lowercase letters, digits and hyphens, starting with a letter."
  }
}

variable "environment" {
  description = "Which environment this account is: production, staging or development."
  type        = string
  validation {
    condition     = contains(["production", "staging", "development"], var.environment)
    error_message = "Use production, staging or development."
  }
}

variable "owner" {
  description = "Who answers for spend in this account: a team or a person's email. Goes in the Owner tag."
  type        = string
}

variable "cost_centre" {
  description = "Cost centre or budget line for the CostCentre tag, e.g. engineering."
  type        = string
  default     = "engineering"
}

variable "monthly_budget_usd" {
  description = "The account's monthly budget in US dollars (AWS bills in USD). Alerts go out at 80% actual and 100% forecast."
  type        = number
  validation {
    condition     = var.monthly_budget_usd > 0
    error_message = "The budget must be more than 0."
  }
}

variable "alert_emails" {
  description = "Who gets budget and cost-anomaly alerts. At least one address."
  type        = list(string)
  validation {
    condition     = length(var.alert_emails) > 0
    error_message = "Give at least one email address."
  }
}

variable "anomaly_threshold_usd" {
  description = "Email when a cost anomaly's total impact reaches this many US dollars."
  type        = number
  default     = 25
}

variable "anomaly_monitor_arn" {
  description = "ARN of an existing AWS-services cost-anomaly monitor to alert on. Leave null to create one (an account can have only one)."
  type        = string
  default     = null
}

variable "enable_cost_guardrails" {
  description = "Create the monthly budget and cost-anomaly alerts. Set false if the aws-cost-guardrails kit already runs in this account: both use the same names."
  type        = bool
  default     = true
}

variable "manage_s3_public_access_block" {
  description = "Block public S3 access for the whole account. Set false if another stack or your organisation already manages it. Destroy switches it off."
  type        = bool
  default     = true
}

variable "manage_ebs_encryption" {
  description = "Encrypt every new EBS volume in this region by default. Set false if something else manages it. Destroy switches it off."
  type        = bool
  default     = true
}

variable "manage_password_policy" {
  description = "Set the account's IAM password policy. Set false if the account already has one you keep elsewhere. Destroy deletes it."
  type        = bool
  default     = true
}

variable "cloudtrail_force_destroy" {
  description = "Let terraform destroy delete the trail bucket with its logs. Keep false in real accounts: the logs are your audit record."
  type        = bool
  default     = false
}

variable "enable_cloudtrail" {
  description = "Record management events for the whole account in an encrypted S3 bucket. The first trail's management events are free; you pay only for S3 storage."
  type        = bool
  default     = true
}

variable "cloudtrail_retention_days" {
  description = "Days to keep CloudTrail logs before they are deleted."
  type        = number
  default     = 365
}

variable "extra_tags" {
  description = "More tags to add to everything this kit creates."
  type        = map(string)
  default     = {}
}
