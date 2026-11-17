# Backend S3, compartido por los workspaces "staging" y "production" (cada uno con su propio
# estado dentro del mismo bucket: S3 antepone "env:/<workspace>/" a la key automáticamente).
#
# El bucket NO lo crea Terraform (problema del huevo y la gallina: el backend necesita existir
# antes de poder guardar el estado). Se crea una sola vez a mano, ver infra/README.md.
#
# "use_lockfile" es el bloqueo nativo de S3 (Terraform >= 1.10): no hace falta tabla de DynamoDB.
#
# El bucket NO se pone aquí: depende de qué cuenta de Learner Lab despliega (los secrets de AWS
# del CD tienen que ser de esa misma cuenta), y eso puede cambiar entre quien corre esto a mano y
# el pipeline. Se pasa siempre con -backend-config al hacer init:
#   terraform init -backend-config=backend.hcl -backend-config="bucket=gastico-tfstate-<cuenta>"

key          = "gastico/terraform.tfstate"
region       = "us-east-1"
encrypt      = true
use_lockfile = true
