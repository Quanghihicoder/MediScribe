resource "aws_security_group" "alb_sg" {
  name        = "mediscribe-alb-sg"
  description = "Allow inbound traffic"
  vpc_id      = var.vpc_id

  # ingress {
  #   from_port   = 443
  #   to_port     = 443
  #   protocol    = "tcp"
  #   cidr_blocks = ["0.0.0.0/0"]
  # }

  # I don't know why, but it only works when all traffic is allowed.
  # Edit the ECS security group instead.
  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}


resource "aws_security_group" "ecs_sg" {
  name        = "mediscribe-ecs-ec2-sg"
  description = "SG for ECS EC2"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # ingress {
  #   from_port       = 80
  #   to_port         = 80
  #   protocol        = "tcp"
  #   security_groups = [aws_security_group.alb_sg.id]
  #   # cidr_blocks     = ["0.0.0.0/0"]
  # }

  # ingress {
  #   from_port       = 443
  #   to_port         = 443
  #   protocol        = "tcp"
  #   security_groups = [aws_security_group.alb_sg.id]
  #   # cidr_blocks     = ["0.0.0.0/0"]
  # }

  # ingress {
  #   from_port       = 8000
  #   to_port         = 8000
  #   protocol        = "tcp"
  #   security_groups = [aws_security_group.alb_sg.id]
  #   # cidr_blocks     = ["0.0.0.0/0"]
  # }

  # egress {
  #   from_port   = 0
  #   to_port     = 0
  #   protocol    = "-1"
  #   cidr_blocks = ["0.0.0.0/0"]
  # }

  tags = {
    Name = "mediscribe-ecs-ec2-sg"
  }
}

resource "aws_security_group" "msk_sg" {
  name        = "mediscribe-msk-sg"
  description = "Security group for MSK cluster"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # ingress {
  #   description = "Allow all inbound from self"
  #   from_port   = 0
  #   to_port     = 0
  #   protocol    = "-1"
  #   self        = true
  # }

  # ingress {
  #   description     = "Allow Kafka access from ECS"
  #   from_port       = 9098
  #   to_port         = 9098
  #   protocol        = "tcp"
  #   security_groups = [aws_security_group.ecs_sg.id]
  # }



  # egress {
  #   from_port   = 0
  #   to_port     = 0
  #   protocol    = "-1"
  #   cidr_blocks = ["0.0.0.0/0"]
  # }
}


resource "aws_security_group" "lambda_msk_sg" {
  name        = "mediscribe-lambda-msk-sg"
  description = "Security group for Lambda to access MSK"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # ingress {
  #   from_port       = 9098
  #   to_port         = 9098
  #   protocol        = "tcp"
  #   security_groups = [aws_security_group.msk_sg.id]
  # }

  # egress {
  #   from_port       = 9098
  #   to_port         = 9098
  #   protocol        = "tcp"
  #   security_groups = [aws_security_group.msk_sg.id]
  # }

  # egress {
  #   from_port   = 0
  #   to_port     = 0
  #   protocol    = "-1"
  #   cidr_blocks = ["0.0.0.0/0"]
  # }
}
