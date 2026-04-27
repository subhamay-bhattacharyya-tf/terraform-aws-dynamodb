output "scalable_target_ids" {
  description = "Map of autoscaling key to the Terraform resource id of the aws_appautoscaling_target."
  value       = { for k, t in aws_appautoscaling_target.this : k => t.id }
}

output "scalable_target_resource_ids" {
  description = "Map of autoscaling key to the AWS resource_id string (e.g., 'table/foo' or 'table/foo/index/bar')."
  value       = { for k, t in aws_appautoscaling_target.this : k => t.resource_id }
}

output "scaling_policy_arns" {
  description = "Map of autoscaling key to the ARN of the aws_appautoscaling_policy."
  value       = { for k, p in aws_appautoscaling_policy.this : k => p.arn }
}

output "scaling_policy_names" {
  description = "Map of autoscaling key to the name of the aws_appautoscaling_policy."
  value       = { for k, p in aws_appautoscaling_policy.this : k => p.name }
}
