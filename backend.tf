terraform {
  backend "s3" {
    bucket         = "tf-state-850924742419-dev"
    key            = "rds-redis/dev/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "tf-locks-dev"
    encrypt        = true
  }
}
