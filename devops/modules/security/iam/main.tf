# Lambda exec role

resource "aws_iam_role" "lambda_exec" {
  name = "lambda-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_policy" "lambda_exec_permissions" {
  name = "lambda-exec-permissions"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "kafka:*",
          "kafka-cluster:*",
          "ec2:CreateNetworkInterface",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DescribeVpcs",
          "ec2:DeleteNetworkInterface",
          "ec2:DescribeSubnets",
          "ec2:DescribeSecurityGroups",
          "ec2:CreateTags",
          "iam:CreateServiceLinkedRole",
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        # Resource = [
        #   var.msk_cluster_arn,
        #   "${var.msk_cluster_arn}/*"
        # ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_policy_attachment" "lambda_policy" {
  name       = "lambda-policy-attachment"
  roles      = [aws_iam_role.lambda_exec.name]
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "lambda_attach_policy" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = aws_iam_policy.lambda_exec_permissions.arn
}


# ECS EC2 instance role

resource "aws_iam_role" "mediscribe_ecs_instance_role" {
  name = "mediscribe-ecs-instance-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement : [{
      Effect = "Allow",
      Principal = {
        Service = "ec2.amazonaws.com"
      },
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_instance_profile" "mediscribe_ecs_instance_profile" {
  name = "mediscribe-instance-profile"
  role = aws_iam_role.mediscribe_ecs_instance_role.name
}

resource "aws_iam_role_policy_attachment" "mediscribe_ecs_instance_role_policy" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
  role       = aws_iam_role.mediscribe_ecs_instance_role.name
}

resource "aws_iam_role_policy_attachment" "ecs_instance_cloudwatch_policy" {
  role       = aws_iam_role.mediscribe_ecs_instance_role.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

# ECS task exec role

resource "aws_iam_role" "mediscribe_ecs_task_exec_role" {
  name = "mediscribe-ecs-task-exec-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement : [{
      Effect = "Allow",
      Principal = {
        Service = "ecs-tasks.amazonaws.com"
      },
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_policy" "mediscribe_ecs_permissions" {
  name = "mediscribe-ecs-task-policy"

  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "kafka:*",
          "kafka-cluster:*",
          "ec2:CreateNetworkInterface",
          "ec2:DescribeNetworkInterfaces",
          "ec2:DescribeVpcs",
          "ec2:DeleteNetworkInterface",
          "ec2:DescribeSubnets",
          "ec2:DescribeSecurityGroups",
          "ec2:CreateTags",
          "iam:CreateServiceLinkedRole",
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogGroups",
          "logs:DescribeLogStreams"
        ]
        # Resource = [
        #   var.msk_cluster_arn,
        #   "${var.msk_cluster_arn}/*"
        # ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "ecs_attach_policy" {
  role       = aws_iam_role.mediscribe_ecs_task_exec_role.name
  policy_arn = aws_iam_policy.mediscribe_ecs_permissions.arn
}
