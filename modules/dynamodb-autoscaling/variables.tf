variable "region" {
  description = "AWS region in which Application Auto Scaling targets and policies are created."
  type        = string
}

variable "autoscaling" {
  description = <<-EOT
    Map of DynamoDB Application Auto Scaling configurations. Each entry creates one
    aws_appautoscaling_target and one aws_appautoscaling_policy (TargetTrackingScaling).
    The map key is a logical Terraform identifier; the AWS resource ID is derived from
    table_name, scope, and (when scope = "index") index_name.
  EOT

  type = map(object({
    table_name         = string
    scope              = string
    index_name         = optional(string)
    capacity_type      = string
    min_capacity       = number
    max_capacity       = number
    target_utilization = number
    scale_in_cooldown  = optional(number, 60)
    scale_out_cooldown = optional(number, 60)
    disable_scale_in   = optional(bool, false)
    tags               = optional(map(string), {})
  }))

  validation {
    condition = alltrue([
      for k, v in var.autoscaling : contains(["table", "index"], v.scope)
    ])
    error_message = "'scope' must be one of 'table' or 'index'."
  }

  validation {
    condition = alltrue([
      for k, v in var.autoscaling : contains(["read", "write"], v.capacity_type)
    ])
    error_message = "'capacity_type' must be one of 'read' or 'write'."
  }

  validation {
    condition = alltrue([
      for k, v in var.autoscaling :
      (v.scope == "index" && v.index_name != null) ||
      (v.scope == "table" && v.index_name == null)
    ])
    error_message = "'index_name' must be set when scope = 'index' and must be null when scope = 'table'."
  }

  validation {
    condition     = alltrue([for k, v in var.autoscaling : v.min_capacity >= 1])
    error_message = "'min_capacity' must be at least 1."
  }

  validation {
    condition     = alltrue([for k, v in var.autoscaling : v.max_capacity >= v.min_capacity])
    error_message = "'max_capacity' must be greater than or equal to 'min_capacity'."
  }

  validation {
    condition = alltrue([
      for k, v in var.autoscaling : v.target_utilization >= 1 && v.target_utilization <= 100
    ])
    error_message = "'target_utilization' must be between 1 and 100."
  }

  validation {
    condition = alltrue([
      for k, v in var.autoscaling : v.scale_in_cooldown >= 0 && v.scale_out_cooldown >= 0
    ])
    error_message = "'scale_in_cooldown' and 'scale_out_cooldown' must be non-negative."
  }
}
