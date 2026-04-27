output "table_names" {
  description = "Map of logical keys to DynamoDB table names."
  value       = module.dynamodb_table.table_names
}

output "table_arns" {
  description = "Map of logical keys to DynamoDB table ARNs."
  value       = module.dynamodb_table.table_arns
}

output "scalable_target_resource_ids" {
  description = "Map of autoscaling keys to AWS resource_id strings (table/... or table/.../index/...)."
  value       = module.dynamodb_autoscaling.scalable_target_resource_ids
}

output "scaling_policy_arns" {
  description = "Map of autoscaling keys to scaling policy ARNs."
  value       = module.dynamodb_autoscaling.scaling_policy_arns
}
