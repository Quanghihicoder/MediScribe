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

        { name = "MSK_BROKERS", value = "${var.msk_bootstrap_brokers}" }
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








# =================================================

resource "aws_iam_role" "ecs_task_execution_role" {
  name = "ecs-task-execution-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_task_execution_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role_policy_attachment" "ecr_read_only" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}



resource "aws_ecs_cluster" "transcriber_cluster" {
  name = "transcriber-cluster"
}

resource "aws_ecs_task_definition" "transcriber_task" {
  family                   = "transcriber-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  execution_role_arn = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn            = var.ecs_task_exec_role_arn
  cpu                      = 2048  # 2 vCPU
  memory                   = 4096  # 4GB (Fargate requires specific CPU/memory combinations)
  
  # Fargate requires this
  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture       = "X86_64"  # or "ARM64" if you prefer
  }

  container_definitions = jsonencode([{
    name      = "transcriber"
    image     = "058264550947.dkr.ecr.ap-southeast-2.amazonaws.com/mediscribe/transcriber:latest"
    essential = true
    command   = ["python", "handler.py"]
    
    environment = [
      { name = "MSK_BROKERS", value = var.msk_bootstrap_brokers }
    ]
    
    log_configuration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = "/ecs/transcriber"
        "awslogs-region"        = "ap-southeast-2"
        "awslogs-stream-prefix" = "ecs"
      }
    }
  }])
}

resource "aws_ecs_service" "transcriber_service" {
  name            = "transcriber-service"
  cluster         = aws_ecs_cluster.transcriber_cluster.id
  task_definition = aws_ecs_task_definition.transcriber_task.arn
  desired_count   = 1
  launch_type     = "FARGATE"  # Explicitly set launch type to Fargate

  network_configuration {
    subnets          = [var.private_subnet_a_id, var.private_subnet_b_id]
    security_groups  = [var.ecs_sg_id]
    assign_public_ip = false  # Typically false for private subnets
  }
}







resource "aws_ecs_cluster" "summarizer_cluster" {
  name = "summarizer-cluster"
}

resource "aws_ecs_task_definition" "summarizer_task" {
  family                   = "summarizer-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  execution_role_arn = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn            = var.ecs_task_exec_role_arn
  cpu                      = 2048  # 2 vCPU
  memory                   = 4096  # 4GB (Fargate requires specific CPU/memory combinations)
  
  # Fargate requires this
  runtime_platform {
    operating_system_family = "LINUX"
    cpu_architecture       = "X86_64"  # or "ARM64" if you prefer
  }

  container_definitions = jsonencode([{
    name      = "summarizer"
    image     = "058264550947.dkr.ecr.ap-southeast-2.amazonaws.com/mediscribe/summarizer"
    essential = true
    command   = ["python", "handler.py"]
    
    environment = [
      { name = "MSK_BROKERS", value = var.msk_bootstrap_brokers },
      { name = "OPENAI_API_KEY",  value = var.openai_api_key }
    ]
    
    log_configuration = {
      logDriver = "awslogs"
      options = {
        "awslogs-group"         = "/ecs/summarizer"
        "awslogs-region"        = "ap-southeast-2"
        "awslogs-stream-prefix" = "ecs"
      }
    }
  }])
}

resource "aws_ecs_service" "summarizer_service" {
  name            = "summarizer-service"
  cluster         = aws_ecs_cluster.summarizer_cluster.id
  task_definition = aws_ecs_task_definition.summarizer_task.arn
  desired_count   = 1
  launch_type     = "FARGATE"  # Explicitly set launch type to Fargate

  network_configuration {
    subnets          = [var.private_subnet_a_id, var.private_subnet_b_id]
    security_groups  = [var.ecs_sg_id]
    assign_public_ip = false  # Typically false for private subnets
  }
}
