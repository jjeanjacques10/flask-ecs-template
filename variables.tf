variable "subnets" {
  type    = list(string)
  default = ["subnet-123456789", "subnet-23456778"]
}

variable "vpc_id" {
  type    = string
  default = "vpc-123456789"
}

variable "region" {
  type    = string
  default = "us-east-1"
}

variable "docker_image" {
  type    = string
  default = "public.ecr.aws/o2n5f4o6/flask-app:latest"
}

variable "account_id" {
  type = string
  default = "123456789102"
}