# ──────────────────────────────────────────────────────────────────────────────
# AWS Free Tier: EC2 + RDS (Postgres) + ElastiCache (Redis) deployed as a stack via Terraform
# VPC with public/private subnets (no NAT), single public EC2 app host,
# private RDS + Redis accessible only from the app SG.
#
# Notes:
# - Keep to free tier: t2.micro (EC2), db.t3.micro (RDS single-AZ), cache.t3.micro (Redis).
# - No NAT Gateway, no ALB. One EC2 instance only.
# - gp2 storage for RDS (20 GB) to align with free tier.
#
# Files in this document:
#   1) main.tf
#   2) variables.tf
#   3) outputs.tf
#   4) terraform.tfvars.example
# ──────────────────────────────────────────────────────────────────────────────
