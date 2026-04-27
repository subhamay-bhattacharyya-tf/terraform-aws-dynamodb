resource "aws_dynamodb_table" "this" {
  for_each = var.tables

  name         = each.value.name
  billing_mode = each.value.billing_mode
  hash_key     = each.value.hash_key
  range_key    = each.value.range_key

  read_capacity  = try(each.value.provisioned_capacity.read_capacity, null)
  write_capacity = try(each.value.provisioned_capacity.write_capacity, null)

  stream_enabled   = each.value.stream_enabled
  stream_view_type = each.value.stream_enabled ? each.value.stream_view_type : null

  deletion_protection_enabled = each.value.deletion_protection_enabled

  tags = each.value.tags

  dynamic "attribute" {
    for_each = each.value.attributes
    content {
      name = attribute.value.name
      type = attribute.value.type
    }
  }

  dynamic "global_secondary_index" {
    for_each = each.value.global_secondary_indexes
    content {
      name               = global_secondary_index.key
      hash_key           = global_secondary_index.value.hash_key
      range_key          = global_secondary_index.value.range_key
      projection_type    = global_secondary_index.value.projection_type
      non_key_attributes = global_secondary_index.value.projection_type == "INCLUDE" ? global_secondary_index.value.non_key_attributes : null
      read_capacity      = global_secondary_index.value.read_capacity
      write_capacity     = global_secondary_index.value.write_capacity
    }
  }

  dynamic "local_secondary_index" {
    for_each = each.value.local_secondary_indexes
    content {
      name               = local_secondary_index.key
      range_key          = local_secondary_index.value.range_key
      projection_type    = local_secondary_index.value.projection_type
      non_key_attributes = local_secondary_index.value.projection_type == "INCLUDE" ? local_secondary_index.value.non_key_attributes : null
    }
  }

  dynamic "ttl" {
    for_each = each.value.ttl != null ? [each.value.ttl] : []
    content {
      attribute_name = ttl.value.attribute_name
      enabled        = ttl.value.enabled
    }
  }

  dynamic "point_in_time_recovery" {
    for_each = each.value.point_in_time_recovery != null ? [each.value.point_in_time_recovery] : []
    content {
      enabled = point_in_time_recovery.value.enabled
    }
  }

  dynamic "server_side_encryption" {
    for_each = each.value.server_side_encryption != null ? [each.value.server_side_encryption] : []
    content {
      enabled     = server_side_encryption.value.enabled
      kms_key_arn = server_side_encryption.value.kms_key_arn
    }
  }

  dynamic "replica" {
    for_each = each.value.replicas
    content {
      region_name            = replica.value.region_name
      kms_key_arn            = replica.value.kms_key_arn
      point_in_time_recovery = replica.value.point_in_time_recovery
      propagate_tags         = replica.value.propagate_tags
    }
  }

  lifecycle {
    ignore_changes = [
      read_capacity,
      write_capacity,
      global_secondary_index,
    ]
  }
}

resource "aws_dynamodb_kinesis_streaming_destination" "this" {
  for_each = {
    for k, v in var.tables : k => v
    if v.kinesis_stream_arn != null
  }

  table_name = aws_dynamodb_table.this[each.key].name
  stream_arn = each.value.kinesis_stream_arn
}
