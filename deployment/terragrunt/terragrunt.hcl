 locals {
  environment_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  aws_profile = local.environment_vars.locals.aws_profile
  account_name = local.environment_vars.locals.account_name
  account_id   = local.environment_vars.locals.aws_account_id
  aws_region   = local.environment_vars.locals.aws_region
}

generate "provider" {
  path      = "provider.tf"
  if_exists = "overwrite_terragrunt"
  contents  = <<EOF
provider "aws" {
  region = "${local.aws_region}"
  profile = "${local.aws_profile}"
  # Only these AWS Account IDs may be operated on by this template
  allowed_account_ids = ["${local.account_id}"]
#    default_tags {
#      tags = {
#        region = "${local.aws_region}"
#        project_name = "${local.environment_vars.locals.project_name}-${local.environment_vars.locals.environment}"
#      }
#    }
}
EOF
}

remote_state {
  backend = "s3"
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite"
  }
  config = {
    profile        = "${local.aws_profile}"
    bucket         = "${local.environment_vars.locals.tf_bucket_name}"
    key            = "${path_relative_to_include()}/terraform.tfstate"
    region         = "${local.environment_vars.locals.tf_region}"
    #encrypt        = true
    #dynamodb_table = "${local.environment_vars.locals.tf_lock_table_name}"
  }
  disable_dependency_optimization = true
}

inputs = merge(
    local.environment_vars.locals,
)

