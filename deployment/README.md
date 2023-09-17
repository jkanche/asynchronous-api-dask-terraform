# Deployment

## Prerequisites

- Terraform installed (version 1.4.5 or later)
- Terragrunt installed (version 0.46.2 or later)
- AWS CLI installed and configured with appropriate AWS account access
- Docker with `docker compose`

## Deploying Resources with Terragrunt

1. Pull all applications repos that you want to deploy
2. Navigate to the desired environment's directory.
3. Authenticate to AWS acc
4. Run `terragrunt init` followed by `terragrunt run-all plan` to check the changes
5. After verifying the changes, apply them by doing `terragrunt run-all apply`

## Cleanup

To destroy all resources managed by Terragrunt:

`terragrunt run-all destroy`

**Note:** Be careful when using `destroy` command as it will remove all resources specified in the configuration.


## Useful links - 

- The repo's above
- https://section411.com/2019/07/hello-world/
- https://github.com/PowerDataHub/terraform-aws-airflow
- https://medium.com/@bradford_hamilton/deploying-containers-on-amazons-ecs-using-fargate-and-terraform-part-2-2e6f6a3a957f
