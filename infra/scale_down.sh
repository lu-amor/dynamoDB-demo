#!/usr/bin/env bash
# Vuelve la tabla a su capacidad baseline (barata) apenas termine la sección
# de sharding. Corre esto SIEMPRE antes de pasar a la sección de escalamiento,
# para que esa demo también arranque desde una base baja y barata.
set -euo pipefail

REGION="${AWS_REGION:-us-east-1}"
TABLE_NAME="${TABLE_NAME:-EventosBigData}"
BASELINE_CAPACITY="${BASELINE_CAPACITY:-5}"

echo "==> Bajando '$TABLE_NAME' de vuelta a baseline ${BASELINE_CAPACITY}/${BASELINE_CAPACITY} RCU/WCU"

aws dynamodb update-table \
  --region "$REGION" \
  --table-name "$TABLE_NAME" \
  --provisioned-throughput ReadCapacityUnits="$BASELINE_CAPACITY",WriteCapacityUnits="$BASELINE_CAPACITY" \
  --output table

aws dynamodb wait table-exists --region "$REGION" --table-name "$TABLE_NAME"
echo "==> Listo. Tabla de vuelta a ${BASELINE_CAPACITY}/${BASELINE_CAPACITY}. Hora: $(date)"
