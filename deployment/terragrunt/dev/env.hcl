locals {
    environment    = "dev"
    account_name   = ""
    aws_account_id = ""
    aws_profile    = "default"
    aws_region     = "us-west-2"
    project_name   = ""
    group_name     = ""

    # Terraform config
    tf_bucket_name = "terraform-state"
    tf_region = "us-west-2"
    #tf_lock_table_name = "adb-infra-lock-table"
}