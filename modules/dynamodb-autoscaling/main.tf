locals {
  scalable_dimension_map = {
    "table-read"  = "dynamodb:table:ReadCapacityUnits"
    "table-write" = "dynamodb:table:WriteCapacityUnits"
    "index-read"  = "dynamodb:index:ReadCapacityUnits"
    "index-write" = "dynamodb:index:WriteCapacityUnits"
  }

  predefined_metric_map = {
    read  = "DynamoDBReadCapacityUtilization"
    write = "DynamoDBWriteCapacityUtilization"
  }

  derived = {
    for k, v in var.autoscaling : k => {
      resource_id            = v.scope == "table" ? "table/${v.table_name}" : "table/${v.table_name}/index/${v.index_name}"
      scalable_dimension     = local.scalable_dimension_map["${v.scope}-${v.capacity_type}"]
      predefined_metric_type = local.predefined_metric_map[v.capacity_type]
    }
  }
}

resource "aws_appautoscaling_target" "this" {
  for_each = var.autoscaling

  service_namespace  = "dynamodb"
  resource_id        = local.derived[each.key].resource_id
  scalable_dimension = local.derived[each.key].scalable_dimension
  min_capacity       = each.value.min_capacity
  max_capacity       = each.value.max_capacity

  tags = each.value.tags
}

resource "aws_appautoscaling_policy" "this" {
  for_each = var.autoscaling

  name               = "${each.key}-target-tracking"
  policy_type        = "TargetTrackingScaling"
  service_namespace  = aws_appautoscaling_target.this[each.key].service_namespace
  resource_id        = aws_appautoscaling_target.this[each.key].resource_id
  scalable_dimension = aws_appautoscaling_target.this[each.key].scalable_dimension

  target_tracking_scaling_policy_configuration {
    target_value       = each.value.target_utilization
    scale_in_cooldown  = each.value.scale_in_cooldown
    scale_out_cooldown = each.value.scale_out_cooldown
    disable_scale_in   = each.value.disable_scale_in

    predefined_metric_specification {
      predefined_metric_type = local.derived[each.key].predefined_metric_type
    }
  }
}
