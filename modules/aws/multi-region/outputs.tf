output "primary_vpc_id" {
  value = module.networking_primary.vpc_id
}

output "primary_private_subnet_ids" {
  value = module.networking_primary.private_subnet_ids
}

output "primary_public_subnet_ids" {
  value = module.networking_primary.public_subnet_ids
}

output "dr_vpc_id" {
  value = module.networking_dr.vpc_id
}

output "dr_private_subnet_ids" {
  value = module.networking_dr.private_subnet_ids
}

output "dr_public_subnet_ids" {
  value = module.networking_dr.public_subnet_ids
}

output "vpc_peering_connection_id" {
  value = aws_vpc_peering_connection.primary_to_dr.id
}
