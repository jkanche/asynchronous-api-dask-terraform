terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.12.0"
    }
  }
}

module "ecr_push_custom_images" {
  source                   = "../../../../../../shared_modules/ecr_push_custom_images"
  image_names              = ["dask-deployer", "dask-scheduler", "dask-worker", "rest-api"]
  service_names            = ["deployer", "scheduler", "worker", "api"]
  docker_compose_directory = "../"
  aws_region               = var.aws_region
  app_name                 = var.app_name
  aws_account_id           = var.aws_account_id
  environment              = var.dev_color
  aws_profile              = var.aws_profile
}

module "ecr_push_opensource_images" {
  for_each           = { for image in local.images : image.image_name_to_pull => image }
  source             = "../../../../../../shared_modules/ecr_push_opensource_images"
  image_name_to_pull = each.value.image_name_to_pull
  image_tag_to_pull  = each.value.image_tag_to_pull
  image_name_to_push = each.value.image_name_to_push
  image_tag_to_push  = each.value.image_tag_to_push
  aws_account_id     = var.aws_account_id
  aws_region         = var.aws_region
  app_name           = var.app_name
  environment        = var.dev_color
  aws_profile        = var.aws_profile
}

module "fargate" {
  source            = "../../../../../../shared_modules/fargate"
  dev_color         = var.dev_color
  app_name          = var.app_name
  project_name      = var.project_name
  group_name        = var.group_name
  efs_filesystem_id = var.efs_filesystem_id
  aws_region        = var.aws_region
}


# commented out because ECS service recreation is not needed anymore
#module "ecs_service_recreation" {
#  source       = "../../../../../../shared_modules/ecs_service_recreation"
#  ecs_cluster  = local.ecs_cluster_name
#  ecs_service  = "${var.app_name}-${var.dev_color}-dask-cluster-service"
#  environment  = var.dev_color
#  aws_region   = var.aws_region
#  app_name     = var.app_name
#  project_name = var.project_name
#  group_name   = var.group_name
#}

locals {
  task_execution_role_arn        = module.fargate.task_execution_role_arn
  ecs_cluster_id                 = module.fargate.ecs_cluster_id
  security_group_id              = module.fargate.sg_id
  az_subnet_ids                  = module.fargate.az_subnet_ids
  ecs_task_role_cloudwatch_arn   = module.fargate.ecs_task_role_cloudwatch_arn
  ecs_cloudwatch_log_group_name  = module.fargate.ecs_cloudwatch_log_group_name
  ecs_cluster_arn                = module.fargate.ecs_cluster_arn
  vpc_id                         = module.fargate.vpc_id
  alb_tg_arn                     = module.fargate.alb_tg_arn
  service_discovery_namespace_id = module.fargate.service_discovery_namespace_id
  ecr_repository_urls            = module.ecr_push_custom_images.repository_urls
  ecs_cluster_name               = module.fargate.ecs_cluster_name

  images = [
    {
      image_name_to_pull = "bitnami/redis"
      image_tag_to_pull  = "latest"
      image_name_to_push = "bitnami.redis"
      image_tag_to_push  = "latest"
    }
  ]
}

resource "aws_service_discovery_service" "sd_redis" {
  depends_on = [module.fargate]
  name       = "redis"
  dns_config {
    namespace_id = local.service_discovery_namespace_id
    dns_records {
      ttl  = 10
      type = "A"
    }

    routing_policy = "MULTIVALUE"
  }
  health_check_custom_config {
    failure_threshold = 1
  }
}

resource "aws_service_discovery_service" "sd_dask_scheduler" {
  depends_on = [module.fargate]
  name       = "dask-scheduler"
  dns_config {
    namespace_id = local.service_discovery_namespace_id
    dns_records {
      ttl  = 10
      type = "A"
    }

    routing_policy = "MULTIVALUE"
  }
  health_check_custom_config {
    failure_threshold = 1
  }
}

resource "aws_ecs_task_definition" "task_dask_worker" {
  depends_on            = [module.fargate]
  family                = "${var.app_name}-${var.dev_color}-dask-worker"
  container_definitions = <<EOF
    [
        {
            "name": "dask-worker",
            "image": "${local.ecr_repository_urls["dask-worker"]}",
            "command": ["dask-worker", "--nthreads", "4", "--memory-limit", "16384MB", "--death-timeout", "60"],
            "mountPoints": [
                {
                    "containerPath": "/files",
                    "sourceVolume": "${var.app_name}"
                }
            ],
            "ulimits": [
                {
                    "name": "nofile",
                    "softLimit": 65535,
                    "hardLimit": 65535
                }
            ],
            "cpu": 4096,
            "memory": 16384,
            "logConfiguration": {
                "logDriver": "awslogs",
                "options": {
                    "awslogs-region": "${var.aws_region}",
                    "awslogs-group": "/aws/ecs/fargate/${var.group_name}/${var.project_name}-${var.app_name}-${var.dev_color}",
                    "awslogs-stream-prefix": "ecs"
                }
            }
        }
    ]
    EOF

  volume {
    name = var.app_name
    efs_volume_configuration {
      file_system_id     = var.efs_filesystem_id
      transit_encryption = "ENABLED"
    }
  }

  execution_role_arn       = local.task_execution_role_arn
  task_role_arn            = local.ecs_task_role_cloudwatch_arn
  cpu                      = 4096
  memory                   = 16384
  requires_compatibilities = ["FARGATE"]

  network_mode = "awsvpc"
}


# task for dask-scheduler
resource "aws_ecs_task_definition" "task_dask_scheduler" {
  depends_on            = [module.fargate, module.ecr_push_custom_images]
  family                = "${var.app_name}-${var.dev_color}-dask-scheduler"
  container_definitions = <<EOF
    [
        {
            "name": "${var.app_name}-${var.dev_color}-dask-scheduler",
            "image": "${local.ecr_repository_urls["dask-scheduler"]}",
            "command": ["dask-scheduler"],
            "portMappings": [
                {
                    "containerPort": 8786,
                    "hostPort": 8786
                }, {
                    "containerPort": 8787,
                    "hostPort": 8787
                }
            ],
            "cpu": 1024,
            "memory": 4096,
            "logConfiguration": {
                "logDriver": "awslogs",
                "options": {
                    "awslogs-region": "${var.aws_region}",
                    "awslogs-group": "/aws/ecs/fargate/${var.group_name}/${var.project_name}-${var.app_name}-${var.dev_color}",
                    "awslogs-stream-prefix": "ecs"
                }
            }
        }
    ]
    EOF

  execution_role_arn       = local.task_execution_role_arn
  cpu                      = 1024
  memory                   = 4096
  requires_compatibilities = ["FARGATE"]

  network_mode = "awsvpc"
}

# resource service for dask-scheduler

resource "aws_ecs_service" "service_dask_scheduler" {
  depends_on      = [module.fargate]
  name            = "${var.app_name}-${var.dev_color}-dask-scheduler"
  task_definition = aws_ecs_task_definition.task_dask_scheduler.arn
  cluster         = local.ecs_cluster_id
  launch_type     = "FARGATE"

  network_configuration {
    assign_public_ip = false

    security_groups = [
      local.security_group_id,
    ]

    subnets = local.az_subnet_ids
  }

  service_registries {
    registry_arn   = aws_service_discovery_service.sd_dask_scheduler.arn
    container_name = "${var.app_name}-${var.dev_color}-dask-scheduler"
  }

  desired_count         = 1
  wait_for_steady_state = true

  lifecycle {
    ignore_changes = [desired_count]
  }
}

# dask cluster service
resource "aws_ecs_service" "dask_cluster_service" {
  name            = "${var.app_name}-${var.dev_color}-dask-cluster-service"
  task_definition = aws_ecs_task_definition.task_dask_cluster.arn
  cluster         = local.ecs_cluster_id
  launch_type     = "FARGATE"

  network_configuration {
    assign_public_ip = false

    security_groups = [
      local.security_group_id,
    ]

    subnets = local.az_subnet_ids
  }

  desired_count = 1

  lifecycle {
    ignore_changes = [desired_count]
  }

  depends_on = [
    module.fargate,
    aws_ecs_service.dask_scheduler
  ]
}

# task for dask-cluster
resource "aws_ecs_task_definition" "task_dask_cluster" {
  family                = "${var.app_name}-${var.dev_color}-dask-cluster-task"
  container_definitions = <<EOF
    [
        {
            "name": "${var.app_name}-${var.dev_color}-dask-cluster-scaler",
            "image": "${local.ecr_repository_urls["dask-deployer"]}",
            "command": ["python", "/dask/dask_start.py"],
            "environment": [
                {"name": "VPC_ID", "value": "${local.vpc_id}"},
                {"name": "FARGATE_CLUSTER_ARN", "value": "${local.ecs_cluster_arn}"},
                {"name": "FILE_SYSTEM_ID", "value": "${var.efs_filesystem_id}"},
                {"name": "DASK_MAX_WORKERS", "value": "${var.max_workers}"},
                {"name": "DASK_MIN_WORKERS", "value": "${var.min_workers}"},
                {"name": "DASK_IMAGE", "value": "${local.ecr_repository_urls["dask-worker"]}"},
                {"name": "SCHEDULER_ADDRESS", "value": "tcp://dask-scheduler.${var.app_name}-${var.dev_color}:8786"},
                {"name": "FILES_PATH", "value": "/files"},
                {"name": "REDIS_DOMAIN", "value": "redis.${var.app_name}-${var.dev_color}"},
                {"name": "REDIS_PASSWORD", "value": "redis"},
                {"name": "WORKER_LOG_GROUP", "value": "${local.ecs_cloudwatch_log_group_name}"},
                {"name": "WORKER_TASK_DEF", "value": "${aws_ecs_task_definition.task_dask_worker.arn}"}
            ],
            "cpu": 1024,
            "memory": 2048,
            "logConfiguration": {
                "logDriver": "awslogs",
                "options": {
                    "awslogs-region": "${var.aws_region}",
                    "awslogs-group": "/aws/ecs/fargate/${var.group_name}/${var.project_name}-${var.app_name}-${var.dev_color}",
                    "awslogs-stream-prefix": "ecs"
                }
            }
        }
    ]
    EOF

  execution_role_arn       = local.task_execution_role_arn
  task_role_arn            = local.ecs_task_role_cloudwatch_arn
  cpu                      = 1024
  memory                   = 2048
  requires_compatibilities = ["FARGATE"]

  network_mode = "awsvpc"

  depends_on = [
    module.fargate,
    aws_ecs_service.service_dask_scheduler,
    module.ecr_push_custom_images
  ]
}

# task definitions for API
resource "aws_ecs_task_definition" "task_api_rest" {
  depends_on            = [module.fargate, module.ecr_push_custom_images]
  family                = "${var.app_name}-${var.dev_color}-api"
  container_definitions = <<EOF
    [
        {
            "name": "${var.app_name}-${var.dev_color}-api",
            "image": "${local.ecr_repository_urls["rest-api"]}",
            "command": ["uvicorn", "app.main:app", "--reload", "--host", "0.0.0.0", "--port", "80"],
            "portMappings": [
                {
                    "containerPort": 80,
                    "hostPort": 80
                }
            ],
            "mountPoints": [
                {
                    "containerPath": "/files",
                    "sourceVolume": "${var.app_name}"
                }
            ],
            "environment": [
                {"name": "FILES_PATH", "value": "/files"},
                {"name": "REDIS_DOMAIN", "value": "redis.${var.app_name}-${var.dev_color}"},
                {"name": "REDIS_PASSWORD", "value": "redis"},
                {"name": "DASK_DOMAIN", "value": "dask-scheduler.${var.app_name}-${var.dev_color}"},
                {"name": "DASK_PORT", "value": "8786"}
            ],
            "cpu": 1024,
            "memory": 2048,
            "logConfiguration": {
                "logDriver": "awslogs",
                "options": {
                    "awslogs-region": "${var.aws_region}",
                    "awslogs-group": "/aws/ecs/fargate/${var.group_name}/${var.project_name}-${var.app_name}-${var.dev_color}",
                    "awslogs-stream-prefix": "ecs"
                }
            }
        }
    ]
    EOF

  volume {
    name = var.app_name
    efs_volume_configuration {
      file_system_id     = var.efs_filesystem_id
      transit_encryption = "ENABLED"
    }
  }

  execution_role_arn       = local.task_execution_role_arn
  task_role_arn            = local.ecs_task_role_cloudwatch_arn
  cpu                      = 1024
  memory                   = 2048
  requires_compatibilities = ["FARGATE"]

  network_mode = "awsvpc"
}

# resource for API
resource "aws_ecs_service" "service_api_rest" {
  name            = "${var.app_name}-${var.dev_color}-api"
  task_definition = aws_ecs_task_definition.task_api_rest.arn
  cluster         = local.ecs_cluster_id
  launch_type     = "FARGATE"

  network_configuration {
    assign_public_ip = false

    security_groups = [
      local.security_group_id,
    ]

    subnets = local.az_subnet_ids
  }

  load_balancer {
    target_group_arn = local.alb_tg_arn
    container_name   = aws_ecs_task_definition.task_api_rest.family
    container_port   = 80
  }

  desired_count = 1

  lifecycle {
    ignore_changes = [desired_count]
  }

  depends_on = [
    aws_ecs_service.service_dask_scheduler,
    aws_ecs_service.service_api_redis,
    module.fargate
  ]
}

# task for redis
resource "aws_ecs_task_definition" "task_redis" {
  depends_on            = [module.fargate, module.ecr_push_custom_images, module.ecr_push_opensource_images]
  family                = "${var.app_name}-${var.dev_color}-redis"
  container_definitions = <<EOF
    [
        {
            "name": "${var.app_name}-${var.dev_color}-redis",
            "image": "${var.aws_account_id}.dkr.ecr.${var.aws_region}.amazonaws.com/${var.app_name}/${var.dev_color}/bitnami.redis:latest",
            "portMappings": [
                {
                    "containerPort": 6379,
                    "hostPort": 6379
                }
            ],
            "environment": [
                {"name": "REDIS_PASSWORD", "value": "redis"}
            ],
            "cpu": 1024,
            "memory": 2048,
            "logConfiguration": {
                "logDriver": "awslogs",
                "options": {
                    "awslogs-region": "${var.aws_region}",
                    "awslogs-group": "/aws/ecs/fargate/${var.group_name}/${var.project_name}-${var.app_name}-${var.dev_color}",
                    "awslogs-stream-prefix": "ecs"
                }
            }
        }
    ]
    EOF

  execution_role_arn       = local.task_execution_role_arn
  cpu                      = 1024
  memory                   = 2048
  requires_compatibilities = ["FARGATE"]

  network_mode = "awsvpc"
}

# resource service for redis
resource "aws_ecs_service" "service_api_redis" {
  depends_on      = [module.fargate]
  name            = "${var.app_name}-${var.dev_color}-redis"
  task_definition = aws_ecs_task_definition.task_redis.arn
  cluster         = local.ecs_cluster_id
  launch_type     = "FARGATE"

  network_configuration {
    assign_public_ip = false

    security_groups = [
      local.security_group_id,
    ]

    subnets = local.az_subnet_ids
  }

  service_registries {
    registry_arn   = aws_service_discovery_service.sd_redis.arn
    container_name = "${var.app_name}-${var.dev_color}-redis"
  }

  desired_count         = 1
  wait_for_steady_state = true

  lifecycle {
    ignore_changes = [desired_count]
  }
}
