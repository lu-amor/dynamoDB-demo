#!/usr/bin/env python3
"""Escribe ítems muy rápido usando UNA sola partition key fija.

Correr esto con la tabla en la capacidad de sharding (scale_up_for_sharding.sh,
2000 WCU / 2 particiones). Toda la carga cae en una única partición, así que
debería superar su cuota y producir ProvisionedThroughputExceededException
("throttled") en vivo.

Uso: python hot_key_writer.py [duracion_segundos] [workers]
"""
import sys
import threading
import time
import uuid

from botocore.exceptions import ClientError

from common import get_table

DURATION_SECONDS = int(sys.argv[1]) if len(sys.argv) > 1 else 20
WORKERS = int(sys.argv[2]) if len(sys.argv) > 2 else 40
FIXED_PK = "hot-partition-demo"

counts = {"ok": 0, "throttled": 0}
errors = []
lock = threading.Lock()
stop_at = 0.0


def worker(table):
    while time.time() < stop_at:
        try:
            table.put_item(
                Item={"pk": FIXED_PK, "sk": str(uuid.uuid4()), "payload": "x" * 200},
                ReturnConsumedCapacity="NONE",
            )
            with lock:
                counts["ok"] += 1
        except ClientError as e:
            if e.response["Error"]["Code"] == "ProvisionedThroughputExceededException":
                with lock:
                    counts["throttled"] += 1
            else:
                with lock:
                    errors.append(str(e))
                return


def main():
    global stop_at
    print(f"== hot_key_writer: pk fija='{FIXED_PK}'  {WORKERS} workers  {DURATION_SECONDS}s ==")
    table = get_table()  # un solo cliente compartido: crear uno por thread serializa el arranque bajo el GIL
    start = time.time()
    stop_at = start + DURATION_SECONDS
    threads = [threading.Thread(target=worker, args=(table,), daemon=True) for _ in range(WORKERS)]
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
    if errors:
        print(f"== {len(errors)} workers murieron por un error no esperado (no throttling), ejemplo: {errors[0]}")


if __name__ == "__main__":
    main()
