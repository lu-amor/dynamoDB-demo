#!/usr/bin/env bash
# Borra TODO lo creado por deploy.sh: scaling policies, scalable targets y la
# tabla (esto también elimina el stream y cualquier índice asociado).
# Corre esto apenas termines de presentar. No dejes nada corriendo en AWS.
set -euo pipefail

REGION="${AWS_REGION:-us-east-1}"
TABLE_NAME="${TABLE_NAME:-EventosBigData}"

echo "==> Esto borra COMPLETAMENTE la tabla '$TABLE_NAME', sus scaling policies y scalable targets."
read -r -p "Escribe 'borrar' para confirmar: " CONFIRM
if [[ "$CONFIRM" != "borrar" ]]; then
  echo "Cancelado."
  exit 1
fi

echo "==> Eliminando scaling policies..."
aws application-autoscaling delete-scaling-policy --region "$REGION" --service-namespace dynamodb \
  --resource-id "table/$TABLE_NAME" --scalable-dimension dynamodb:table:ReadCapacityUnits \
  --policy-name "${TABLE_NAME}-read-autoscaling" 2>/dev/null || true

aws application-autoscaling delete-scaling-policy --region "$REGION" --service-namespace dynamodb \
  --resource-id "table/$TABLE_NAME" --scalable-dimension dynamodb:table:WriteCapacityUnits \
  --policy-name "${TABLE_NAME}-write-autoscaling" 2>/dev/null || true

echo "==> Deregistrando scalable targets..."
aws application-autoscaling deregister-scalable-target --region "$REGION" --service-namespace dynamodb \
  --resource-id "table/$TABLE_NAME" --scalable-dimension dynamodb:table:ReadCapacityUnits 2>/dev/null || true

aws application-autoscaling deregister-scalable-target --region "$REGION" --service-namespace dynamodb \
  --resource-id "table/$TABLE_NAME" --scalable-dimension dynamodb:table:WriteCapacityUnits 2>/dev/null || true

echo "==> Borrando la tabla (incluye stream y cualquier GSI asociado)..."
aws dynamodb delete-table --region "$REGION" --table-name "$TABLE_NAME" >/dev/null

echo "==> Esperando confirmación de borrado..."
aws dynamodb wait table-not-exists --region "$REGION" --table-name "$TABLE_NAME"

echo
echo "==> Listo. '$TABLE_NAME' y todos sus recursos asociados fueron eliminados. Hora: $(date)"
echo "==> Verifica en la consola de AWS (DynamoDB > Tables y CloudWatch > Alarms) que no quede nada."
