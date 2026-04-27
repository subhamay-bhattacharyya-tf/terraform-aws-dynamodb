module "dynamodb_table" {
  source = "../../modules/dynamodb-table"

  region = var.region

  tables = {
    events = {
      name         = var.table_name
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
        (var.gsi_name) = {
          hash_key        = "Source"
          projection_type = "ALL"
          read_capacity   = 5
          write_capacity  = 5
        }
      }

      point_in_time_recovery = {
        enabled = true
      }

      tags = {
        Environment = "dev"
        Module      = "terraform-aws-dynamodb"
      }
    }
  }
}

locals {
  events_table_name = module.dynamodb_table.table_names["events"]
}

module "dynamodb_autoscaling" {
  source = "../../modules/dynamodb-autoscaling"

  region = var.region

  autoscaling = {
    "events-table-read" = {
      table_name         = local.events_table_name
      scope              = "table"
      capacity_type      = "read"
      min_capacity       = 5
      max_capacity       = 100
      target_utilization = 70
      tags = {
        Environment = "dev"
      }
    }

    "events-table-write" = {
      table_name         = local.events_table_name
      scope              = "table"
      capacity_type      = "write"
      min_capacity       = 5
      max_capacity       = 100
      target_utilization = 70
      tags = {
        Environment = "dev"
      }
    }

    "events-gsi-read" = {
      table_name         = local.events_table_name
      scope              = "index"
      index_name         = var.gsi_name
      capacity_type      = "read"
      min_capacity       = 5
      max_capacity       = 100
      target_utilization = 70
      tags = {
        Environment = "dev"
      }
    }

    "events-gsi-write" = {
      table_name         = local.events_table_name
      scope              = "index"
      index_name         = var.gsi_name
      capacity_type      = "write"
      min_capacity       = 5
      max_capacity       = 100
      target_utilization = 70
      tags = {
        Environment = "dev"
      }
    }
  }
}
