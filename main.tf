terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.5"
    }
  }
}

provider "aws" {
  region = var.region
  # Apply project-wide default tags
  default_tags {
    tags = merge({
      Environment = var.environment
      Project     = var.project
    }, var.tags)
  }
}

# Discover 2 AZs for subnets
data "aws_availability_zones" "available" {
  state = "available"
}

# Amazon Linux 2023 AMI (x86_64) via public SSM parameter
# This avoids hardcoding AMI IDs.
data "aws_ssm_parameter" "al2023_x86_64" {
  name = "/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-6.1-x86_64"
}

locals {
  # Chosen AZs (first two available)
  az0 = data.aws_availability_zones.available.names[0]
  az1 = data.aws_availability_zones.available.names[1]

  # Password fallback + SSH source list
  db_password = var.db_password != null && var.db_password != "" ? var.db_password : random_password.db.result
  ssh_cidrs   = length(var.allowed_ssh_cidrs) > 0 ? var.allowed_ssh_cidrs : [var.my_ip_cidr]
}

# ── Networking (VPC, subnets, routes) ────────────────────────
resource "aws_vpc" "main" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = { Name = "${var.project}-vpc" }
}

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "${var.project}-igw" }
}

# Public subnets (map public IPs on launch)
resource "aws_subnet" "public_a" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[0]
  availability_zone       = local.az0
  map_public_ip_on_launch = true
  tags                    = { Name = "${var.project}-public-a" }
}
resource "aws_subnet" "public_b" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[1]
  availability_zone       = local.az1
  map_public_ip_on_launch = true
  tags                    = { Name = "${var.project}-public-b" }
}

# Public route table + default route to IGW
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
  tags = { Name = "${var.project}-public-rt" }
}
resource "aws_route_table_association" "public_a" {
  subnet_id      = aws_subnet.public_a.id
  route_table_id = aws_route_table.public.id
}
resource "aws_route_table_association" "public_b" {
  subnet_id      = aws_subnet.public_b.id
  route_table_id = aws_route_table.public.id
}

# Private subnets (no NAT/no egress to internet)
resource "aws_subnet" "private_a" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidrs[0]
  availability_zone = local.az0
  tags              = { Name = "${var.project}-private-a" }
}
resource "aws_subnet" "private_b" {
  vpc_id            = aws_vpc.main.id
  cidr_block        = var.private_subnet_cidrs[1]
  availability_zone = local.az1
  tags              = { Name = "${var.project}-private-b" }
}

# (Optional explicit private route tables; default local routing only)
resource "aws_route_table" "private_a" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "${var.project}-private-a-rt" }
}
resource "aws_route_table" "private_b" {
  vpc_id = aws_vpc.main.id
  tags   = { Name = "${var.project}-private-b-rt" }
}
resource "aws_route_table_association" "private_a" {
  subnet_id      = aws_subnet.private_a.id
  route_table_id = aws_route_table.private_a.id
}
resource "aws_route_table_association" "private_b" {
  subnet_id      = aws_subnet.private_b.id
  route_table_id = aws_route_table.private_b.id
}

# ── Security Groups ──────────────────────────────────────────
# App SG: allow SSH from your IPs; egress anywhere
resource "aws_security_group" "app" {
  name        = "${var.project}-app-sg"
  description = "App host security group"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = local.ssh_cidrs
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project}-app-sg" }
}

# RDS SG: allow Postgres only from the app SG
resource "aws_security_group" "rds" {
  name        = "${var.project}-rds-sg"
  description = "Postgres access from app"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "Postgres"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [aws_security_group.app.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project}-rds-sg" }
}

# Redis SG: allow Redis only from the app SG
resource "aws_security_group" "redis" {
  name        = "${var.project}-redis-sg"
  description = "Redis access from app"
  vpc_id      = aws_vpc.main.id

  ingress {
    description     = "Redis"
    from_port       = 6379
    to_port         = 6379
    protocol        = "tcp"
    security_groups = [aws_security_group.app.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project}-redis-sg" }
}

# ── RDS (PostgreSQL) ─
resource "aws_db_subnet_group" "rds" {
  name       = "${var.project}-rds-subnets"
  subnet_ids = [aws_subnet.private_a.id, aws_subnet.private_b.id]
  tags       = { Name = "${var.project}-rds-subnets" }
}

resource "aws_db_instance" "postgres" {
  identifier                 = "${var.project}-postgres"
  engine                     = "postgres"
  engine_version             = var.rds_engine_version
  instance_class             = var.rds_instance_class # e.g., db.t3.micro
  storage_type               = "gp2"                  # free tier aligns with gp2
  allocated_storage          = 20                     # 20 GB free
  db_subnet_group_name       = aws_db_subnet_group.rds.name
  vpc_security_group_ids     = [aws_security_group.rds.id]
  publicly_accessible        = false
  multi_az                   = false
  username                   = var.db_username
  password                   = local.db_password
  db_name                    = var.db_name
  backup_retention_period    = 1
  deletion_protection        = false
  skip_final_snapshot        = true
  apply_immediately          = true
  auto_minor_version_upgrade = true

  tags = { Name = "${var.project}-postgres" }
}

# ── ElastiCache (Redis) ───────────────────────────────────────
resource "aws_elasticache_subnet_group" "redis" {
  name       = "${var.project}-redis-subnets"
  subnet_ids = [aws_subnet.private_a.id, aws_subnet.private_b.id]
}

resource "aws_elasticache_replication_group" "redis" {
  replication_group_id       = "${var.project}-redis"
  description                = "Redis for ${var.project}"
  engine                     = "redis"
  engine_version             = var.redis_engine_version
  node_type                  = var.redis_node_type # e.g., cache.t3.micro
  automatic_failover_enabled = false               # single node
  at_rest_encryption_enabled = false
  transit_encryption_enabled = false
  subnet_group_name          = aws_elasticache_subnet_group.redis.name
  security_group_ids         = [aws_security_group.redis.id]
  maintenance_window         = "sun:04:00-sun:05:00"

  # Place the single cache node in the same AZ as the app host to avoid inter-AZ data transfer.
  preferred_cache_cluster_azs = [local.az0]

  # For single node groups, specify zero replicas
  num_node_groups         = 1
  replicas_per_node_group = 0

  tags = { Name = "${var.project}-redis" }
}

# ── EC2 app host ──────────────────────────────────────────────
resource "aws_instance" "app" {
  ami                         = data.aws_ssm_parameter.al2023_x86_64.value
  instance_type               = var.ec2_instance_type # e.g., t2.micro
  subnet_id                   = aws_subnet.public_a.id
  vpc_security_group_ids      = [aws_security_group.app.id]
  associate_public_ip_address = true
  key_name                    = var.ec2_key_name

  user_data = <<-EOF
              #!/bin/bash
              set -euxo pipefail
              dnf -y update
              # Useful CLI tools for testing
              dnf -y install postgresql15 redis

              cat >/home/ec2-user/test-connections.sh <<'SH'
              #!/bin/bash
              set -e
              echo "Testing Redis ping..."
              redis-cli -h ${aws_elasticache_replication_group.redis.primary_endpoint_address} ping || true

              echo "Testing Postgres connectivity..."
              # export PGPASSWORD if you want non-interactive test
              # export PGPASSWORD="${local.db_password}"
              psql \
                --host='${aws_db_instance.postgres.address}' \
                --port=5432 \
                --username='${var.db_username}' \
                --dbname='${var.db_name}' \
                -c 'SELECT version();' || true
              SH

              chown ec2-user:ec2-user /home/ec2-user/test-connections.sh
              chmod +x /home/ec2-user/test-connections.sh
            EOF

  tags = { Name = "${var.project}-app" }
}
