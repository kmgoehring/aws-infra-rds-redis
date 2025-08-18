terraform {
  backend "s3" {
    bucket         = "tf-state-850924742419-dev"
    key            = "rds-redis/dev/smoke.tfstate"
    region         = "us-east-1"
    dynamodb_table = "tf-locks-dev"
    encrypt        = true
  }
}
provider "aws" { region = "us-east-1" }
resource "null_resource" "touch" {}
