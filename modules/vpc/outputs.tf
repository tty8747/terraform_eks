output "cidr" {
  value       = aws_vpc.vpc.cidr_block
  description = "The CIDR block assigned to the main VPC"
}

output "pub_subnets" {
  value = aws_subnet.public
}

output "priv_subnets" {
  value = aws_subnet.private
}

output "id" {
  value = aws_vpc.vpc.id
}

output "default_security_group_id" {
  value = aws_vpc.vpc.default_security_group_id
}
