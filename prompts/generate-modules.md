# Prompt: Generate `terraform-aws-dynamodb` Modules

You are working in the `terraform-aws-dynamodb` repository. Generate a complete, production-ready Terraform module that provisions AWS DynamoDB tables and their auto-scaling targets and policies as two independent submodules.

## Context

- **Repository name:** `terraform-aws-dynamodb`
- **Provider:** AWS (`hashicorp/aws` >= 5.0.0)
- **Terraform:** >= 1.3.0
- **Design principle:** Split DynamoDB tables and auto-scaling configuration into separate submodules to avoid drift between Terraform-managed capacity values and Application Auto Scaling adjustments, and to allow scaling targets to be added, removed, or retuned independently of the table lifecycle.

## Scope

Generate the following two submodules. Do **not** create a root-level `main.tf` — this repository is a collection of submodules consumed via `source = ".../modules/<name>"`.

### Submodule 1: `modules/dynamodb-table/`

Create these files:

**`main.tf`**

- Single `aws_dynamodb_table` resource, created via `for_each = var.tables`
- **No inline auto-scaling configuration** — auto-scaling is handled by the other submodule
- Fields from each map entry: `name`, `billing_mode` (default `"PAY_PER_REQUEST"`), `hash_key`, `range_key`, `read_capacity` / `write_capacity` (from `provisioned_capacity`, only when `billing_mode = "PROVISIONED"`), `stream_enabled`, `stream_view_type`, `deletion_protection_enabled`, `tags`
- Dynamic blocks for `attribute`, `global_secondary_index`, `local_secondary_index`, `ttl`, `point_in_time_recovery`, `server_side_encryption`, `replica` (global tables v2)
- Optional `aws_dynamodb_kinesis_streaming_destination` resource via `for_each` over tables where `kinesis_stream_arn` is set
- Include `lifecycle { ignore_changes = [read_capacity, write_capacity, global_secondary_index] }` to prevent drift when Application Auto Scaling adjusts capacity values

**`variables.tf`**

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
- `region` (string, required)
- Validations:
  - `name` is non-empty, between 3 and 255 chars, and matches `^[a-zA-Z0-9_.-]+$`
  - `billing_mode` ∈ {`PAY_PER_REQUEST`, `PROVISIONED`}
  - `provisioned_capacity` is non-null when `billing_mode = "PROVISIONED"` and null otherwise
  - `stream_view_type` ∈ {`NEW_IMAGE`, `OLD_IMAGE`, `NEW_AND_OLD_IMAGES`, `KEYS_ONLY`} when `stream_enabled = true`
  - Each attribute `type` ∈ {`S`, `N`, `B`}
  - `kms_key_arn` matches `^arn:aws:kms:[a-z0-9-]+:[0-9]{12}:key/[a-f0-9-]+$` when set

**`outputs.tf`**

- `table_names` — map of key → table name
- `table_arns` — map of key → table arn
- `table_ids` — map of key → table id
- `table_stream_arns` — map of key → stream arn (only for tables with streams enabled)
- `global_secondary_index_names` — map of key → list of GSI names

**`versions.tf`**

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

### Submodule 2: `modules/dynamodb-autoscaling/`

Create these files:

**`main.tf`**

- Two derived locals per autoscaling entry:
  - `resource_id`:
    - `scope = "table"` → `"table/${table_name}"`
    - `scope = "index"` → `"table/${table_name}/index/${index_name}"`
  - `scalable_dimension` from `(scope, capacity_type)`:
    - (`table`, `read`) → `"dynamodb:table:ReadCapacityUnits"`
    - (`table`, `write`) → `"dynamodb:table:WriteCapacityUnits"`
    - (`index`, `read`) → `"dynamodb:index:ReadCapacityUnits"`
    - (`index`, `write`) → `"dynamodb:index:WriteCapacityUnits"`
- `aws_appautoscaling_target` via `for_each = var.autoscaling`, with `service_namespace = "dynamodb"`
- `aws_appautoscaling_policy` via `for_each = var.autoscaling`, with `policy_type = "TargetTrackingScaling"` and `service_namespace = "dynamodb"`
- Pass through: `min_capacity`, `max_capacity`, `target_utilization` (as `target_value` in `target_tracking_scaling_policy_configuration`), `predefined_metric_type` derived from `capacity_type` (`"DynamoDBReadCapacityUtilization"` or `"DynamoDBWriteCapacityUtilization"`), `scale_in_cooldown`, `scale_out_cooldown`, `disable_scale_in`

**`variables.tf`**

- `autoscaling`: `map(object({...}))` with fields:
  - `table_name` (string, required)
  - `scope` (string, required — `"table"` or `"index"`)
  - `index_name` (optional string, default `null`)
  - `capacity_type` (string, required — `"read"` or `"write"`)
  - `min_capacity` (number, required)
  - `max_capacity` (number, required)
  - `target_utilization` (number, required)
  - `scale_in_cooldown` (optional number, default `60`)
  - `scale_out_cooldown` (optional number, default `60`)
  - `disable_scale_in` (optional bool, default `false`)
  - `tags` (optional map(string), default `{}`)
- `region` (string, required)
- Validations:
  - `scope` ∈ {`table`, `index`}
  - `capacity_type` ∈ {`read`, `write`}
  - `index_name` is non-null when `scope = "index"` and is null when `scope = "table"`
  - `min_capacity >= 1`
  - `max_capacity >= min_capacity`
  - `target_utilization` ∈ [1, 100]
  - `scale_in_cooldown >= 0` and `scale_out_cooldown >= 0`

**`outputs.tf`**

- `scalable_target_ids` — map of key → scalable target resource id
- `scalable_target_resource_ids` — map of key → resource_id string (e.g., `table/foo` or `table/foo/index/bar`)
- `scaling_policy_arns` — map of key → policy arn
- `scaling_policy_names` — map of key → policy name

**`versions.tf`** — same block as Submodule 1.

---

## Examples

Also generate:

### `examples/basic/`

- Consumes only the `dynamodb-table` submodule
- Creates one on-demand (`PAY_PER_REQUEST`) DynamoDB table with a hash key, range key, one GSI, and TTL enabled
- No auto-scaling — on-demand tables don't need it
- Self-contained, validatable with `terraform init -backend=false && terraform validate`

### `examples/provisioned-with-autoscaling/`

- Consumes both submodules
- Creates one provisioned-mode DynamoDB table with one GSI
- Wires up four `aws_appautoscaling_target` + policy pairs via the `dynamodb-autoscaling` submodule:
  - Table read capacity
  - Table write capacity
  - GSI read capacity
  - GSI write capacity
- Demonstrates the split-module pattern solving the auto-scaling drift case

---

## Coding standards

- Use `map(object({...}))` with `optional(...)` for defaults — do not use flat variables.
- The map key is a logical Terraform identifier only; the real AWS resource name must come from a `name` field inside the object (or `table_name` for autoscaling entries).
- All validations belong in `variables.tf` via `validation` blocks — do not push validation into `main.tf`.
- Run `terraform fmt -recursive` on the output.
- Every resource must carry `tags` merged from the per-entry `tags` field.
- No hardcoded regions, account IDs, table names, KMS key ARNs, or stream ARNs anywhere in the submodules.

## Deliverables checklist

- [ ] `modules/dynamodb-table/` with `main.tf`, `variables.tf`, `outputs.tf`, `versions.tf`
- [ ] `modules/dynamodb-autoscaling/` with `main.tf`, `variables.tf`, `outputs.tf`, `versions.tf`
- [ ] `examples/basic/` — working end-to-end config (table-only, on-demand)
- [ ] `examples/provisioned-with-autoscaling/` — working end-to-end config with table + auto-scaling composed
- [ ] All files pass `terraform fmt -check -recursive` and `terraform validate`
- [ ] Summary output listing every file created and every AWS resource type provisioned
