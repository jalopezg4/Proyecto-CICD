data "aws_region" "current" {}

resource "aws_cloudwatch_log_group" "este" {
  name              = "/ecs/${var.name}"
  retention_in_days = 7
}

resource "aws_ecs_task_definition" "este" {
  family                   = var.name
  requires_compatibilities = ["FARGATE"]
  network_mode             = "awsvpc"
  cpu                      = var.cpu
  memory                   = var.memory
  execution_role_arn       = var.execution_role_arn
  task_role_arn            = var.task_role_arn

  container_definitions = jsonencode([
    {
      name      = var.name
      image     = var.image
      essential = true
      portMappings = [{
        containerPort = var.container_port
        protocol      = "tcp"
        name          = var.service_connect_alias
      }]
      environment = [for k, v in var.environment_variables : { name = k, value = v }]
      secrets     = [for k, v in var.secrets : { name = k, valueFrom = v }]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.este.name
          "awslogs-region"        = data.aws_region.current.name
          "awslogs-stream-prefix" = var.service_connect_alias
        }
      }
    }
  ])
}

resource "aws_ecs_service" "este" {
  name            = var.name
  cluster         = var.cluster_arn
  task_definition = aws_ecs_task_definition.este.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.subnet_ids
    security_groups  = [var.security_group_id]
    assign_public_ip = var.assign_public_ip
  }

  service_connect_configuration {
    enabled   = true
    namespace = var.service_connect_namespace_arn

    service {
      port_name      = var.service_connect_alias
      discovery_name = var.service_connect_alias
      client_alias {
        port = var.container_port
      }
    }
  }

  dynamic "load_balancer" {
    for_each = var.target_group_arn == null ? [] : [1]
    content {
      target_group_arn = var.target_group_arn
      container_name   = var.name
      container_port   = var.container_port
    }
  }

  health_check_grace_period_seconds = var.target_group_arn == null ? null : var.health_check_grace_period

  # D8 nivel 1: si la tarea nueva no pasa el health check, ECS no le manda trafico y
  # vuelve a la task definition anterior.
  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }
}
