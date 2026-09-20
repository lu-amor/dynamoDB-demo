#!/usr/bin/env bash
# Sube TEMPORALMENTE la capacidad provisionada para forzar >=2 particiones
# físicas reales (fórmula de AWS: particiones = techo(RCU/3000 + WCU/1000)).
# Con 2000 WCU / 100 RCU -> 2000/1000 = 2 particiones.
#
# Corre esto justo antes de la sección de sharding del demo, y corre
# scale_down.sh apenas termines esa sección. Ver RUNBOOK.md para el costo.
set -euo pipefail

REGION="${AWS_REGION:-us-east-1}"
TABLE_NAME="${TABLE_NAME:-EventosBigData}"
TARGET_WCU="${TARGET_WCU:-2000}"
TARGET_RCU="${TARGET_RCU:-100}"

echo "==> Esto sube '$TABLE_NAME' a ${TARGET_RCU} RCU / ${TARGET_WCU} WCU (~2 particiones)."
echo "    Costo aproximado por minuto a esta capacidad: ver RUNBOOK.md."
echo "    NO olvides correr scale_down.sh apenas termines la sección de sharding."
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

echo "==> Esperando a que la tabla vuelva a ACTIVE con la nueva capacidad..."
aws dynamodb wait table-exists --region "$REGION" --table-name "$TABLE_NAME"

echo "==> Listo. Tabla en ${TARGET_RCU} RCU / ${TARGET_WCU} WCU. Hora de inicio: $(date)"
echo "    Recuerda: scale_down.sh apenas termines esta sección."
