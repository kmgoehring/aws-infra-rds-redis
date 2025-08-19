output "app_instance_public_ip" {
  value       = aws_instance.app.public_ip
  description = "Public IP of the app host"
}

output "ssh_command" {
  value       = "ssh -i <your-key.pem> ec2-user@${aws_instance.app.public_ip}"
  description = "Convenience SSH command (replace with your actual key)"
}

output "rds_endpoint" {
  value       = aws_db_instance.postgres.address
  description = "RDS writer endpoint"
}

output "redis_primary_endpoint" {
  value       = aws_elasticache_replication_group.redis.primary_endpoint_address
  description = "Redis primary endpoint"
}

# (Sensitive) expose DB password only for development/demo convenience.
# Consider storing it in AWS Secrets Manager/SSM instead of outputting.
output "db_password" {
  value       = local.db_password
  sensitive   = true
  description = "DB master password (sensitive)."
}
