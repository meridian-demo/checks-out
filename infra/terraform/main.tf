terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket = "checks-out-terraform-state"
    key    = "checks-out/terraform.tfstate"
    region = "us-east-1"
  }
}

provider "aws" {
  region = var.aws_region
}

resource "aws_ecs_cluster" "checks_out" {
  name = "checks-out-${var.environment}"

  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = {
    Application = "checks-out"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_ecs_task_definition" "checks_out" {
  family                   = "checks-out-${var.environment}"
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = 256
  memory                   = 512
  execution_role_arn       = aws_iam_role.ecs_execution.arn
  task_role_arn            = aws_iam_role.ecs_task.arn

  container_definitions = jsonencode([
    {
      name      = "checks-out"
      image     = "${var.ecr_repository_url}:${var.image_tag}"
      essential = true

      portMappings = [
        {
          containerPort = 8000
          protocol      = "tcp"
        }
      ]

      environment = [
        {
          name  = "DATABASE_DRIVER"
          value = "mysql"
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/checks-out-${var.environment}"
          "awslogs-region"        = var.aws_region
          "awslogs-stream-prefix" = "checks-out"
        }
      }
    }
  ])

  tags = {
    Application = "checks-out"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_ecs_service" "checks_out" {
  name            = "checks-out"
  cluster         = aws_ecs_cluster.checks_out.id
  task_definition = aws_ecs_task_definition.checks_out.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.private_subnet_ids
    security_groups  = [aws_security_group.ecs.id]
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.checks_out.arn
    container_name   = "checks-out"
    container_port   = 8000
  }

  tags = {
    Application = "checks-out"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_security_group" "ecs" {
  name_prefix = "checks-out-ecs-${var.environment}-"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 8000
    to_port         = 8000
    protocol        = "tcp"
    security_groups = [var.alb_security_group_id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Application = "checks-out"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_lb_target_group" "checks_out" {
  name        = "checks-out-${var.environment}"
  port        = 8000
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    path                = "/healthz"
    port                = "traffic-port"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
  }

  tags = {
    Application = "checks-out"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_iam_role" "ecs_execution" {
  name = "checks-out-ecs-execution-${var.environment}"

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

  tags = {
    Application = "checks-out"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_iam_role_policy_attachment" "ecs_execution" {
  role       = aws_iam_role.ecs_execution.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_role" "ecs_task" {
  name = "checks-out-ecs-task-${var.environment}"

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

  tags = {
    Application = "checks-out"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

resource "aws_cloudwatch_log_group" "checks_out" {
  name              = "/ecs/checks-out-${var.environment}"
  retention_in_days = 30

  tags = {
    Application = "checks-out"
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}
