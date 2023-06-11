terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 4.16"
    }
  }

  required_version = ">= 1.2.0"
}

provider "aws" {
  region = var.region
}

# Create a CloudWatch Logs group for the Flask app
resource "aws_cloudwatch_log_group" "flask_log_group" {
  name = "/ecs/flask-app"
}

# Create a CloudWatch Logs stream for the Flask app
resource "aws_cloudwatch_log_stream" "flask_log_stream" {
  name           = "flask-app"
  log_group_name = aws_cloudwatch_log_group.flask_log_group.name
}

resource "aws_ecs_task_definition" "flask_app" {
  family                   = "flask-app"
  execution_role_arn       = aws_iam_role.task_execution.arn
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "256"
  memory                   = "512"
  container_definitions    = jsonencode([
    {
        "name": "flask-app",
        "image": "${var.docker_image}",
        "portMappings": [
        {
            "containerPort": 8000,
            "hostPort": 8000,
            "protocol": "tcp"
        }
        ],
        "essential": true,
        "logConfiguration": {
        "logDriver": "awslogs",
        "options": {
                "awslogs-group": aws_cloudwatch_log_group.flask_log_group.name,
                "awslogs-region": var.region,
                "awslogs-stream-prefix": "flask-app"
        }
        }
    }])
}

resource "aws_ecs_service" "flask_app" {
  name            = "flask-app"
  cluster         = aws_ecs_cluster.flask_app.id
  task_definition = aws_ecs_task_definition.flask_app.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    security_groups = [aws_security_group.ecs_service.id]
    subnets         = var.subnets
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.flask_app.arn
    container_name   = "flask-app"
    container_port   = 8000
  }

  lifecycle {
    ignore_changes = [desired_count]
  }
}

resource "aws_ecs_cluster" "flask_app" {
  name = "flask-app"
}

resource "aws_security_group" "ecs_service" {
  name        = "ecs-service"
  description = "Security group for ECS service"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 8000
    to_port     = 8000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_iam_role" "task_execution" {
  name = "flask-app-task-execution"

  assume_role_policy = jsonencode({
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Principal": {
          "Service": "ecs-tasks.amazonaws.com"
        },
        "Action": "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_policy" "task_execution_policy" {
  name        = "flask-app-task-execution-policy"
  description = "IAM policy for the Flask app task execution role"

  policy = jsonencode({
      "Version": "2012-10-17",
      "Statement": [
        {
          "Effect": "Allow",
          "Action": [
            "logs:CreateLogStream",
            "logs:PutLogEvents"
          ],
          "Resource": "arn:aws:logs:${var.region}:416068129208:log-group:/ecs/flask-app:*"
        }
      ]
    })
}

resource "aws_iam_role_policy_attachment" "task_execution_policy_attachment" {
  role       = aws_iam_role.task_execution.name
  policy_arn = aws_iam_policy.task_execution_policy.arn
}

resource "aws_lb" "flask_app" {
  name               = "flask-app-lb"
  load_balancer_type = "application"
  subnets            = var.subnets
}

resource "aws_lb_target_group" "flask_app" {
  name        = "flask-app-target-group"
  port        = 8000
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip" # Set the target type to "ip" for Fargate tasks

  health_check {
    path = "/"
    port = "traffic-port"
  }
}

resource "aws_lb_listener" "flask_app" {
  load_balancer_arn = aws_lb.flask_app.arn
  port              = 8000
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.flask_app.arn
  }
}