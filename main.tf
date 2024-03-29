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

provider "aws" {
  alias  = "apigateway"
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
  load_balancer_type = "network"
  subnets            = var.subnets

  enable_cross_zone_load_balancing = true
}

resource "aws_lb_target_group" "flask_app" {
  name        = "flask-app-target-group"
  port        = 8000
  protocol    = "TCP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  depends_on = [
    aws_lb.flask_app
  ]

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_lb_listener" "flask_app" {
  load_balancer_arn = aws_lb.flask_app.arn
  port              = 80
  protocol          = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.flask_app.arn
  }

}

# Gateway
resource "aws_api_gateway_rest_api" "flask_app" {
  name        = "flask-app-api"
  description = "API Gateway for the Flask app"
}

resource "aws_api_gateway_deployment" "flask_app" {
  rest_api_id = aws_api_gateway_rest_api.flask_app.id
  stage_name  = "prod"

  depends_on = [
    aws_api_gateway_integration.flask_app,
    aws_api_gateway_method.flask_app,
  ]
}

resource "aws_api_gateway_integration" "flask_app" {
  rest_api_id             = aws_api_gateway_rest_api.flask_app.id
  resource_id             = aws_api_gateway_resource.flask_app.id
  http_method             = aws_api_gateway_method.flask_app.http_method
  integration_http_method = "GET"
  type                    = "HTTP_PROXY"
  uri                     = "http://${aws_lb.flask_app.dns_name}/"
}


resource "aws_api_gateway_resource" "flask_app" {
  rest_api_id = aws_api_gateway_rest_api.flask_app.id
  parent_id   = aws_api_gateway_rest_api.flask_app.root_resource_id
  path_part   = "hello"
}

resource "aws_api_gateway_method" "flask_app" {
  rest_api_id   = aws_api_gateway_rest_api.flask_app.id
  resource_id   = aws_api_gateway_resource.flask_app.id
  http_method   = "GET"
  authorization = "NONE"
}