# A startup's production account in Mumbai, set up in one apply.
locals {
  project     = "acme"
  environment = "production"
  owner       = "platform@acme.example"
}

provider "aws" {
  region = "ap-south-1"

  # The same mandatory tags on everything else you create with this provider.
  default_tags {
    tags = {
      Project     = local.project
      Environment = local.environment
      Owner       = local.owner
      CostCentre  = "engineering"
      ManagedBy   = "terraform"
    }
  }
}

module "landing_zone" {
  source = "../.."
  # After publishing: source = "github.com/Cover-Ops/terraform-aws-startup-landing-zone?ref=v0.2.0"

  project            = local.project
  environment        = local.environment
  owner              = local.owner
  monthly_budget_usd = 3500
  alert_emails       = ["platform@acme.example", "cto@acme.example"]
}
