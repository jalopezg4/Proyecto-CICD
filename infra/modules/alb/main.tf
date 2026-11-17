resource "aws_lb" "este" {
  name               = "${var.name}-alb"
  internal           = var.internal
  load_balancer_type = "application"
  security_groups    = [var.security_group_id]
  subnets            = var.subnet_ids

  tags = { Name = "${var.name}-alb" }
}

resource "aws_lb_target_group" "este" {
  name        = "${var.name}-tg"
  port        = var.target_port
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = var.vpc_id

  health_check {
    path                = var.health_check_path
    healthy_threshold   = 2
    unhealthy_threshold = 3
    interval            = 15
    timeout             = 5
    matcher             = "200"
  }

  # D4: NiceGUI guarda estado por cliente y usa WebSocket; sin afinidad, más de una tarea
  # rompe la UI. El backend (ALB interno) no lo necesita: no guarda estado de sesión.
  stickiness {
    type            = "lb_cookie"
    cookie_duration = 86400
    enabled         = var.sticky_sessions
  }

  tags = { Name = "${var.name}-tg" }
}

resource "aws_lb_listener" "este" {
  load_balancer_arn = aws_lb.este.arn
  port              = coalesce(var.listener_port, var.target_port)
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.este.arn
  }
}
