# ================= 5) envs/dev/terraform.tfvars =================

environment          = "dev"
project              = "interview"
region               = "us-east-1"
tags                 = { Owner = "kevin" }
my_ip_cidr           = "169.150.188.81/32"   # fallback if allowed_ssh_cidrs empty
allowed_ssh_cidrs    = ["169.150.188.81/32"] # preferred list-based control
ec2_instance_type    = "t2.micro"
ec2_key_name         = "kevin-dev-key"
db_name              = "appdb"
db_username          = "appuser"
db_password          = null # omit to auto-generate
rds_instance_class   = "db.t3.micro"
rds_engine_version   = "15"
redis_node_type      = "cache.t3.micro"
redis_engine_version = "7.1"
