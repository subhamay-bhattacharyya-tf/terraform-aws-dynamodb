variable "region" {
  type        = string
  description = "AWS region to deploy into."
  default     = "us-east-1"
}

variable "table_name" {
  type        = string
  description = "Name of the provisioned DynamoDB table to create."
  default     = "events"
}

variable "gsi_name" {
  type        = string
  description = "Name of the GSI created on the table."
  default     = "by-source"
}
