#!/usr/bin/env bash
# Crea la tabla base del demo en modo barato (baseline 5/5) con TTL, Streams
# y Application Auto Scaling configurado. Costo mientras está en baseline:
# centavos (ver RUNBOOK.md para el desglose completo).
set -euo pipefail

REGION="${AWS_REGION:-us-east-1}"
TABLE_NAME="${TABLE_NAME:-EventosBigData}"
BASELINE_CAPACITY=5
MAX_CAPACITY=40

echo "==> Creando tabla '$TABLE_NAME' en $REGION (baseline ${BASELINE_CAPACITY}/${BASELINE_CAPACITY} RCU/WCU)"

aws dynamodb create-table \
  --region "$REGION" \
  --table-name "$TABLE_NAME" \
  --attribute-definitions AttributeName=pk,AttributeType=S AttributeName=sk,AttributeType=S \
  --key-schema AttributeName=pk,KeyType=HASH AttributeName=sk,KeyType=RANGE \
  --billing-mode PROVISIONED \
  --provisioned-throughput ReadCapacityUnits=$BASELINE_CAPACITY,WriteCapacityUnits=$BASELINE_CAPACITY \
  --stream-specification StreamEnabled=true,StreamViewType=NEW_AND_OLD_IMAGES \
  --tags Key=proyecto,Value=demo-dynamodb-unidad3 \
  --output table

echo "==> Esperando a que la tabla quede ACTIVE..."
aws dynamodb wait table-exists --region "$REGION" --table-name "$TABLE_NAME"

echo "==> Habilitando TTL sobre el atributo 'ttl' (buena práctica: expirar datos automáticamente)"
aws dynamodb update-time-to-live \
  --region "$REGION" \
  --table-name "$TABLE_NAME" \
  --time-to-live-specification "Enabled=true,AttributeName=ttl" \
  --output table

echo "==> Registrando scalable targets para Application Auto Scaling (min=$BASELINE_CAPACITY, max=$MAX_CAPACITY)"
aws application-autoscaling register-scalable-target \
  --region "$REGION" \
  --service-namespace dynamodb \
  --resource-id "table/$TABLE_NAME" \
  --scalable-dimension dynamodb:table:ReadCapacityUnits \
  --min-capacity $BASELINE_CAPACITY \
  --max-capacity $MAX_CAPACITY

aws application-autoscaling register-scalable-target \
  --region "$REGION" \
  --service-namespace dynamodb \
  --resource-id "table/$TABLE_NAME" \
  --scalable-dimension dynamodb:table:WriteCapacityUnits \
  --min-capacity $BASELINE_CAPACITY \
  --max-capacity $MAX_CAPACITY

echo "==> Creando policies de target tracking (70% de utilización)"
aws application-autoscaling put-scaling-policy \
  --region "$REGION" \
  --service-namespace dynamodb \
  --resource-id "table/$TABLE_NAME" \
  --scalable-dimension dynamodb:table:ReadCapacityUnits \
  --policy-name "${TABLE_NAME}-read-autoscaling" \
  --policy-type TargetTrackingScaling \
  --target-tracking-scaling-policy-configuration '{"TargetValue":70.0,"PredefinedMetricSpecification":{"PredefinedMetricType":"DynamoDBReadCapacityUtilization"},"ScaleInCooldown":60,"ScaleOutCooldown":60}' \
  >/dev/null

aws application-autoscaling put-scaling-policy \
  --region "$REGION" \
  --service-namespace dynamodb \
  --resource-id "table/$TABLE_NAME" \
  --scalable-dimension dynamodb:table:WriteCapacityUnits \
  --policy-name "${TABLE_NAME}-write-autoscaling" \
  --policy-type TargetTrackingScaling \
  --target-tracking-scaling-policy-configuration '{"TargetValue":70.0,"PredefinedMetricSpecification":{"PredefinedMetricType":"DynamoDBWriteCapacityUtilization"},"ScaleInCooldown":60,"ScaleOutCooldown":60}' \
  >/dev/null

echo
echo "==> Listo. Tabla '$TABLE_NAME' creada con baseline ${BASELINE_CAPACITY}/${BASELINE_CAPACITY} y auto scaling configurado."
aws dynamodb describe-table --region "$REGION" --table-name "$TABLE_NAME" \
  --query 'Table.{Status:TableStatus,RCU:ProvisionedThroughput.ReadCapacityUnits,WCU:ProvisionedThroughput.WriteCapacityUnits,Stream:LatestStreamArn}' \
  --output table
