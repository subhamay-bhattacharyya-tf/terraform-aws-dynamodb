module "dynamodb_table" {
  source = "../../modules/dynamodb-table"

  region = var.region

  tables = {
    orders = {
      name      = var.table_name
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
        Module      = "terraform-aws-dynamodb"
      }
    }
  }
}
