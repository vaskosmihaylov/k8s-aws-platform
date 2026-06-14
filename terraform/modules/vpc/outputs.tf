output "vpc_id" {
  description = "ID of the VPC."
  value       = module.vpc.vpc_id
}

output "vpc_cidr_block" {
  description = "Primary CIDR block of the VPC."
  value       = module.vpc.vpc_cidr_block
}

output "public_subnet_ids" {
  description = "IDs of the public subnets."
  value       = module.vpc.public_subnets
}

output "private_subnet_ids" {
  description = "IDs of the private subnets (EKS nodes)."
  value       = module.vpc.private_subnets
}

output "database_subnet_ids" {
  description = "IDs of the isolated database subnets."
  value       = module.vpc.database_subnets
}

output "database_subnet_group_name" {
  description = "Name of the DB subnet group created by the VPC module."
  value       = module.vpc.database_subnet_group_name
}

output "private_subnets_cidr_blocks" {
  description = "CIDR blocks of the private subnets."
  value       = module.vpc.private_subnets_cidr_blocks
}
