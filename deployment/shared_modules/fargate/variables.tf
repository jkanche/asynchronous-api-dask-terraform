variable "dev_color" {}

variable "efs_filesystem_id" {}

variable "app_name" {
  description = "Name of the application"
}

variable "project_name" {
  description = "Project to identify the dask cluster with"
}

variable "group_name" {
  description = "Group to associate the entire deployment"
}

variable "aws_region" {
  description = "ie. us-west-2"
}