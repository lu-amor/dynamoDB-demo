#!/usr/bin/env bash
set -euo pipefail

REGION="${AWS_REGION:-us-east-1}"
TABLE_NAME="${TABLE_NAME:-EventosBigData}"
BASELINE_CAPACITY="${BASELINE_CAPACITY:-5}"

echo "Bajando '$TABLE_NAME' a ${BASELINE_CAPACITY}/${BASELINE_CAPACITY} RCU/WCU"

aws dynamodb update-table \
    --region "$REGION" \
    --table-name "$TABLE_NAME" \
    --provisioned-throughput ReadCapacityUnits="$BASELINE_CAPACITY",WriteCapacityUnits="$BASELINE_CAPACITY" \
    --output table

aws dynamodb wait table-exists --region "$REGION" --table-name "$TABLE_NAME"
echo "Listo"
