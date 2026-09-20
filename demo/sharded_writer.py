#!/usr/bin/env python3
"""Misma carga que hot_key_writer.py pero con partition key de alta cardinalidad.

Al repartirse entre varias particiones, debería throttlear mucho menos (o nada)
comparado con hot_key_writer.py corriendo la misma cantidad de tiempo/workers.
Esa comparación en vivo es la prueba de que la partition key determina cómo
se reparten físicamente los datos.

Uso: python sharded_writer.py [duracion_segundos] [workers]
"""
import random
import sys
import threading
import time
import uuid

from botocore.exceptions import ClientError

from common import get_table

DURATION_SECONDS = int(sys.argv[1]) if len(sys.argv) > 1 else 20
WORKERS = int(sys.argv[2]) if len(sys.argv) > 2 else 40

counts = {"ok": 0, "throttled": 0}
lock = threading.Lock()
stop_at = 0.0


def worker():
    table = get_table()
    while time.time() < stop_at:
        pk = f"device#{random.randint(0, 9999)}"
        try:
            table.put_item(
                Item={"pk": pk, "sk": str(uuid.uuid4()), "payload": "x" * 200},
                ReturnConsumedCapacity="NONE",
            )
            with lock:
                counts["ok"] += 1
        except ClientError as e:
            if e.response["Error"]["Code"] == "ProvisionedThroughputExceededException":
                with lock:
                    counts["throttled"] += 1
            else:
                raise


def main():
    global stop_at
    print(f"== sharded_writer: partition key de alta cardinalidad (device#0-9999)  {WORKERS} workers  {DURATION_SECONDS}s ==")
    start = time.time()
    stop_at = start + DURATION_SECONDS
    threads = [threading.Thread(target=worker, daemon=True) for _ in range(WORKERS)]
    for t in threads:
        t.start()
    while time.time() < stop_at:
        time.sleep(1)
        elapsed = time.time() - start
        with lock:
            ok, throttled = counts["ok"], counts["throttled"]
        print(f"\r[{elapsed:5.1f}s] ok={ok:6d}  throttled={throttled:6d}", end="", flush=True)
    for t in threads:
        t.join(timeout=5)
    print()
    ok, throttled = counts["ok"], counts["throttled"]
    total = ok + throttled
    pct = (100 * throttled / total) if total else 0
    print(f"== resultado final: ok={ok}  throttled={throttled}  ({pct:.1f}% de escrituras throttled) ==")


if __name__ == "__main__":
    main()
