include "root" {
  path = find_in_parent_folders()
}

terraform {
  source = "${local.base_source_url}//deployment"
}

locals {
  environment_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))
  env = local.environment_vars.locals.environment
  base_source_url = "${get_parent_terragrunt_dir("root")}/../..//"
}

inputs = merge(
    local.environment_vars.locals,
    {
      app_name = "fibo",
      dev_color = local.environment_vars.locals.environment
    },
)

