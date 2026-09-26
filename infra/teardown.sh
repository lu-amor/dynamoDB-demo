#!/usr/bin/env bash
set -euo pipefail

REGION="${AWS_REGION:-us-east-1}"
TABLE_NAME="${TABLE_NAME:-EventosBigData}"

read -r -p "Escribir 'borrar' para confirmar: " CONFIRM
if [[ "$CONFIRM" != "borrar" ]]; then
    echo "Cancelado."
    exit 1
fi

aws application-autoscaling delete-scaling-policy --region "$REGION" --service-namespace dynamodb \
    --resource-id "table/$TABLE_NAME" --scalable-dimension dynamodb:table:ReadCapacityUnits \
    --policy-name "${TABLE_NAME}-read-autoscaling" 2>/dev/null || true

aws application-autoscaling delete-scaling-policy --region "$REGION" --service-namespace dynamodb \
    --resource-id "table/$TABLE_NAME" --scalable-dimension dynamodb:table:WriteCapacityUnits \
    --policy-name "${TABLE_NAME}-write-autoscaling" 2>/dev/null || true

aws application-autoscaling deregister-scalable-target --region "$REGION" --service-namespace dynamodb \
    --resource-id "table/$TABLE_NAME" --scalable-dimension dynamodb:table:ReadCapacityUnits 2>/dev/null || true

aws application-autoscaling deregister-scalable-target --region "$REGION" --service-namespace dynamodb \
    --resource-id "table/$TABLE_NAME" --scalable-dimension dynamodb:table:WriteCapacityUnits 2>/dev/null || true

aws dynamodb delete-table --region "$REGION" --table-name "$TABLE_NAME" >/dev/null

aws dynamodb wait table-not-exists --region "$REGION" --table-name "$TABLE_NAME"

echo "Listo"
