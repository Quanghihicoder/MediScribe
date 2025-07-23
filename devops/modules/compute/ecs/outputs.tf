output "ecs_cluster_name" {
  value = aws_ecs_cluster.mediscribe_ecs.name
}

output "ecs_service_name" {
  value = aws_ecs_service.mediscribe_service.name
}
