## Staging: sha-98fdf425a6bc285c3ebc1863dbf5449dc5acdaf1

**URL:** http://gastico-staging-alb-871422411.us-east-1.elb.amazonaws.com

**/health:** `{"status":"ok","version":"sha-98fdf425a6bc285c3ebc1863dbf5449dc5acdaf1","backend":"ok"}`

### Servicios de ECS
| Servicio | Estado | Tareas corriendo / deseadas |
|---|---|---|
| gastico-staging-backend | ACTIVE | 1 / 1 |
| gastico-staging-frontend | ACTIVE | 1 / 1 |

### Target groups del ALB
| Target group | Salud |
|---|---|
| gastico-staging-tg | healthy |
| gastico-staging-backend-tg | healthy |

### Backend inaccesible desde internet
Su security group (`gastico-staging-backend`) solo acepta el puerto 8000 desde el ALB interno:
```
--------------------------------------------
|          DescribeSecurityGroups          |
+------+------------------------+----------+
| cidr |         desde          | puerto   |
+------+------------------------+----------+
|  None|  sg-017d1eb25a75cb756  |  8000    |
+------+------------------------+----------+
```

### Escaneo de ECR (tag sha-98fdf425a6bc285c3ebc1863dbf5449dc5acdaf1)
| Repositorio | Hallazgos por severidad |
|---|---|
| gastico-backend | escaneo no disponible (None) |
| gastico-frontend | escaneo no disponible (None) |

_ECR también reporta vulnerabilidades sin arreglo disponible; Trivy en el CI solo falla con las que tienen arreglo._

### SSM (base del rollback)
| Parámetro | Valor |
|---|---|
| /gastico/staging/current | sha-98fdf425a6bc285c3ebc1863dbf5449dc5acdaf1 |
| /gastico/staging/last-good | sha-98fdf425a6bc285c3ebc1863dbf5449dc5acdaf1 |
