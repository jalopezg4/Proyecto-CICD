# Monitoreo del ambiente con CloudWatch: un dashboard y alarmas sobre las métricas que AWS ya
# publica (ALB y ECS), sin agentes ni servicios extra. Las pruebas del pipeline dicen si la
# versión estaba bien al desplegarla; esto muestra cómo sigue después.
#
# Las alarmas no tienen acciones (sin SNS/correo): quedan en rojo en la consola y en el resumen
# de cada run del CD (evidencia-aws.sh). El rollback lo decide una persona con el botón de pánico.

locals {
  alb      = ["LoadBalancer", var.alb_arn_suffix]
  alb_back = ["LoadBalancer", var.backend_alb_arn_suffix]
  tg_front = ["TargetGroup", var.frontend_target_group_arn_suffix, "LoadBalancer", var.alb_arn_suffix]
  tg_back  = ["TargetGroup", var.backend_target_group_arn_suffix, "LoadBalancer", var.backend_alb_arn_suffix]

  servicios = {
    frontend = var.frontend_service_name
    backend  = var.backend_service_name
  }

  # Base común de los gráficos
  grafico = {
    view    = "timeSeries"
    region  = var.region
    period  = 60
    stacked = false
  }
}

# ---------------------------------------------------------------------------
# Alarmas
# ---------------------------------------------------------------------------

resource "aws_cloudwatch_metric_alarm" "errores_5xx" {
  alarm_name          = "${var.name}-errores-5xx"
  alarm_description   = "El frontend respondió más de 5 errores 5xx por minuto, 2 minutos seguidos"
  namespace           = "AWS/ApplicationELB"
  metric_name         = "HTTPCode_Target_5XX_Count"
  dimensions          = { LoadBalancer = var.alb_arn_suffix }
  statistic           = "Sum"
  period              = 60
  evaluation_periods  = 2
  threshold           = 5
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching" # sin tráfico no hay errores
}

resource "aws_cloudwatch_metric_alarm" "latencia" {
  alarm_name          = "${var.name}-latencia-p95"
  alarm_description   = "La p95 del frontend pasó de ${var.latencia_p95_maxima} s durante 3 minutos (mismo umbral de k6)"
  namespace           = "AWS/ApplicationELB"
  metric_name         = "TargetResponseTime"
  dimensions          = { LoadBalancer = var.alb_arn_suffix }
  extended_statistic  = "p95"
  period              = 60
  evaluation_periods  = 3
  threshold           = var.latencia_p95_maxima
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
}

resource "aws_cloudwatch_metric_alarm" "tareas_caidas" {
  for_each = {
    frontend = { tg = var.frontend_target_group_arn_suffix, lb = var.alb_arn_suffix }
    backend  = { tg = var.backend_target_group_arn_suffix, lb = var.backend_alb_arn_suffix }
  }

  alarm_name          = "${var.name}-${each.key}-sin-tareas-sanas"
  alarm_description   = "El ${each.key} no tiene ninguna tarea sana en su target group durante 2 minutos"
  namespace           = "AWS/ApplicationELB"
  metric_name         = "HealthyHostCount"
  dimensions          = { TargetGroup = each.value.tg, LoadBalancer = each.value.lb }
  statistic           = "Minimum"
  period              = 60
  evaluation_periods  = 2
  threshold           = 1
  comparison_operator = "LessThanThreshold"
  treat_missing_data  = "breaching" # sin datos = nadie reporta sano
}

resource "aws_cloudwatch_metric_alarm" "cpu" {
  for_each = local.servicios

  alarm_name          = "${var.name}-${each.key}-cpu-alta"
  alarm_description   = "El ${each.key} usó más del 80 % de CPU durante 3 minutos"
  namespace           = "AWS/ECS"
  metric_name         = "CPUUtilization"
  dimensions          = { ClusterName = var.cluster_name, ServiceName = each.value }
  statistic           = "Average"
  period              = 60
  evaluation_periods  = 3
  threshold           = 80
  comparison_operator = "GreaterThanThreshold"
  treat_missing_data  = "notBreaching"
}

# ---------------------------------------------------------------------------
# Dashboard
# ---------------------------------------------------------------------------

resource "aws_cloudwatch_dashboard" "este" {
  dashboard_name = var.name

  dashboard_body = jsonencode({
    widgets = [
      {
        type = "text", x = 0, y = 0, width = 24, height = 2
        properties = {
          markdown = "## Gastico · ${var.environment}\nUsuario → ALB público → **frontend** (NiceGUI) → ALB interno → **backend** (FastAPI). Métricas de AWS por minuto; las alarmas están abajo."
        }
      },
      {
        type = "metric", x = 0, y = 2, width = 8, height = 6
        properties = merge(local.grafico, {
          title   = "Peticiones por minuto"
          stat    = "Sum"
          metrics = [["AWS/ApplicationELB", "RequestCount", local.alb[0], local.alb[1], { label = "frontend" }]]
        })
      },
      {
        type = "metric", x = 8, y = 2, width = 8, height = 6
        properties = merge(local.grafico, {
          title = "Errores por minuto"
          stat  = "Sum"
          metrics = [
            ["AWS/ApplicationELB", "HTTPCode_Target_5XX_Count", local.alb[0], local.alb[1], { label = "5xx del frontend", color = "#d62728" }],
            ["AWS/ApplicationELB", "HTTPCode_ELB_5XX_Count", local.alb[0], local.alb[1], { label = "5xx del ALB (sin tarea sana)", color = "#ff7f0e" }],
            ["AWS/ApplicationELB", "HTTPCode_Target_5XX_Count", local.alb_back[0], local.alb_back[1], { label = "5xx del backend", color = "#9467bd" }],
            ["AWS/ApplicationELB", "HTTPCode_Target_4XX_Count", local.alb_back[0], local.alb_back[1], { label = "4xx del backend (validaciones)", color = "#bcbd22" }],
          ]
        })
      },
      {
        type = "metric", x = 16, y = 2, width = 8, height = 6
        properties = merge(local.grafico, {
          title = "Latencia (segundos)"
          metrics = [
            ["AWS/ApplicationELB", "TargetResponseTime", local.alb[0], local.alb[1], { stat = "p95", label = "frontend p95" }],
            ["AWS/ApplicationELB", "TargetResponseTime", local.alb[0], local.alb[1], { stat = "p50", label = "frontend p50" }],
            ["AWS/ApplicationELB", "TargetResponseTime", local.alb_back[0], local.alb_back[1], { stat = "p95", label = "backend p95" }],
          ]
          annotations = { horizontal = [{ label = "umbral k6", value = var.latencia_p95_maxima, color = "#d62728" }] }
        })
      },
      {
        type = "metric", x = 0, y = 8, width = 8, height = 6
        properties = merge(local.grafico, {
          title = "Tareas sanas en el ALB"
          stat  = "Minimum"
          metrics = [
            concat(["AWS/ApplicationELB", "HealthyHostCount"], local.tg_front, [{ label = "frontend sanas", color = "#2ca02c" }]),
            concat(["AWS/ApplicationELB", "UnHealthyHostCount"], local.tg_front, [{ label = "frontend caídas", color = "#d62728" }]),
            concat(["AWS/ApplicationELB", "HealthyHostCount"], local.tg_back, [{ label = "backend sanas", color = "#17becf" }]),
            concat(["AWS/ApplicationELB", "UnHealthyHostCount"], local.tg_back, [{ label = "backend caídas", color = "#ff7f0e" }]),
          ]
          yAxis = { left = { min = 0 } }
        })
      },
      {
        type = "metric", x = 8, y = 8, width = 8, height = 6
        properties = merge(local.grafico, {
          title   = "CPU de ECS (%)"
          stat    = "Average"
          metrics = [for k, s in local.servicios : ["AWS/ECS", "CPUUtilization", "ClusterName", var.cluster_name, "ServiceName", s, { label = k }]]
          yAxis   = { left = { min = 0, max = 100 } }
        })
      },
      {
        type = "metric", x = 16, y = 8, width = 8, height = 6
        properties = merge(local.grafico, {
          title   = "Memoria de ECS (%)"
          stat    = "Average"
          metrics = [for k, s in local.servicios : ["AWS/ECS", "MemoryUtilization", "ClusterName", var.cluster_name, "ServiceName", s, { label = k }]]
          yAxis   = { left = { min = 0, max = 100 } }
        })
      },
      {
        type = "alarm", x = 0, y = 14, width = 24, height = 3
        properties = {
          title = "Alarmas"
          alarms = concat(
            [aws_cloudwatch_metric_alarm.errores_5xx.arn, aws_cloudwatch_metric_alarm.latencia.arn],
            [for a in aws_cloudwatch_metric_alarm.tareas_caidas : a.arn],
            [for a in aws_cloudwatch_metric_alarm.cpu : a.arn],
          )
        }
      },
      {
        type = "log", x = 0, y = 17, width = 24, height = 6
        properties = {
          title  = "Errores recientes en los logs (frontend y backend)"
          region = var.region
          view   = "table"
          query  = "SOURCE ${join(" | SOURCE ", [for g in var.log_group_names : "'${g}'"])} | fields @timestamp, @log, @message | filter @message like /(?i)(error|exception|traceback)/ | sort @timestamp desc | limit 20"
        }
      },
    ]
  })
}
