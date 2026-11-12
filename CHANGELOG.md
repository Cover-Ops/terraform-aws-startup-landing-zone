# Changelog

Semantic versions. Every release lists its sandbox test result.

## 0.2.0 (2026-11-12)
- `enable_cost_guardrails` switch, so it can share an account with `aws-cost-guardrails` (#7).
- A switch per account-wide setting: `manage_s3_public_access_block`, `manage_ebs_encryption`, `manage_password_policy` (#8).
- README: "Before you apply" and "Before you destroy".
- `cloudtrail_force_destroy`, off by default.
- Sandbox test: **passed 2026-11-12** (AWS ap-south-1: apply, re-plan with no changes, destroy, nothing left).

## 0.1.0 (2026-11-10)
- First release: monthly budget with 80% actual / 100% forecast alerts, cost-anomaly monitor (or reuse of an existing one) and daily email, S3 account public access block, EBS default encryption, IAM password policy, IAM Access Analyzer, optional CloudTrail with an encrypted, versioned, lifecycle-managed bucket.
- Mandatory tags on everything: Project, Environment, Owner, CostCentre, ManagedBy, Kit.
- Sandbox test: **not run yet**.
