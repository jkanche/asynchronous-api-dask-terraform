variable "image_name_to_pull" {
  description = "The name of the Docker image"
  type        = string
}

variable "image_name_to_push" {
  description = "The name of the Docker image"
  type        = string
}

variable "image_tag_to_push" {
  description = "The tag of the Docker image"
  type        = string
}

variable "image_tag_to_pull" {
  description = "The tag of the Docker image"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "aws_account_id" {
  type = string
}

variable "app_name" {
  type = string
}

variable "environment" {
  type = string
}

variable "aws_profile" {
  type = string
}