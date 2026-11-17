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
      }]
      environment = [for k, v in var.environment_variables : { name = k, value = v }]
      secrets     = [for k, v in var.secrets : { name = k, valueFrom = v }]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = aws_cloudwatch_log_group.este.name
          "awslogs-region"        = data.aws_region.current.name
          "awslogs-stream-prefix" = var.name
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

  # El backend va detrás de un ALB interno, y el frontend detrás del público: los dos siempre
  # tienen target group (ver infra/README.md sobre por qué no es Service Connect/Cloud Map).
  load_balancer {
    target_group_arn = var.target_group_arn
    container_name   = var.name
    container_port   = var.container_port
  }

  health_check_grace_period_seconds = var.health_check_grace_period

  # D8 nivel 1: si la tarea nueva no pasa el health check, ECS no le manda trafico y
  # vuelve a la task definition anterior.
  deployment_circuit_breaker {
    enable   = true
    rollback = true
  }
}
