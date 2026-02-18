output "replication_group_configuration_endpoint_address" {
    description = "Address of the replication group configuration endpoint."
    value       = aws_elasticache_replication_group.cluster.configuration_endpoint_address
}

output "replication_group_region" {
    description = "The region of the replication group."
    value = try(aws_elasticache_replication_group.cluster.region, null)
}

output "replication_group_engine_version_actual" {
    description = "The full version number of the cache engine running on the members of this replication group."
    value       = aws_elasticache_replication_group.cluster.engine_version_actual
}

# output "runtime_user" {
#     description = "The user id for connecting to this replication group."
#     value       = aws_elasticache_user.runtime.id
# }

# output "runtime_user_auth_mode" {
#     description = "The authentication mode configured for runtime user."
#     value       = aws_elasticache_user.runtime.authentication_mode[0].type
# }

output "parameter_group_name" {
    description = "The ElastiCache parameter group name"
    value       = aws_elasticache_parameter_group.cluster_pg.id
}

output "elasticache_replication_group_arn" {
  value = aws_elasticache_replication_group.cluster.arn
}