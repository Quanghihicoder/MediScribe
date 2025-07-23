variable "vpc_id" {
  description = "ID of the VPC"
  type        = string
}

variable "az_a" {
  description = "Availability Zone A"
  type        = string
}

variable "az_b" {
  description = "Availability Zone B"
  type        = string
}

variable "public_cidr_block_a" {
  description = "Public subnet cidr block A"
  default     = "10.0.6.0/24"
  type        = string
}

variable "public_cidr_block_b" {
  description = "Public subnet cidr block B"
  default     = "10.0.7.0/24"
  type        = string
}

variable "private_cidr_block_a" {
  description = "Private subnet cidr block A"
  default     = "10.0.8.0/24"
  type        = string
}

variable "private_cidr_block_b" {
  description = "Private subnet cidr block B"
  default     = "10.0.9.0/24"
  type        = string
}

variable "public_route_table_id" {
  type = string
}
