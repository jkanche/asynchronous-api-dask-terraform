variable "max_workers" {
  type        = number
  description = "Maximum number of workers dask can deploy"
  default     = 100
}

variable "dev_color" {
  type        = string
  description = "The infra instance (red/blue)"
  default     = "red"
}

variable "min_workers" {
  type        = number
  description = "Minimum number of dask workers to spin"
  default     = 1
}

variable "efs_filesystem_id" {
  type        = string
  description = "mount a volume?, provide the file-system-id of the EFS drive"
}

variable "app_name" {
  type        = string
  description = "Name of the application"
  default     = "Fibonacci"
}

variable "project_name" {
  type        = string
  description = "Project to identify the dask cluster with"
  default     = "MY_AWESOME_API"
}

variable "group_name" {
  type        = string
  description = "Group to associate the entire deployment"
  default     = "MY_GROUP"
}

variable "aws_region" {
  type        = string
  description = "AWS Region to deploy in, e.g. us-west-2"
  default     = "us-west-2"
}

variable "aws_account_id" {
  description = "AWS Account id"
}

variable "aws_profile" {
  type = string
}
