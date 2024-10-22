output "tags" {
  value       = aws_vpc.vpc.tags
  description = "Outputs the tags associated with the main VPC"
}

output "cidr" {
  value       = aws_vpc.vpc.cidr_block
  description = "The CIDR block assigned to the main VPC"
}
