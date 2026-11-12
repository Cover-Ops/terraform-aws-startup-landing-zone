output "tags" {
  description = "The mandatory tags. Pass them to your provider's default_tags so everything you build carries them."
  value       = local.tags
}

output "budget_name" {
  description = "Name of the monthly AWS budget."
  value       = one(aws_budgets_budget.monthly[*].name)
}

output "anomaly_monitor_arn" {
  description = "ARN of the cost-anomaly monitor the alerts watch."
  value       = local.anomaly_monitor_arn
}

output "cloudtrail_bucket" {
  description = "The S3 bucket holding CloudTrail logs, if the trail is on."
  value       = var.enable_cloudtrail ? aws_s3_bucket.trail[0].id : null
}
