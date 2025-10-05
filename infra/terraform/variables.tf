variable "region" { default = "us-east-1" }
variable "vpc_id" {}
variable "public_subnets" { type = list(string) }
variable "private_subnets" { type = list(string) }

variable "db_host" {}
variable "db_name" { default = "notesdb" }
variable "db_user" { default = "notesuser" }
variable "db_pass" { sensitive = true }
