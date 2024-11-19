variable "vpc_cidr" {
  type        = string
  description = "VPC IPv4 CIDR"
  default     = "10.0.0.0/16"
}

variable "pl_prototype_subnet_1_cidr" {
  type        = string
  default     = "10.0.1.0/24"
}

variable "pl_prototype_subnet_2_cidr" {
  type        = string
  default     = "10.0.2.0/24"
}

variable "pl_prototype_subnet_3_cidr" {
  type        = string
  default     = "10.0.3.0/24"
}