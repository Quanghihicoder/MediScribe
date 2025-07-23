resource "aws_cloudwatch_log_group" "ecs_task_logs" {
  name              = "/ecs/mediscribe"
  retention_in_days = 7
}
