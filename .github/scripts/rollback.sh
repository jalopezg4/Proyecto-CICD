#!/usr/bin/env bash
# Rollback de Gastico (paso 13 del plan, D8/D9): vuelve a aplicar el mismo Terraform con otra
# version, en vez de un mecanismo aparte. Lo usan:
#   - el rollback automatico del CD/release (nivel 2): el smoke falla despues de un deploy que
#     si quedo estable, y se vuelve al last-good.
#   - el workflow manual de rollback (nivel 3, "boton de panico").
#
# Requiere en el entorno: credenciales de AWS ya configuradas y TF_STATE_BUCKET.
# Uso: rollback.sh <ambiente> <version>
#   ej: TF_STATE_BUCKET=gastico-tfstate-... rollback.sh staging sha-abc1234
set -euo pipefail

AMBIENTE="$1"
VERSION="$2"

if [ "$VERSION" = "sin-desplegar" ]; then
  echo "::error::No hay last-good de $AMBIENTE todavia (nunca se desplego con exito): no hay a que volver"
  exit 1
fi

cd infra
terraform init -input=false -backend-config=backend.hcl -backend-config="bucket=${TF_STATE_BUCKET}"
terraform workspace select -or-create "$AMBIENTE"
terraform apply -input=false -auto-approve \
  -var="backend_image_tag=$VERSION" -var="frontend_image_tag=$VERSION" -var="app_version=$VERSION"

echo "frontend_url=$(terraform output -raw frontend_url)" >> "$GITHUB_OUTPUT"

aws ssm put-parameter --name "$(terraform output -raw ssm_current_name)" \
  --value "$VERSION" --type String --overwrite >/dev/null
