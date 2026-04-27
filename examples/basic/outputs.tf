output "table_names" {
  description = "Map of logical keys to DynamoDB table names."
  value       = module.dynamodb_table.table_names
}

output "table_arns" {
  description = "Map of logical keys to DynamoDB table ARNs."
  value       = module.dynamodb_table.table_arns
}

output "global_secondary_index_names" {
  description = "Map of logical keys to GSI name lists."
  value       = module.dynamodb_table.global_secondary_index_names
}
