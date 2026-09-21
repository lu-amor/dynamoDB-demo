import os

import boto3
from botocore.config import Config

REGION = os.environ.get("AWS_REGION", "us-east-1")
TABLE_NAME = os.environ.get("TABLE_NAME", "EventosBigData")

# Los scripts de carga comparten un único cliente entre cientos de threads
# (ver hot_key_writer.py / sharded_writer.py); el pool de conexiones default
# de botocore (10) se satura mucho antes que el WCU de la tabla y produce un
# cuello de botella artificial en el cliente. Y max_attempts=1 desactiva los
# reintentos automáticos de botocore ante throttling: si no, cada request
# throttled se reintenta internamente con backoff (varios segundos) antes de
# devolvernos la excepción, y el demo se "congela" en vez de mostrar el
# throttling en vivo.
_BOTO_CONFIG = Config(max_pool_connections=300, retries={"max_attempts": 1})


def get_table():
    dynamodb = boto3.resource("dynamodb", region_name=REGION, config=_BOTO_CONFIG)
    return dynamodb.Table(TABLE_NAME)


def get_client():
    return boto3.client("dynamodb", region_name=REGION, config=_BOTO_CONFIG)
