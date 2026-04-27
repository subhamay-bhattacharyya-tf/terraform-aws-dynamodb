output "table_names" {
  description = "Map of table key to DynamoDB table name."
  value       = { for k, t in aws_dynamodb_table.this : k => t.name }
}

output "table_arns" {
  description = "Map of table key to DynamoDB table ARN."
  value       = { for k, t in aws_dynamodb_table.this : k => t.arn }
}

output "table_ids" {
  description = "Map of table key to DynamoDB table id."
  value       = { for k, t in aws_dynamodb_table.this : k => t.id }
}

output "table_stream_arns" {
  description = "Map of table key to DynamoDB stream ARN. Only includes tables with streams enabled."
  value = {
    for k, t in aws_dynamodb_table.this : k => t.stream_arn
    if var.tables[k].stream_enabled
  }
}

output "global_secondary_index_names" {
  description = "Map of table key to the list of GSI names declared on that table."
  value = {
    for k, v in var.tables : k => keys(v.global_secondary_indexes)
  }
}
