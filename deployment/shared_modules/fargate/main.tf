# reusing earlier snippets for vpc ids
data "aws_secretsmanager_secret_version" "vpcid" {
  secret_id = "gepiviz_vpc_id"
}

data "aws_secretsmanager_secret_version" "secrets_key" {
  secret_id = "secrets_key"
}

# TODO change to
#resource "aws_efs_file_system" "cache" {
#  lifecycle_policy {
#    transition_to_ia = "AFTER_30_DAYS"
#  }
#  tags = {
#    Name = var.app_name
#  }
#}
data "aws_efs_file_system" "cache" {
  file_system_id = "${var.efs_filesystem_id}"
}

data "aws_subnets" "az_subnet" {
  filter {
    name   = "availabilityZone"
    values = ["us-west-2a", "us-west-2b"]
  }

  filter {
    name = "vpc-id"
    values = [local.vpc_id]
  }
}

locals {
  timestamp = formatdate("YYYY-MM-DD", timestamp())

  vpc_id = jsondecode(
    data.aws_secretsmanager_secret_version.vpcid.secret_string
  )

  gepiviz_key = jsondecode(
    data.aws_secretsmanager_secret_version.gepiviz_key.secret_string
  )
}

# IAM roles
data "aws_iam_policy_document" "ecs_task_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]

    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

data "aws_iam_policy_document" "dask_task_policy" {
  statement {
    effect = "Allow"

    actions = [
      "ec2:AuthorizeSecurityGroupIngress",
      "ec2:CreateSecurityGroup",
      "ec2:CreateTags",
      "ec2:DescribeNetworkInterfaces",
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeSubnets",
      "ec2:DescribeVpcs",
      "ec2:DeleteSecurityGroup",
      "ecs:CreateCluster",
      "ecs:DescribeTasks",
      "ecs:ListAccountSettings",
      "ecs:RegisterTaskDefinition",
      "ecs:RunTask",
      "ecs:StopTask",
      "ecs:ListClusters",
      "ecs:DescribeClusters",
      "ecs:DeleteCluster",
      "ecs:ListTaskDefinitions",
      "ecs:DescribeTaskDefinition",
      "ecs:DeregisterTaskDefinition",
      "iam:AttachRolePolicy",
      "iam:CreateRole",
      "iam:TagRole",
      "iam:PassRole",
      "iam:DeleteRole",
      "iam:ListRoles",
      "iam:ListRoleTags",
      "iam:ListAttachedRolePolicies",
      "iam:DetachRolePolicy",
      "logs:DescribeLogGroups",
      "logs:GetLogEvents",
      "logs:CreateLogGroup",
      "logs:PutRetentionPolicy"
    ]

    resources = ["*"]
  }
}

resource "aws_iam_role" "task_execution_role" {
  name               = "${var.group_name}-${var.project_name}-${var.app_name}-task-execution-role-${var.dev_color}"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_assume_role.json
  lifecycle {ignore_changes = [permissions_boundary]}
}

data "aws_iam_policy" "ecs_task_execution_role" {
  arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_role" {
  role       = aws_iam_role.task_execution_role.name
  policy_arn = data.aws_iam_policy.ecs_task_execution_role.arn
}

resource "aws_iam_role" "ecs_task_role_cloudwatch" {
  name               = "${var.group_name}-${var.project_name}-${var.app_name}-cw-role-${var.dev_color}"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_assume_role.json
  lifecycle { ignore_changes = [permissions_boundary] }
}

data "aws_iam_policy_document" "ecs_task_policy_cloudwatch" {
  statement {
    effect = "Allow"

    actions = [
      "cloudwatch:Put*",
      "ec2:AuthorizeSecurityGroupIngress",
      "ec2:CreateSecurityGroup",
      "ec2:CreateTags",
      "ec2:DescribeNetworkInterfaces",
      "ec2:DescribeSecurityGroups",
      "ec2:DescribeSubnets",
      "ec2:DescribeVpcs",
      "ec2:DeleteSecurityGroup",
      "ecs:CreateCluster",
      "ecs:DescribeTasks",
      "ecs:ListAccountSettings",
      "ecs:RegisterTaskDefinition",
      "ecs:RunTask",
      "ecs:StopTask",
      "ecs:ListClusters",
      "ecs:DescribeClusters",
      "ecs:DeleteCluster",
      "ecs:ListTaskDefinitions",
      "ecs:DescribeTaskDefinition",
      "ecs:DeregisterTaskDefinition",
      "iam:AttachRolePolicy",
      "iam:CreateRole",
      "iam:TagRole",
      "iam:PassRole",
      "iam:DeleteRole",
      "iam:ListRoles",
      "iam:ListRoleTags",
      "iam:ListAttachedRolePolicies",
      "iam:DetachRolePolicy",
      "logs:DescribeLogGroups",
      "logs:GetLogEvents",
      "logs:CreateLogGroup",
      "logs:PutRetentionPolicy"
    ]

    resources = ["*"]
  }
}

# setting up cloudwatch
resource "aws_iam_role_policy" "ecs_task_role_cloudwatch_policy" {
  name   = "${var.group_name}-${var.project_name}-${var.app_name}-cw-role-policy-${var.dev_color}"
  role   = aws_iam_role.ecs_task_role_cloudwatch.id
  policy = data.aws_iam_policy_document.ecs_task_policy_cloudwatch.json
}

resource "aws_cloudwatch_log_group" "ecs" {
  name              = "/aws/ecs/fargate/${var.group_name}/${var.project_name}-${var.app_name}-${var.dev_color}"
  retention_in_days = 30
}

resource "aws_cloudwatch_log_stream" "ecs" {
  name           = "${var.group_name}-${var.project_name}-${var.app_name}-logstream-${var.dev_color}"
  log_group_name = aws_cloudwatch_log_group.ecs.name
}


# setting up security group
resource "aws_security_group" "default" {
  name   = "${var.group_name}-${var.project_name}-${var.app_name}-${var.dev_color}-sg"
  vpc_id = local.vpc_id

  # from_port needs to be 0, may be because awsvpc ENI controls this ?
  ingress {
    from_port   = 0
    protocol    = "tcp"
    to_port     = 80
    cidr_blocks = ["0.0.0.0/0"]
  }

  # for redis
  ingress {
    from_port   = 0
    protocol    = "tcp"
    to_port     = 6379
    cidr_blocks = ["0.0.0.0/0"]
  }

  # for dask-scheduler
  ingress {
    from_port   = 0
    protocol    = "tcp"
    to_port     = 8786
    cidr_blocks = ["0.0.0.0/0"]
  }

  # for dask-scheduler
  ingress {
    from_port   = 0
    protocol    = "tcp"
    to_port     = 8787
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port = 0
    to_port   = 0
    protocol  = "-1"
    cidr_blocks = [
      "0.0.0.0/0"
    ]
  }

  lifecycle {
    ignore_changes = [
      tags, tags_all
    ]
  }
}


# setup cluster
resource "aws_ecs_cluster" "main" {
  name               = "${var.group_name}-${var.project_name}-${var.app_name}-${var.dev_color}"
  #capacity_providers = ["FARGATE_SPOT", "FARGATE"]

  setting {
    name  = "containerInsights"
    value = "enabled"
  }
  tags = {app_name = "${var.app_name}-${var.dev_color}"}
}

# setup service discovery
resource "aws_service_discovery_private_dns_namespace" "namespace" {
  name = "${var.app_name}-${var.dev_color}"
  vpc  = local.vpc_id
}

# load balancer
resource "aws_lb_target_group" "alb_tg" {
  #name        = "${var.group_name}-${var.project_name}-${var.app_name}-alb-tg-${var.dev_color}"
  #name        = "${var.group_name}-${var.app_name}-alb-tg-${var.dev_color}"
  name        = "${var.app_name}-${var.dev_color}-alb-tg"
  port        = 80
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = local.vpc_id

  health_check {
    enabled = true
    path    = "/api/v1/docs"
  }

  depends_on = [aws_alb.alb]
}

resource "aws_alb" "alb" {
  name               = "${var.group_name}-${var.project_name}-${var.app_name}-alb-${var.dev_color}"
  internal           = true
  load_balancer_type = "application"

  subnets = data.aws_subnets.az_subnet.ids

  security_groups = [
    aws_security_group.default.id
  ]
}

resource "aws_alb_listener" "alb_listener" {
  load_balancer_arn = aws_alb.alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.alb_tg.arn
  }
}

# route53
data "aws_route53_zone" "zone" {
  name         = "${var.group_name}.com" # change this to your domain
  private_zone = false
}

resource "aws_route53_record" "this" {
  zone_id = data.aws_route53_zone.zone.id
  name    = var.dev_color == "prd" ? "${var.app_name}.${data.aws_route53_zone.zone.name}" : "${var.app_name}-${var.dev_color}.${data.aws_route53_zone.zone.name}"
  type    = "A"

  alias {
    name                   = aws_alb.alb.dns_name
    zone_id                = aws_alb.alb.zone_id
    evaluate_target_health = true
  }
}

resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.app_name}-${var.dev_color}"

  dashboard_body = <<EOF
  {
      "widgets": [
          {
              "height": 8,
              "width": 13,
              "y": 0,
              "x": 0,
              "type": "log",
              "properties": {
                  "query": "SOURCE '/aws/ecs/fargate/${var.group_name}/${var.project_name}-${var.app_name}-${var.dev_color}' | fields @timestamp, @message\n| filter @message like /POST/\n| sort @timestamp desc",
                  "region": "${var.aws_region}",
                  "stacked": false,
                  "title": "[${var.project_name}-${var.app_name}-${var.dev_color}] POST requests",
                  "view": "table"
              }
          },
          {
              "height": 6,
              "width": 6,
              "y": 24,
              "x": 0,
              "type": "metric",
              "properties": {
                  "metrics": [
                      [ "ECS/ContainerInsights", "MemoryUtilized", "ClusterName", "${var.group_name}-${var.project_name}-${var.app_name}-${var.dev_color}" ]
                  ],
                  "sparkline": true,
                  "view": "timeSeries",
                  "region": "${var.aws_region}",
                  "stacked": true,
                  "setPeriodToTimeRange": true,
                  "stat": "Average",
                  "period": 300,
                  "yAxis": {
                      "left": {
                          "showUnits": true
                      }
                  },
                  "title": "RAM"
              }
          },
          {
              "height": 8,
              "width": 13,
              "y": 8,
              "x": 0,
              "type": "log",
              "properties": {
                  "query": "SOURCE '/aws/ecs/fargate/${var.group_name}/${var.project_name}-${var.app_name}-${var.dev_color}' | fields @timestamp, @message\n| filter @message like \"GET\" and @message not like \"GET /api/v1/docs\"\n| sort @timestamp desc",
                  "region": "${var.aws_region}",
                  "stacked": false,
                  "title": "[${var.project_name}-${var.app_name}-${var.dev_color}] GET requests (minus /api/v1/docs)",
                  "view": "table"
              }
          },
          {
              "height": 3,
              "width": 6,
              "y": 0,
              "x": 13,
              "type": "log",
              "properties": {
                  "query": "SOURCE '/aws/ecs/fargate/${var.group_name}/${var.project_name}-${var.app_name}-${var.dev_color}' | fields @timestamp, @message\n| filter @message like /POST/\n| sort @timestamp desc\n| stats count(*) as post_requests_count",
                  "region": "${var.aws_region}",
                  "stacked": false,
                  "title": "[${var.project_name}-${var.app_name}-${var.dev_color}] POST requests COUNT",
                  "view": "table"
              }
          },
          {
              "height": 5,
              "width": 6,
              "y": 3,
              "x": 13,
              "type": "log",
              "properties": {
                  "query": "SOURCE '/aws/ecs/fargate/${var.group_name}/${var.project_name}-${var.app_name}-${var.dev_color}' | fields @timestamp, @message\n| filter @message like /POST/\n| sort @timestamp desc\n| stats count(*) by bin(1d) as post_requests_per_day",
                  "region": "${var.aws_region}",
                  "stacked": false,
                  "title": "[${var.project_name}-${var.app_name}-${var.dev_color}] POST requests COUNT per day",
                  "view": "table"
              }
          },
          {
              "height": 5,
              "width": 6,
              "y": 11,
              "x": 13,
              "type": "log",
              "properties": {
                  "query": "SOURCE '/aws/ecs/fargate/${var.group_name}/${var.project_name}-${var.app_name}-${var.dev_color}' | fields @timestamp, @message\n| filter @message like \"GET\" and @message not like \"GET /api/v1/docs\"\n| sort @timestamp desc\n| stats count(*) by bin(1d) as get_requests_per_day",
                  "region": "${var.aws_region}",
                  "stacked": false,
                  "title": "[${var.project_name}-${var.app_name}-${var.dev_color}] GET requests COUNT per day",
                  "view": "table"
              }
          },
          {
              "height": 3,
              "width": 6,
              "y": 8,
              "x": 13,
              "type": "log",
              "properties": {
                  "query": "SOURCE '/aws/ecs/fargate/${var.group_name}/${var.project_name}-${var.app_name}-${var.dev_color}' | fields @timestamp, @message\n| filter @message like \"GET\" and @message not like \"GET /api/v1/docs\"\n| sort @timestamp desc\n| stats count(*) as get_requests_count",
                  "region": "${var.aws_region}",
                  "stacked": false,
                  "title": "[${var.project_name}-${var.app_name}-${var.dev_color}] GET requests COUNT",
                  "view": "table"
              }
          },
          {
              "height": 8,
              "width": 13,
              "y": 16,
              "x": 0,
              "type": "log",
              "properties": {
                  "query": "SOURCE '/aws/ecs/fargate/${var.group_name}/${var.project_name}-${var.app_name}-${var.dev_color}' | fields @timestamp, @message\n| filter @message like \"ERROR\"\n| sort @timestamp desc",
                  "region": "${var.aws_region}",
                  "stacked": false,
                  "title": "[${var.project_name}-${var.app_name}-${var.dev_color}] ERROR messages",
                  "view": "table"
              }
          },
          {
              "height": 5,
              "width": 6,
              "y": 16,
              "x": 13,
              "type": "log",
              "properties": {
                  "query": "SOURCE '/aws/ecs/fargate/${var.group_name}/${var.project_name}-${var.app_name}-${var.dev_color}' | fields @timestamp, @message\n| filter @message like \"ERROR\"\n| sort @timestamp desc\n| stats count(*) by bin(1d) as get_requests_per_day",
                  "region": "${var.aws_region}",
                  "stacked": false,
                  "title": "Log group: /aws/ecs/fargate/${var.group_name}/${var.project_name}-${var.app_name}-${var.dev_color}",
                  "view": "table"
              }
          },
          {
              "height": 6,
              "width": 6,
              "y": 24,
              "x": 6,
              "type": "metric",
              "properties": {
                  "metrics": [
                      [ "ECS/ContainerInsights", "CpuUtilized", "ClusterName", "${var.group_name}-${var.project_name}-${var.app_name}-${var.dev_color}" ]
                  ],
                  "sparkline": true,
                  "view": "timeSeries",
                  "region": "${var.aws_region}",
                  "stacked": true,
                  "setPeriodToTimeRange": true,
                  "stat": "Average",
                  "period": 300,
                  "yAxis": {
                      "left": {
                          "showUnits": true
                      }
                  },
                  "title": "CPU"
              }
          },
          {
              "height": 6,
              "width": 6,
              "y": 24,
              "x": 12,
              "type": "metric",
              "properties": {
                  "metrics": [
                      [ "ECS/ContainerInsights", "TaskCount", "ClusterName", "${var.group_name}-${var.project_name}-${var.app_name}-${var.dev_color}", { "region": "${var.aws_region}" } ],
                      [ ".", "ServiceCount", ".", ".", { "region": "${var.aws_region}" } ],
                      [ ".", "EphemeralStorageUtilized", ".", ".", { "region": "${var.aws_region}" } ],
                      [ ".", "ContainerInstanceCount", ".", "." ]
                  ],
                  "sparkline": true,
                  "view": "singleValue",
                  "region": "${var.aws_region}",
                  "stacked": true,
                  "setPeriodToTimeRange": true,
                  "stat": "Average",
                  "period": 300,
                  "yAxis": {
                      "left": {
                          "showUnits": true
                      }
                  },
                  "title": "Overall"
              }
          }
      ]
  }
 EOF
}
