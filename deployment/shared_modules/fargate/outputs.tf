output "service_discovery_namespace_id" {
  value = aws_service_discovery_private_dns_namespace.namespace.id
}

output "alb_url" {
  value = "http://${aws_alb.alb.dns_name}"
}

output "task_execution_role_arn" {
  value       = aws_iam_role.task_execution_role.arn
}

output "ecs_task_role_cloudwatch_arn" {
  value       = aws_iam_role.ecs_task_role_cloudwatch.arn
}

output "ecs_cluster_id" {
  value       = aws_ecs_cluster.main.id
}

output "ecs_cluster_arn" {
  value       = aws_ecs_cluster.main.arn
}

output "ecs_cluster_name" {
  value       = aws_ecs_cluster.main.name
}

output "sg_id" {
  value       = aws_security_group.default.id
}

output "az_subnet_ids" {
  value       = data.aws_subnets.az_subnet.ids
}

output "ecs_cloudwatch_log_group_name" {
  value       = aws_cloudwatch_log_group.ecs.name
}

output "vpc_id" {
  value = local.vpc_id
}

output "alb_tg_arn" {
  value = aws_lb_target_group.alb_tg.arn
}