variable "image_names" {
  type = list(string)
  description = "The Docker images to build and push"
  default     = ["dask-deployer", "dask-scheduler", "dask-worker", "rest-api"]
}

variable "service_names" {
  type = list(string)
  description = "The service names to build from docker compose"
  default     = ["deployer", "scheduler", "worker", "api"]
}

variable "service_dirs" {
  type = list(string)
  description = "The service names to build from docker compose"
  default     = ["../api", "../dask", "../dask-awsdeploy", "../dask-worker"]
}

variable "docker_compose_directory" {
  type = string
  description = "The directory containing the Docker Compose file"
}

variable "aws_region" {
  type = string
  default = "us-west-2"
}

variable "app_name" {
  type = string
  default = "fibo"
}

variable "aws_account_id" {
  type = string
}

variable "environment" {
  type = string
}

variable "aws_profile" {
  type = string
}