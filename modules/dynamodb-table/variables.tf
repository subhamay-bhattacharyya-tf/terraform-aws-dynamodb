variable "region" {
  description = "AWS region in which DynamoDB tables are created."
  type        = string
}

variable "tables" {
  description = <<-EOT
    Map of DynamoDB tables to create. The map key is a logical Terraform identifier
    used inside this module; the actual AWS table name comes from the `name` field.
  EOT

  type = map(object({
    name         = string
    billing_mode = optional(string, "PAY_PER_REQUEST")
    hash_key     = string
    range_key    = optional(string)

    attributes = list(object({
      name = string
      type = string
    }))

    provisioned_capacity = optional(object({
      read_capacity  = number
      write_capacity = number
    }))

    global_secondary_indexes = optional(map(object({
      hash_key           = string
      range_key          = optional(string)
      projection_type    = string
      non_key_attributes = optional(list(string), [])
      read_capacity      = optional(number)
      write_capacity     = optional(number)
    })), {})

    local_secondary_indexes = optional(map(object({
      range_key          = string
      projection_type    = string
      non_key_attributes = optional(list(string), [])
    })), {})

    ttl = optional(object({
      attribute_name = string
      enabled        = bool
    }))

    point_in_time_recovery = optional(object({
      enabled = bool
    }))

    server_side_encryption = optional(object({
      enabled     = bool
      kms_key_arn = optional(string)
    }))

    stream_enabled   = optional(bool, false)
    stream_view_type = optional(string)

    replicas = optional(list(object({
      region_name            = string
      kms_key_arn            = optional(string)
      point_in_time_recovery = optional(bool, false)
      propagate_tags         = optional(bool, true)
    })), [])

    kinesis_stream_arn          = optional(string)
    deletion_protection_enabled = optional(bool, false)
    tags                        = optional(map(string), {})
  }))

  validation {
    condition = alltrue([
      for k, v in var.tables :
      length(v.name) >= 3 && length(v.name) <= 255 && can(regex("^[a-zA-Z0-9_.-]+$", v.name))
    ])
    error_message = "Each table 'name' must be 3-255 characters and match ^[a-zA-Z0-9_.-]+$."
  }

  validation {
    condition = alltrue([
      for k, v in var.tables :
      contains(["PAY_PER_REQUEST", "PROVISIONED"], v.billing_mode)
    ])
    error_message = "Each table 'billing_mode' must be one of PAY_PER_REQUEST or PROVISIONED."
  }

  validation {
    condition = alltrue([
      for k, v in var.tables :
      (v.billing_mode == "PROVISIONED" && v.provisioned_capacity != null) ||
      (v.billing_mode == "PAY_PER_REQUEST" && v.provisioned_capacity == null)
    ])
    error_message = "'provisioned_capacity' must be set when billing_mode = PROVISIONED, and must be null when billing_mode = PAY_PER_REQUEST."
  }

  validation {
    condition = alltrue([
      for k, v in var.tables :
      !v.stream_enabled || (
        v.stream_view_type != null &&
        contains(["NEW_IMAGE", "OLD_IMAGE", "NEW_AND_OLD_IMAGES", "KEYS_ONLY"], coalesce(v.stream_view_type, "NEW_IMAGE"))
      )
    ])
    error_message = "When stream_enabled = true, 'stream_view_type' must be one of NEW_IMAGE, OLD_IMAGE, NEW_AND_OLD_IMAGES, KEYS_ONLY."
  }

  validation {
    condition = alltrue(flatten([
      for k, v in var.tables : [
        for a in v.attributes : contains(["S", "N", "B"], a.type)
      ]
    ]))
    error_message = "Each attribute 'type' must be one of S, N, or B."
  }

  validation {
    condition = alltrue([
      for k, v in var.tables :
      v.server_side_encryption == null ||
      v.server_side_encryption.kms_key_arn == null ||
      can(regex("^arn:aws:kms:[a-z0-9-]+:[0-9]{12}:key/[a-f0-9-]+$", v.server_side_encryption.kms_key_arn))
    ])
    error_message = "'server_side_encryption.kms_key_arn' must match ^arn:aws:kms:[a-z0-9-]+:[0-9]{12}:key/[a-f0-9-]+$ when set."
  }
}
