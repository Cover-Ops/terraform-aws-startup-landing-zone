# AWS startup landing zone with cost guardrails

A CoverOps Marketplace kit. One apply sets up a new AWS account the safe, cost-aware way: every resource tagged, a monthly budget with alerts, cost-anomaly alerts, and account-wide security defaults. Terraform ≥ 1.6 or OpenTofu ≥ 1.6, AWS provider 6.x. Apache 2.0.

> Status: **v0.2.0, tested on 2026-11-12**: applied, re-planned with no changes and destroyed on a sandbox AWS account (ap-south-1), nothing left behind. Run `terraform plan` before you apply it to your account.

## What it creates

| Resource | Why | Cost |
|---|---|---|
| AWS Budget (monthly, USD) with alerts at 80% actual and 100% forecast | You hear about overspend before the invoice | Free (budgets without actions) |
| Cost Anomaly Detection monitor (or your existing one) + daily email subscription | Spikes in any service are flagged within a day | Free |
| S3 account-level public access block | No bucket can be made public by accident | Free |
| EBS encryption by default (this region) | New disks and snapshots are encrypted | Free |
| IAM password policy (14+ characters, all character types, no reuse of the last 24) | Stronger console passwords | Free |
| IAM Access Analyzer (account) | Tells you when something is shared outside the account | Free |
| CloudTrail (all regions, management events, log validation) + encrypted, versioned S3 bucket, logs deleted after 365 days | An audit trail of every change | First trail's management events free; S3 storage only, usually under ₹100/month for a startup (estimate) |

**Estimated monthly cost: under ₹100** for a small account (estimate, at list prices; S3 storage depends on activity).

## Mandatory tags
Everything the kit creates carries `Project`, `Environment`, `Owner`, `CostCentre`, `ManagedBy` and `Kit`. Put the same tags in your provider's `default_tags` (see the example) so everything **you** create carries them too. The CoverOps Platform reads these tags to say who owns each rupee.

## Use

```hcl
module "landing_zone" {
  source = "github.com/Cover-Ops/terraform-aws-startup-landing-zone?ref=v0.2.0"

  project            = "acme"
  environment        = "production"
  owner              = "platform@acme.example"
  monthly_budget_usd = 3500
  alert_emails       = ["platform@acme.example"]
}
```

Full example: [`examples/basic`](examples/basic). Apply it once per account, in your main region (EBS default encryption is per region: apply the kit, or just that resource, in each region you use).

## Inputs

| Name | Description | Default |
|---|---|---|
| `project` | Short product/company name (lowercase, digits, hyphens) | required |
| `environment` | `production`, `staging` or `development` | required |
| `owner` | Team or email that answers for spend | required |
| `cost_centre` | Budget line for the CostCentre tag | `engineering` |
| `monthly_budget_usd` | Monthly budget in USD | required |
| `alert_emails` | Who gets budget and anomaly emails | required |
| `anomaly_threshold_usd` | Alert when an anomaly's impact reaches this | `25` |
| `anomaly_monitor_arn` | Reuse an existing AWS-services anomaly monitor | `null` (create one) |
| `enable_cost_guardrails` | Budget + anomaly alerts (`false` if `aws-cost-guardrails` already runs in this account) | `true` |
| `manage_s3_public_access_block` | Manage the account's S3 public access block | `true` |
| `manage_ebs_encryption` | Manage EBS default encryption in this region | `true` |
| `manage_password_policy` | Manage the account's IAM password policy | `true` |
| `enable_cloudtrail` | Create the audit trail | `true` |
| `cloudtrail_force_destroy` | Let destroy delete the trail bucket and its logs | `false` |
| `cloudtrail_retention_days` | Days to keep trail logs | `365` |
| `extra_tags` | More tags on everything | `{}` |

## Outputs
`tags`, `budget_name`, `anomaly_monitor_arn`, `cloudtrail_bucket`.

## Before you apply
Run `terraform plan` and read it. Check these first; each has a switch:
- **Another stack already manages an account setting** (S3 public access block, EBS default encryption, the IAM password policy): set its `manage_*` input to `false`, or two tools will keep overwriting each other.
- **The account already has a CloudTrail trail**: a second trail's management events are charged. Set `enable_cloudtrail = false` and keep yours.
- **AWS Organizations SCPs** can deny `iam:UpdateAccountPasswordPolicy` or `s3:PutAccountPublicAccessBlock` in member accounts: switch those off, the organisation already manages them.
- **`aws-cost-guardrails` is already applied** in this account: set `enable_cost_guardrails = false` (same budget and anomaly names).
- **Budgets are in US dollars**, even for accounts billed in rupees: ₹1 lakh a month is about USD 1,200.

## Before you destroy
`terraform destroy` **switches the account settings back off**: S3 public access becomes possible again, new EBS volumes are no longer encrypted by default, the password policy is deleted. To remove the kit but keep them:

```sh
terraform state rm 'module.landing_zone.aws_s3_account_public_access_block.this[0]'   'module.landing_zone.aws_ebs_encryption_by_default.this[0]'   'module.landing_zone.aws_iam_account_password_policy.this[0]'
terraform destroy
```

The trail bucket keeps its logs: destroy stops at a non-empty bucket unless `cloudtrail_force_destroy = true`.

## Good to know
- Alert emails need no confirmation, but check spam the first time.
- An account can have only one AWS-services anomaly monitor, and newer accounts get one from AWS automatically. If `apply` fails on the monitor, pass its ARN (Billing → Cost Anomaly Detection → Cost monitors) as `anomaly_monitor_arn`.

## Not included (other kits)
Non-production auto-stop (`aws-nonprod-autostop`), the Terraform CI/CD pipeline (`github-terraform-pipeline`) and right-sized compute are separate CoverOps Marketplace kits. The cost part of this kit is also sold alone as `aws-cost-guardrails`, for accounts that already have their security basics.

## Support
Open an issue on GitHub. Want Coverops engineers to apply it for you? ₹14,999 + GST per kit, or the fee back if it doesn't apply cleanly: marketplace.coverops.dev.
