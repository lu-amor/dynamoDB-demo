#!/usr/bin/env python3
"""Genera carga sostenida por encima del baseline para disparar Application
Auto Scaling.

Correr esto con la tabla en su capacidad BASELINE (5/5), NO durante la
ventana de sharding (scale_down.sh primero). Mientras corre, muestra en la
consola de AWS (DynamoDB > tabla > Monitor, o CloudWatch) cómo
ConsumedWriteCapacityUnits sube y, unos minutos después, cómo la capacidad
provisionada reacciona sola.

Uso: python autoscale_load.py [duracion_segundos] [writes_por_segundo_objetivo]
"""
import random
import sys
import threading
import time
import uuid

from common import TABLE_NAME, get_client

DURATION_SECONDS = int(sys.argv[1]) if len(sys.argv) > 1 else 420
TARGET_WRITES_PER_SEC = int(sys.argv[2]) if len(sys.argv) > 2 else 15

client = get_client()
counts = {"ok": 0, "throttled": 0}
lock = threading.Lock()
stop_at = 0.0


def write_one():
    try:
        client.put_item(
            TableName=TABLE_NAME,
            Item={
                "pk": {"S": f"autoscale-demo#{random.randint(0, 999)}"},
                "sk": {"S": str(uuid.uuid4())},
                "payload": {"S": "x" * 200},
            },
            ReturnConsumedCapacity="NONE",
        )
        with lock:
            counts["ok"] += 1
    except client.exceptions.ProvisionedThroughputExceededException:
        with lock:
            counts["throttled"] += 1


def main():
    global stop_at
    print(f"== autoscale_load: ~{TARGET_WRITES_PER_SEC} writes/s durante {DURATION_SECONDS}s ==")
    print("   Mira en la consola de AWS la métrica ConsumedWriteCapacityUnits subiendo")
    print("   y, unos minutos después, Application Auto Scaling subiendo la capacidad.")
    start = time.time()
    stop_at = start + DURATION_SECONDS
    interval = 1.0 / TARGET_WRITES_PER_SEC
    next_report = start + 5
    while time.time() < stop_at:
        threading.Thread(target=write_one, daemon=True).start()
        time.sleep(interval)
        now = time.time()
        if now >= next_report:
            with lock:
                ok, throttled = counts["ok"], counts["throttled"]
            print(f"[{now - start:6.1f}s] ok={ok:6d}  throttled={throttled:6d}")
            next_report = now + 5
    time.sleep(2)
    with lock:
        ok, throttled = counts["ok"], counts["throttled"]
    print(f"== resultado final: ok={ok}  throttled={throttled} ==")


if __name__ == "__main__":
    main()
