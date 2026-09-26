#!/usr/bin/env bash
set -euo pipefail

REGION="${AWS_REGION:-us-east-1}"
TABLE_NAME="${TABLE_NAME:-EventosBigData}"
TARGET_WCU="${TARGET_WCU:-2000}"
TARGET_RCU="${TARGET_RCU:-100}"

echo "Sube '$TABLE_NAME' a ${TARGET_RCU} RCU / ${TARGET_WCU} WCU para generar dos particiones."
read -r -p "Escribe 'si' para continuar: " CONFIRM
if [[ "$CONFIRM" != "si" ]]; then
    echo "Cancelado."
    exit 1
fi

aws dynamodb update-table \
    --region "$REGION" \
    --table-name "$TABLE_NAME" \
    --provisioned-throughput ReadCapacityUnits="$TARGET_RCU",WriteCapacityUnits="$TARGET_WCU" \
    --output table

echo "Esperando que finalice el update"
aws dynamodb wait table-exists --region "$REGION" --table-name "$TABLE_NAME"

echo "Listo."
