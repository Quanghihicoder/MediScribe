resource "aws_ecs_cluster" "mediscribe_ecs" {
  name = var.app_name
}

data "aws_ami" "ecs_ami" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-ecs-hvm-*-x86_64-ebs"]
  }
}

resource "aws_instance" "mediscribe_ecs_ec2" {
  ami                         = data.aws_ami.ecs_ami.id
  instance_type               = var.instance_type # it is cheaper to use t3.small running 4 tasks than t3.micro but can only run 1 task which will need to add more ec2 instances
  subnet_id                   = var.public_subnet_a_id
  iam_instance_profile        = var.iam_instance_profile_name
  security_groups             = [var.ecs_sg_id]
  associate_public_ip_address = true

  user_data = <<EOF
  #!/bin/bash
  echo ECS_CLUSTER=${aws_ecs_cluster.mediscribe_ecs.name} >> /etc/ecs/ecs.config
  echo "ECS_AVAILABLE_LOGGING_DRIVERS=[\"json-file\",\"awslogs\"]" >> /etc/ecs/ecs.config
  EOF

  tags = {
    Name = "mediscribe-ecs-ec2-instance"
  }
}

resource "aws_eip" "mediscribe_eip" {
  instance = aws_instance.mediscribe_ecs_ec2.id
  domain   = "vpc"
}

resource "aws_ecs_task_definition" "mediscribe_app_task" {
  family                   = "mediscribe"
  requires_compatibilities = ["EC2"]
  network_mode             = "bridge"
  cpu                      = "256"
  memory                   = "512"
  task_role_arn            = var.ecs_task_exec_role_arn

  container_definitions = jsonencode([
    {
      name      = "mediscribe",
      image     = var.ecs_image_url,
      essential = true,
      environment = [
        { name = "NODE_ENV", value = "production" },
        { name = "PORT", value = "8000" },

        { name = "ALLOW_ORIGIN", value = "${var.frontend_url}" },

        { name = "AWS_REGION", value = "${var.aws_region}" },

        { name = "MSK_BROKERS", value = "${var.msk_bootstrap_brokers_tls}" }
      ],
      portMappings = [{
        containerPort = 8000
        hostPort      = 8000
      }],
      logConfiguration = {
        logDriver = "awslogs",
        options = {
          awslogs-group         = var.ecs_logs_group_name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "ecs"
        }
      }
    }
  ])
}

resource "aws_ecs_service" "mediscribe_service" {
  name            = "mediscribe-service"
  cluster         = aws_ecs_cluster.mediscribe_ecs.id
  task_definition = aws_ecs_task_definition.mediscribe_app_task.arn
  desired_count   = 1
  launch_type     = "EC2"

  load_balancer {
    target_group_arn = var.alb_target_group_arn
    container_name   = "mediscribe"
    container_port   = 8000
  }
}
