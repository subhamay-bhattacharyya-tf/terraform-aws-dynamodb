# Terraform Template Specification

Generate these files across two submodule directories: `modules/dynamodb-table/` and `modules/dynamodb-autoscaling/`.

---

## Module 1: `modules/dynamodb-table/`

**main.tf:**

- Single `aws_dynamodb_table` resource created via `for_each` over `var.tables`
- Do NOT use inline auto-scaling configuration — auto-scaling targets and policies are managed in the separate `dynamodb-autoscaling` submodule
- Pass through from each map entry:
  - `name`: from object field
  - `billing_mode`: from object field (default `"PAY_PER_REQUEST"`)
  - `hash_key`: from object field
  - `range_key`: from object field (optional)
  - `read_capacity` / `write_capacity`: from `provisioned_capacity` object (only when `billing_mode = "PROVISIONED"`)
  - `attribute` blocks: dynamic, from `attributes` list
  - `global_secondary_index` blocks: dynamic, from `global_secondary_indexes` map
  - `local_secondary_index` blocks: dynamic, from `local_secondary_indexes` map
  - `ttl` block: dynamic, from `ttl` object
  - `point_in_time_recovery` block: dynamic, from `point_in_time_recovery` object
  - `server_side_encryption` block: dynamic, from `server_side_encryption` object
  - `stream_enabled` and `stream_view_type`: from object fields
  - `replica` blocks: dynamic, from `replicas` list (global tables v2)
  - `deletion_protection_enabled`: from object field
  - `tags`: from object field merged with common tags
- Optional `aws_dynamodb_kinesis_streaming_destination` resource created via `for_each` when `kinesis_stream_arn` is set on a table entry
- Include `lifecycle { ignore_changes = [read_capacity, write_capacity] }` on `aws_dynamodb_table` and on each `global_secondary_index` block to avoid drift when auto-scaling adjusts capacity

**variables.tf:**

- `tables`: `map(object({...}))` with fields:
  - `name` (string, required)
  - `billing_mode` (optional string, default `"PAY_PER_REQUEST"`)
  - `hash_key` (string, required)
  - `range_key` (optional string, default `null`)
  - `attributes` (list of `object({ name = string, type = string })`, required)
  - `provisioned_capacity` (optional `object({ read_capacity = number, write_capacity = number })`, default `null`)
  - `global_secondary_indexes` (optional map of object, default `{}`)
  - `local_secondary_indexes` (optional map of object, default `{}`)
  - `ttl` (optional `object({ attribute_name = string, enabled = bool })`, default `null`)
  - `point_in_time_recovery` (optional `object({ enabled = bool })`, default `null`)
  - `server_side_encryption` (optional `object({ enabled = bool, kms_key_arn = optional(string) })`, default `null`)
  - `stream_enabled` (optional bool, default `false`)
  - `stream_view_type` (optional string, default `null`)
  - `replicas` (optional list of object, default `[]`)
  - `kinesis_stream_arn` (optional string, default `null`)
  - `deletion_protection_enabled` (optional bool, default `false`)
  - `tags` (optional map(string), default `{}`)
- Validations:
  - `name` is non-empty, between 3 and 255 characters, and matches `^[a-zA-Z0-9_.-]+$`
  - `billing_mode` is one of `"PAY_PER_REQUEST"` or `"PROVISIONED"`
  - `provisioned_capacity` is set when `billing_mode = "PROVISIONED"` and `null` otherwise
  - `stream_view_type` is one of `"NEW_IMAGE"`, `"OLD_IMAGE"`, `"NEW_AND_OLD_IMAGES"`, or `"KEYS_ONLY"` when `stream_enabled = true`
  - Each attribute `type` is one of `"S"`, `"N"`, or `"B"`
  - `kms_key_arn` matches `^arn:aws:kms:[a-z0-9-]+:[0-9]{12}:key/[a-f0-9-]+$` when set

**outputs.tf:**

- `table_names`: map of logical key → table name
- `table_arns`: map of logical key → table arn
- `table_ids`: map of logical key → table id
- `table_stream_arns`: map of logical key → stream arn (only for tables with streams enabled)
- `global_secondary_index_names`: map of logical key → list of GSI names
- `replica_regions`: map of logical key → list of replica regions

**versions.tf:**

```hcl
terraform {
  required_version = ">= 1.3.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0.0"
    }
  }
}

provider "aws" {
  region = var.region
}
```

---

## Module 2: `modules/dynamodb-autoscaling/`

**main.tf:**

- Build a derived local for the `resource_id` per autoscaling entry:
  - `scope = "table"` → `"table/${table_name}"`
  - `scope = "index"` → `"table/${table_name}/index/${index_name}"`
- Build a derived local for `scalable_dimension` per autoscaling entry:
  - `scope = "table"` and `capacity_type = "read"` → `"dynamodb:table:ReadCapacityUnits"`
  - `scope = "table"` and `capacity_type = "write"` → `"dynamodb:table:WriteCapacityUnits"`
  - `scope = "index"` and `capacity_type = "read"` → `"dynamodb:index:ReadCapacityUnits"`
  - `scope = "index"` and `capacity_type = "write"` → `"dynamodb:index:WriteCapacityUnits"`
- Create `aws_appautoscaling_target` via `for_each` over `var.autoscaling`
- Create `aws_appautoscaling_policy` via `for_each` over `var.autoscaling`, with `policy_type = "TargetTrackingScaling"`
- Pass through from each map entry:
  - `min_capacity`, `max_capacity`
  - `target_utilization` (in `target_tracking_scaling_policy_configuration.target_value`)
  - `predefined_metric_type` derived from `capacity_type` (`"DynamoDBReadCapacityUtilization"` or `"DynamoDBWriteCapacityUtilization"`)
  - `scale_in_cooldown`, `scale_out_cooldown`
  - `disable_scale_in`
- Set `service_namespace = "dynamodb"` on both target and policy

**variables.tf:**

- `autoscaling`: `map(object({...}))` with fields:
  - `table_name` (string, required)
  - `scope` (string, required — must be `"table"` or `"index"`)
  - `index_name` (optional string, default `null`)
  - `capacity_type` (string, required — must be `"read"` or `"write"`)
  - `min_capacity` (number, required)
  - `max_capacity` (number, required)
  - `target_utilization` (number, required)
  - `scale_in_cooldown` (optional number, default `60`)
  - `scale_out_cooldown` (optional number, default `60`)
  - `disable_scale_in` (optional bool, default `false`)
  - `tags` (optional map(string), default `{}`)
- Validations:
  - `scope` is one of `"table"` or `"index"`
  - `capacity_type` is one of `"read"` or `"write"`
  - `index_name` is non-null when `scope = "index"` and is null when `scope = "table"`
  - `min_capacity >= 1` and `max_capacity >= min_capacity`
  - `target_utilization` is between 1 and 100
  - `scale_in_cooldown` and `scale_out_cooldown` are non-negative

**outputs.tf:**

- `scalable_target_ids`: map of logical key → scalable target resource id
- `scalable_target_resource_ids`: map of logical key → resource_id (e.g., `table/foo` or `table/foo/index/bar`)
- `scaling_policy_arns`: map of logical key → policy arn
- `scaling_policy_names`: map of logical key → policy name

**versions.tf:**

```hcl
terraform {
  required_version = ">= 1.3.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0.0"
    }
  }
}

provider "aws" {
  region = var.region
}
```

---

## `examples/`

- `examples/basic/` — single on-demand DynamoDB table with a hash key, range key, one GSI, and TTL enabled (no auto-scaling, since `PAY_PER_REQUEST` does not require it)
- `examples/provisioned-with-autoscaling/` — provisioned-mode table with a GSI, where the `dynamodb-autoscaling` submodule is consumed to attach read and write auto-scaling on both the table and the GSI (4 scaling targets total)

Each example should be a working, self-contained configuration that references both submodules (or one, in the on-demand case) and passes example values for all variables. Examples are validated separately from the root modules in CI.

---

## `test/`

This folder contains the integration test cases for both submodules. Tests are written in Go using the Terratest framework. They must:

- Provision real DynamoDB tables and auto-scaling resources in AWS
- Assert the outputs of both submodules (table names, ARNs, stream ARNs, scaling policy ARNs)
- Verify that auto-scaling targets are wired to the correct table and GSI resource IDs
- Destroy all resources after the test completes

At minimum, include:

- `dynamodb_table_basic_test.go` — exercises `examples/basic`
- `dynamodb_provisioned_autoscaling_test.go` — exercises `examples/provisioned-with-autoscaling`
- `helpers_test.go` — shared AWS test helpers (region handling, KMS key lookup, tag assertions)

---

## `package.json`

Ensure the `name` field is always set to the repository name (`terraform-aws-dynamodb`).

## `package-lock.json`

Ensure the `name` field is always set to the repository name (`terraform-aws-dynamodb`).

## `CONTRIBUTING.md`

Ensure the **Reporting Issues** section always links to the current repository's issues page.

## `README.md`

The custom endpoint badge should always point to the current repository's `.json` metadata endpoint.
