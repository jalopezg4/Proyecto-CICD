#!/usr/bin/env bash
# Evidencia del estado de AWS de un ambiente, en Markdown (para el resumen de un run).
# La usan el CD de staging y el release a producción, así que el equipo ve el estado de la
# infraestructura en la pestaña Actions sin necesitar credenciales de AWS.
#
# Uso: evidencia-aws.sh <ambiente> <versión> <url-del-alb>
#   ej: evidencia-aws.sh staging sha-0d9ed2d... http://gastico-staging-alb-....elb.amazonaws.com
set -uo pipefail

AMBIENTE="$1"
VERSION="$2"
BASE_URL="$3"
NOMBRE="gastico-${AMBIENTE}"

echo "## ${AMBIENTE}: ${VERSION}"
echo
echo "**URL:** ${BASE_URL}"
echo
echo "**/health:** \`$(curl -s -m 10 "${BASE_URL}/health" || echo 'sin respuesta')\`"
echo

echo "### Servicios de ECS"
echo "| Servicio | Estado | Tareas corriendo / deseadas |"
echo "|---|---|---|"
aws ecs describe-services --cluster "${NOMBRE}" \
  --services "${NOMBRE}-backend" "${NOMBRE}-frontend" \
  --query 'services[].[serviceName,status,runningCount,desiredCount]' --output text |
  while read -r nombre estado corriendo deseadas; do
    echo "| ${nombre} | ${estado} | ${corriendo} / ${deseadas} |"
  done
echo

echo "### Target groups del ALB"
echo "| Target group | Salud |"
echo "|---|---|"
for tg in "${NOMBRE}-tg" "${NOMBRE}-backend-tg"; do
  arn=$(aws elbv2 describe-target-groups --names "${tg}" --query 'TargetGroups[0].TargetGroupArn' --output text)
  salud=$(aws elbv2 describe-target-health --target-group-arn "${arn}" \
    --query 'TargetHealthDescriptions[].TargetHealth.State' --output text)
  echo "| ${tg} | ${salud} |"
done
echo

echo "### Backend inaccesible desde internet"
echo "Su security group (\`${NOMBRE}-backend\`) solo acepta el puerto 8000 desde el ALB interno:"
echo '```'
aws ec2 describe-security-groups --filters "Name=group-name,Values=${NOMBRE}-backend" \
  --query 'SecurityGroups[0].IpPermissions[].{puerto:FromPort,desde:UserIdGroupPairs[0].GroupId,cidr:IpRanges[0].CidrIp}' \
  --output table
echo '```'
echo

echo "### Escaneo de ECR (tag ${VERSION})"
echo "| Repositorio | Hallazgos por severidad |"
echo "|---|---|"
for repo in gastico-backend gastico-frontend; do
  # El escaneo al subir tarda unos segundos en aparecer: se reintenta hasta 2 minutos
  conteo=""
  estado=""
  for _ in $(seq 1 12); do
    # Con escaneo básico, describe-images no trae el estado: se lee del propio escaneo
    estado=$(aws ecr describe-image-scan-findings --repository-name "${repo}" --image-id imageTag="${VERSION}" \
      --query 'imageScanStatus.status' --output text 2>/dev/null)
    if [ "${estado}" = "COMPLETE" ]; then
      conteo=$(aws ecr describe-image-scan-findings --repository-name "${repo}" --image-id imageTag="${VERSION}" \
        --query 'imageScanFindings.findingSeverityCounts' --output json | tr -d '\n ')
      break
    fi
    sleep 10
  done
  echo "| ${repo} | ${conteo:-escaneo no disponible (${estado})} |"
done
echo
echo "_ECR también reporta vulnerabilidades sin arreglo disponible; Trivy en el CI solo falla con las que tienen arreglo._"
echo

echo "### Monitoreo (alarmas de CloudWatch)"
echo "Dashboard: [${NOMBRE}](https://us-east-1.console.aws.amazon.com/cloudwatch/home?region=us-east-1#dashboards/dashboard/${NOMBRE}) (se abre con la sesión del Learner Lab)"
echo
echo "| Alarma | Estado |"
echo "|---|---|"
aws cloudwatch describe-alarms --alarm-name-prefix "${NOMBRE}-" \
  --query 'MetricAlarms[].[AlarmName,StateValue]' --output text | tr -d '\r' |
  while read -r alarma estado; do
    case "${estado}" in
      OK) icono="✅" ;;
      ALARM) icono="🔴" ;;
      *) icono="⏳" ;; # INSUFFICIENT_DATA: recién creada o sin tráfico todavía
    esac
    echo "| ${alarma} | ${icono} ${estado} |"
  done
echo

echo "### SSM (base del rollback)"
echo "| Parámetro | Valor |"
echo "|---|---|"
for p in current last-good; do
  valor=$(aws ssm get-parameter --name "/gastico/${AMBIENTE}/${p}" --query Parameter.Value --output text 2>/dev/null)
  echo "| /gastico/${AMBIENTE}/${p} | ${valor:-no existe} |"
done
