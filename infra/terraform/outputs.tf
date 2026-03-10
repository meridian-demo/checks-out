output "cluster_arn" {
  description = "ECS cluster ARN"
  value       = aws_ecs_cluster.checks_out.arn
}

output "service_name" {
  description = "ECS service name"
  value       = aws_ecs_service.checks_out.name
}

output "target_group_arn" {
  description = "ALB target group ARN"
  value       = aws_lb_target_group.checks_out.arn
}
