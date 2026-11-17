# Backend S3, compartido por los workspaces "staging" y "production" (cada uno con su propio
# estado dentro del mismo bucket: S3 antepone "env:/<workspace>/" a la key automáticamente).
#
# El bucket NO lo crea Terraform (problema del huevo y la gallina: el backend necesita existir
# antes de poder guardar el estado). Se crea una sola vez a mano, ver infra/README.md.
#
# "use_lockfile" es el bloqueo nativo de S3 (Terraform >= 1.10): no hace falta tabla de DynamoDB.
#
# Rellenar <BUCKET> después de crearlo (paso 1 del README) y correr:
#   terraform init -backend-config=backend.hcl

bucket       = "<BUCKET>"
key          = "gastico/terraform.tfstate"
region       = "us-east-1"
encrypt      = true
use_lockfile = true
