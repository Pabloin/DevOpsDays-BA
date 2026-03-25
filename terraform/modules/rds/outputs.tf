output "db_endpoint" {
  description = "Hostname of the RDS instance endpoint"
  value       = aws_db_instance.main.address
}

output "db_port" {
  description = "Port of the RDS instance"
  value       = aws_db_instance.main.port
}

output "db_security_group_id" {
  description = "ID of the RDS security group"
  value       = aws_security_group.rds.id
}
