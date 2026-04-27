# Terraform AWS DynamoDB Module

![Release](https://github.com/subhamay-bhattacharyya-tf/terraform-aws-dynamodb/actions/workflows/ci.yaml/badge.svg)&nbsp;![AWS](https://img.shields.io/badge/AWS-232F3E?logo=amazonaws&logoColor=white)&nbsp;![Commit Activity](https://img.shields.io/github/commit-activity/t/subhamay-bhattacharyya-tf/terraform-aws-dynamodb)&nbsp;![Last Commit](https://img.shields.io/github/last-commit/subhamay-bhattacharyya-tf/terraform-aws-dynamodb)&nbsp;![Release Date](https://img.shields.io/github/release-date/subhamay-bhattacharyya-tf/terraform-aws-dynamodb)&nbsp;![Repo Size](https://img.shields.io/github/repo-size/subhamay-bhattacharyya-tf/terraform-aws-dynamodb)&nbsp;![File Count](https://img.shields.io/github/directory-file-count/subhamay-bhattacharyya-tf/terraform-aws-dynamodb)&nbsp;![Issues](https://img.shields.io/github/issues/subhamay-bhattacharyya-tf/terraform-aws-dynamodb)&nbsp;![Top Language](https://img.shields.io/github/languages/top/subhamay-bhattacharyya-tf/terraform-aws-dynamodb)&nbsp;![Custom Endpoint](https://img.shields.io/endpoint?url=https://gist.githubusercontent.com/bsubhamay/6cc1ccf9f06e25c9289d339ac7513731/raw/terraform-aws-dynamodb.json?)

A Terraform module for creating and managing AWS DynamoDB tables and their Application Auto Scaling configuration as two independent submodules. The split-module design prevents drift between Terraform-managed capacity values and Application Auto Scaling adjustments, and lets scaling targets be added, removed, or retuned independently of the table lifecycle.

## Features

- Split-module design — table resources and auto-scaling targets/policies are independent
- Single `map(object({...}))` input per submodule, consumed via `for_each`
- No inline auto-scaling on the table — `read_capacity` / `write_capacity` / `global_secondary_index` are in `lifecycle.ignore_changes` to absorb runtime adjustments
- Supports on-demand and provisioned tables, GSIs/LSIs, TTL, PITR, KMS encryption, DynamoDB Streams, Kinesis streaming destination, and global tables (v2 replicas)
- Auto-scaling submodule covers both table-level and per-GSI scaling for read and write capacity
- Built-in input validation (name format, billing mode, capacity coherence, stream view type, attribute types, KMS ARN format, scope/capacity ranges)

## Modules

| Module                                               | Description                                                                           |
| ---------------------------------------------------- | ------------------------------------------------------------------------------------- |
| [dynamodb-table](modules/dynamodb-table)             | Creates `aws_dynamodb_table` resources (no inline auto-scaling)                       |
| [dynamodb-autoscaling](modules/dynamodb-autoscaling) | Creates `aws_appautoscaling_target` and `aws_appautoscaling_policy` (target tracking) |

## Usage

### On-demand table with a GSI and TTL

```hcl
module "dynamodb_table" {
  source = "github.com/subhamay-bhattacharyya-tf/terraform-aws-dynamodb/modules/dynamodb-table?ref=main"

  region = "us-east-1"

  tables = {
    orders = {
      name      = "orders"
      hash_key  = "OrderId"
      range_key = "CreatedAt"

      attributes = [
        { name = "OrderId", type = "S" },
        { name = "CreatedAt", type = "S" },
        { name = "CustomerId", type = "S" },
      ]

      global_secondary_indexes = {
        "by-customer" = {
          hash_key        = "CustomerId"
          range_key       = "CreatedAt"
          projection_type = "ALL"
        }
      }

      ttl = {
        attribute_name = "ExpiresAt"
        enabled        = true
      }

      point_in_time_recovery = {
        enabled = true
      }

      tags = {
        Environment = "dev"
      }
    }
  }
}
```

### Provisioned table with auto-scaling on the table and a GSI

```hcl
module "dynamodb_table" {
  source = "github.com/subhamay-bhattacharyya-tf/terraform-aws-dynamodb/modules/dynamodb-table?ref=main"

  region = "us-east-1"

  tables = {
    events = {
      name         = "events"
      billing_mode = "PROVISIONED"
      hash_key     = "EventId"

      provisioned_capacity = {
        read_capacity  = 5
        write_capacity = 5
      }

      attributes = [
        { name = "EventId", type = "S" },
        { name = "Source", type = "S" },
      ]

      global_secondary_indexes = {
        "by-source" = {
          hash_key        = "Source"
          projection_type = "ALL"
          read_capacity   = 5
          write_capacity  = 5
        }
      }
    }
  }
}

module "dynamodb_autoscaling" {
  source = "github.com/subhamay-bhattacharyya-tf/terraform-aws-dynamodb/modules/dynamodb-autoscaling?ref=main"

  region = "us-east-1"

  autoscaling = {
    "events-table-read" = {
      table_name         = module.dynamodb_table.table_names["events"]
      scope              = "table"
      capacity_type      = "read"
      min_capacity       = 5
      max_capacity       = 100
      target_utilization = 70
    }
    "events-table-write" = {
      table_name         = module.dynamodb_table.table_names["events"]
      scope              = "table"
      capacity_type      = "write"
      min_capacity       = 5
      max_capacity       = 100
      target_utilization = 70
    }
    "events-gsi-read" = {
      table_name         = module.dynamodb_table.table_names["events"]
      scope              = "index"
      index_name         = "by-source"
      capacity_type      = "read"
      min_capacity       = 5
      max_capacity       = 100
      target_utilization = 70
    }
    "events-gsi-write" = {
      table_name         = module.dynamodb_table.table_names["events"]
      scope              = "index"
      index_name         = "by-source"
      capacity_type      = "write"
      min_capacity       = 5
      max_capacity       = 100
      target_utilization = 70
    }
  }
}
```

### Table with DynamoDB Streams and a Kinesis streaming destination

```hcl
module "dynamodb_table" {
  source = "github.com/subhamay-bhattacharyya-tf/terraform-aws-dynamodb/modules/dynamodb-table?ref=main"

  region = "us-east-1"

  tables = {
    audit = {
      name     = "audit"
      hash_key = "AuditId"

      attributes = [
        { name = "AuditId", type = "S" },
      ]

      stream_enabled     = true
      stream_view_type   = "NEW_AND_OLD_IMAGES"
      kinesis_stream_arn = "arn:aws:kinesis:us-east-1:123456789012:stream/audit-events"
    }
  }
}
```

### Global table with cross-region replicas

```hcl
module "dynamodb_table" {
  source = "github.com/subhamay-bhattacharyya-tf/terraform-aws-dynamodb/modules/dynamodb-table?ref=main"

  region = "us-east-1"

  tables = {
    sessions = {
      name             = "sessions"
      hash_key         = "SessionId"
      stream_enabled   = true
      stream_view_type = "NEW_AND_OLD_IMAGES"

      attributes = [
        { name = "SessionId", type = "S" },
      ]

      replicas = [
        { region_name = "us-west-2" },
        { region_name = "eu-west-1" },
      ]
    }
  }
}
```

## Examples

| Example                                                               | Description                                                                                   |
| --------------------------------------------------------------------- | --------------------------------------------------------------------------------------------- |
| [basic](examples/basic)                                               | Single on-demand DynamoDB table with a GSI, TTL, and PITR                                     |
| [provisioned-with-autoscaling](examples/provisioned-with-autoscaling) | Provisioned table with one GSI, plus four scaling targets (table read/write + GSI read/write) |

## Requirements

| Name      | Version  |
| --------- | -------- |
| terraform | >= 1.3.0 |
| aws       | >= 5.0.0 |

## Providers

| Name | Version  |
| ---- | -------- |
| aws  | >= 5.0.0 |

## `dynamodb-table` submodule

### `dynamodb-table` inputs

| Name   | Description                                         | Type        | Default | Required |
| ------ | --------------------------------------------------- | ----------- | ------- | -------- |
| region | AWS region in which DynamoDB tables are created     | string      | -       | yes      |
| tables | Map of DynamoDB tables to create (key = logical id) | map(object) | -       | yes      |

#### `tables` object properties

| Property                    | Type                                      | Default             | Description                                                                                               |
| --------------------------- | ----------------------------------------- | ------------------- | --------------------------------------------------------------------------------------------------------- |
| name                        | string                                    | -                   | AWS table name (3–255 chars, `^[a-zA-Z0-9_.-]+$`, required)                                               |
| billing_mode                | string                                    | `"PAY_PER_REQUEST"` | One of `PAY_PER_REQUEST`, `PROVISIONED`                                                                   |
| hash_key                    | string                                    | -                   | Partition key name (required)                                                                             |
| range_key                   | string                                    | `null`              | Sort key name                                                                                             |
| attributes                  | list(object({ name, type }))              | -                   | Attribute definitions; each `type` must be `S`, `N`, or `B` (required)                                    |
| provisioned_capacity        | object({ read_capacity, write_capacity }) | `null`              | Required when `billing_mode = "PROVISIONED"`; must be null otherwise                                      |
| global_secondary_indexes    | map(object)                               | `{}`                | GSI definitions keyed by GSI name                                                                         |
| local_secondary_indexes     | map(object)                               | `{}`                | LSI definitions keyed by LSI name                                                                         |
| ttl                         | object({ attribute_name, enabled })       | `null`              | Time-to-live configuration                                                                                |
| point_in_time_recovery      | object({ enabled })                       | `null`              | PITR configuration                                                                                        |
| server_side_encryption      | object({ enabled, kms_key_arn })          | `null`              | SSE configuration; `kms_key_arn` (when set) must match `^arn:aws:kms:...:key/...$`                        |
| stream_enabled              | bool                                      | `false`             | Enable DynamoDB Streams                                                                                   |
| stream_view_type            | string                                    | `null`              | Required when `stream_enabled = true`; one of `NEW_IMAGE`, `OLD_IMAGE`, `NEW_AND_OLD_IMAGES`, `KEYS_ONLY` |
| replicas                    | list(object)                              | `[]`                | Global-tables-v2 replica definitions                                                                      |
| kinesis_stream_arn          | string                                    | `null`              | When set, creates `aws_dynamodb_kinesis_streaming_destination` for the table                              |
| deletion_protection_enabled | bool                                      | `false`             | Enable deletion protection                                                                                |
| tags                        | map(string)                               | `{}`                | Tags applied to the table                                                                                 |

### `dynamodb-table` outputs

| Name                         | Description                                                            |
| ---------------------------- | ---------------------------------------------------------------------- |
| table_names                  | Map of table key to DynamoDB table name                                |
| table_arns                   | Map of table key to DynamoDB table ARN                                 |
| table_ids                    | Map of table key to DynamoDB table id                                  |
| table_stream_arns            | Map of table key to DynamoDB stream ARN (only for tables with streams) |
| global_secondary_index_names | Map of table key to the list of GSI names declared on that table       |

## `dynamodb-autoscaling` submodule

### `dynamodb-autoscaling` inputs

| Name        | Description                                                       | Type        | Default | Required |
| ----------- | ----------------------------------------------------------------- | ----------- | ------- | -------- |
| region      | AWS region in which scaling targets and policies are created      | string      | -       | yes      |
| autoscaling | Map of Application Auto Scaling configurations (key = logical id) | map(object) | -       | yes      |

#### `autoscaling` object properties

| Property           | Type        | Default | Description                                                          |
| ------------------ | ----------- | ------- | -------------------------------------------------------------------- |
| table_name         | string      | -       | Name of the target DynamoDB table (required)                         |
| scope              | string      | -       | One of `table` or `index` (required)                                 |
| index_name         | string      | `null`  | Required when `scope = "index"`; must be null when `scope = "table"` |
| capacity_type      | string      | -       | One of `read` or `write` (required)                                  |
| min_capacity       | number      | -       | Minimum capacity units; must be >= 1 (required)                      |
| max_capacity       | number      | -       | Maximum capacity units; must be >= `min_capacity` (required)         |
| target_utilization | number      | -       | Target tracking utilization percentage in `[1, 100]` (required)      |
| scale_in_cooldown  | number      | `60`    | Scale-in cooldown in seconds; must be >= 0                           |
| scale_out_cooldown | number      | `60`    | Scale-out cooldown in seconds; must be >= 0                          |
| disable_scale_in   | bool        | `false` | Disable scale-in on the target tracking policy                       |
| tags               | map(string) | `{}`    | Tags applied to the scalable target                                  |

### `dynamodb-autoscaling` outputs

| Name                         | Description                                                                                   |
| ---------------------------- | --------------------------------------------------------------------------------------------- |
| scalable_target_ids          | Map of autoscaling key to the Terraform resource id of the `aws_appautoscaling_target`        |
| scalable_target_resource_ids | Map of autoscaling key to the AWS `resource_id` string (`table/foo` or `table/foo/index/bar`) |
| scaling_policy_arns          | Map of autoscaling key to the ARN of the `aws_appautoscaling_policy`                          |
| scaling_policy_names         | Map of autoscaling key to the name of the `aws_appautoscaling_policy`                         |

## Resources Created

### `dynamodb-table` resources

| Resource                                   | Description                                                             |
| ------------------------------------------ | ----------------------------------------------------------------------- |
| aws_dynamodb_table                         | DynamoDB table (one per map entry, no inline auto-scaling)              |
| aws_dynamodb_kinesis_streaming_destination | Kinesis streaming destination (one per table with `kinesis_stream_arn`) |

### `dynamodb-autoscaling` resources

| Resource                  | Description                                                               |
| ------------------------- | ------------------------------------------------------------------------- |
| aws_appautoscaling_target | Scalable target on the table or GSI (one per map entry)                   |
| aws_appautoscaling_policy | Target-tracking scaling policy attached to the target (one per map entry) |

## Validation

All validation lives in each submodule's `variables.tf`:

- `tables[*].name` is 3–255 characters and matches `^[a-zA-Z0-9_.-]+$`
- `tables[*].billing_mode` is one of `PAY_PER_REQUEST`, `PROVISIONED`
- `tables[*].provisioned_capacity` is non-null when `billing_mode = "PROVISIONED"` and null otherwise
- `tables[*].stream_view_type` is set and one of `NEW_IMAGE`, `OLD_IMAGE`, `NEW_AND_OLD_IMAGES`, `KEYS_ONLY` when `stream_enabled = true`
- Each attribute `type` is one of `S`, `N`, `B`
- `tables[*].server_side_encryption.kms_key_arn` matches `^arn:aws:kms:[a-z0-9-]+:[0-9]{12}:key/[a-f0-9-]+$` when set
- `autoscaling[*].scope` is one of `table`, `index`; `capacity_type` is one of `read`, `write`
- `autoscaling[*].index_name` is non-null when `scope = "index"` and null when `scope = "table"`
- `autoscaling[*].min_capacity >= 1`, `max_capacity >= min_capacity`, `target_utilization` in `[1, 100]`, cooldowns >= 0

## Testing

The module includes a Terratest-based integration test that creates a real DynamoDB table plus auto-scaling targets/policies, asserts the outputs, and then destroys them:

```bash
cd test
go mod tidy
go test -v -timeout 30m -run TestDynamoDBTableBasic ./dynamodb_table_basic_test.go ./helpers_test.go
```

AWS credentials must be configured via environment variables, AWS CLI profile, or (in CI) OIDC. `AWS_REGION` and `AWS_KMS_KEY_ARN` are required.

## CI/CD Configuration

The CI workflow (`.github/workflows/ci.yaml`) runs on:

- Push to `main`, `feature/**`, and `bug/**` branches (when `modules/**`, `examples/**`, or `test/**` change)
- Pull requests to `main` (same path filter)
- Manual workflow dispatch

Jobs:

1. **terraform-validate** — `fmt -check`, `init`, `validate` on both submodules (`modules/dynamodb-table`, `modules/dynamodb-autoscaling`)
2. **examples-validate** — `init` + `validate` on all `examples/*` (`basic`, `provisioned-with-autoscaling`)
3. **dynamodb-table-terratest** — real AWS integration test via OIDC
4. **generate-changelog** — runs `git-cliff` on non-main branches
5. **semantic-release** — runs only on `main`; uses Conventional Commits to auto-version

### GitHub Secrets

| Secret         | Description                          |
| -------------- | ------------------------------------ |
| `AWS_ROLE_ARN` | IAM role ARN for OIDC authentication |

### GitHub Variables

| Variable            | Description                                                               | Default |
| ------------------- | ------------------------------------------------------------------------- | ------- |
| `AWS_REGION`        | AWS region for Terratest                                                  | -       |
| `AWS_KMS_KEY_ARN`   | KMS key ARN used to assert SSE-on-CMK paths in the DynamoDB Terratest run | -       |
| `TERRAFORM_VERSION` | Terraform version for CI jobs                                             | `1.3.0` |
| `GO_VERSION`        | Go version for Terratest                                                  | `1.21`  |

## License

MIT License — see [LICENSE](LICENSE) for details.
