data "aws_ami" "ecs_ami" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["amzn2-ami-ecs-hvm-*-x86_64-ebs"]
  }
}

resource "aws_ecs_cluster" "backend" {
  name = "${var.project_name}-backend"
}

resource "aws_instance" "backend" {
  ami                         = data.aws_ami.ecs_ami.id
  instance_type               = var.instance_type # it is cheaper to use t3.small running 4 tasks than t3.micro but can only run 1 task which will need to add more ec2 instances
  subnet_id                   = var.public_subnet_a_id
  iam_instance_profile        = var.backend_instance_profile_name
  security_groups             = [var.backend_sg_id]
  associate_public_ip_address = true

  user_data = <<EOF
  #!/bin/bash
  echo ECS_CLUSTER=${aws_ecs_cluster.backend.name} >> /etc/ecs/ecs.config
  echo "ECS_AVAILABLE_LOGGING_DRIVERS=[\"json-file\",\"awslogs\"]" >> /etc/ecs/ecs.config
  EOF

  tags = {
    Name = "${var.project_name}-backend-instance"
  }
}

resource "aws_eip" "backend_eip" {
  instance = aws_instance.backend.id
  domain   = "vpc"
}

resource "aws_ecs_task_definition" "backend_app_task" {
  family                   = "${var.project_name}-backend"
  requires_compatibilities = ["EC2"]
  network_mode             = "bridge"
  cpu                      = "256"
  memory                   = "512"
  task_role_arn            = var.backend_task_exec_role_arn

  container_definitions = jsonencode([
    {
      name      = "${var.project_name}-backend",
      image     = var.backend_image_url,
      essential = true,
      environment = [
        { name = "NODE_ENV", value = "production" },
        { name = "PORT", value = "8000" },
        { name = "ALLOW_ORIGIN", value = "${var.frontend_url}" },
        { name = "AWS_REGION", value = "${var.aws_region}" },
        { name = "MSK_BROKERS", value = "${var.msk_bootstrap_brokers}" }
      ],
      portMappings = [{
        containerPort = 8000
        hostPort      = 8000
      }],
      logConfiguration = {
        logDriver = "awslogs",
        options = {
          awslogs-group         = var.backend_logs_group_name
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "ecs"
        }
      }
    }
  ])
}

resource "aws_ecs_service" "backend" {
  name            = "${var.project_name}-backend-service"
  cluster         = aws_ecs_cluster.backend.id
  task_definition = aws_ecs_task_definition.backend_app_task.arn
  desired_count   = 1
  launch_type     = "EC2"

  load_balancer {
    target_group_arn = var.alb_target_group_arn
    container_name   = "${var.project_name}-backend"
    container_port   = 8000
  }
}








# =================================================



# =================================================


resource "aws_ecs_cluster" "transcriber" {
  name = "${var.project_name}-transcriber"
}

resource "aws_ecs_task_definition" "transcriber_task" {
  family                   = "${var.project_name}-transcriber"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  execution_role_arn       = var.service_execution_role_arn
  task_role_arn            = var.service_task_exec_role_arn
  cpu                      = 2048  # 2 vCPU
  memory                   = 4096  # 4GB (Fargate requires specific CPU/memory combinations)
  
  # Fargate requires this
  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture       = "X86_64"  # or "ARM64" if you prefer
  }

  container_definitions = jsonencode([{
    name      = "${var.project_name}-transcriber"
    image     = var.transcriber_image_url
    essential = true
    command   = ["python", "-u" , "app.py"]
    
    environment = [
      { name = "MSK_BROKERS", value = var.msk_bootstrap_brokers }
    ]
    
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = var.transcriber_logs_group_name
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "ecs"
      }
    }
  }])
}

resource "aws_ecs_service" "transcriber" {
  name            = "${var.project_name}-transcriber-service"
  cluster         = aws_ecs_cluster.transcriber.id
  task_definition = aws_ecs_task_definition.transcriber_task.arn
  desired_count   = 1
  launch_type     = "FARGATE" 

  network_configuration {
    subnets          = [var.private_subnet_a_id, var.private_subnet_b_id]
    security_groups  = [var.service_sg_id]
    assign_public_ip = false 
  }
}







resource "aws_ecs_cluster" "summarizer" {
  name = "${var.project_name}-summarizer"
}

resource "aws_ecs_task_definition" "summarizer_task" {
  family                   = "${var.project_name}-summarizer"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  execution_role_arn       = var.service_execution_role_arn
  task_role_arn            = var.service_task_exec_role_arn
  cpu                      = 2048  # 2 vCPU
  memory                   = 4096  # 4GB (Fargate requires specific CPU/memory combinations)
  
  # Fargate requires this
  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture       = "X86_64"  # or "ARM64" if you prefer
  }

  container_definitions = jsonencode([{
    name      = "${var.project_name}-summarizer" 
    image     = var.summarizer_image_url
    essential = true
    command   = ["python", "-u", "app.py"]
    
    environment = [
      { name = "MSK_BROKERS", value = var.msk_bootstrap_brokers },
      { name = "OPENAI_API_KEY",  value = var.openai_api_key }
    ]
    
    logConfiguration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = var.summarizer_logs_group_name
        "awslogs-region"        = var.aws_region
        "awslogs-stream-prefix" = "ecs"
      }
    }
  }])
}

resource "aws_ecs_service" "summarizer" {
  name            = "${var.project_name}-summarizer-service"
  cluster         = aws_ecs_cluster.summarizer.id
  task_definition = aws_ecs_task_definition.summarizer_task.arn
  desired_count   = 1
  launch_type     = "FARGATE" 

  network_configuration {
    subnets          = [var.private_subnet_a_id, var.private_subnet_b_id]
    security_groups  = [var.service_sg_id]
    assign_public_ip = false  
  }
}
