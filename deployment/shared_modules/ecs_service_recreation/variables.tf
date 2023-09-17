variable "environment" {
  description = "ie. prd"
}

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

variable "ecs_cluster" {
  description = "ie. ecs fargate cluster id"
}

variable "ecs_service" {
  description = "ie. dask-cluster-service"
}
