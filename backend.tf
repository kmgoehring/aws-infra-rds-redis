terraform {
  required_version = ">= 1.11.0"
  backend "s3" {
    bucket       = "tf-state-<acct>-dev"
    key          = "rds-redis/dev/terraform.tfstate"
    region       = "us-east-1"
    use_lockfile = true
  }
}
