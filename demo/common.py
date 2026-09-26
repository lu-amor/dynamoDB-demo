import os

import boto3
from botocore.config import Config

REGION = os.environ.get("AWS_REGION", "us-east-1")
TABLE_NAME = os.environ.get("TABLE_NAME", "EventosBigData")

_BOTO_CONFIG = Config(max_pool_connections=300, retries={"max_attempts": 1})


def get_table():
    dynamodb = boto3.resource("dynamodb", region_name=REGION, config=_BOTO_CONFIG)
    return dynamodb.Table(TABLE_NAME)


def get_client():
    return boto3.client("dynamodb", region_name=REGION, config=_BOTO_CONFIG)
