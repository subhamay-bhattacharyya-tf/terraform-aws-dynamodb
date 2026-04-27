variable "region" {
  type        = string
  description = "AWS region to deploy into."
  default     = "us-east-1"
}

variable "table_name" {
  type        = string
  description = "Name of the DynamoDB table to create."
  default     = "orders"
}
