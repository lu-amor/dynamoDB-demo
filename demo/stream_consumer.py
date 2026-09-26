#!/usr/bin/env python3
"""
Lee el DynamoDB Stream de la tabla en vivo e imprime los cambios.
Esto podría utilizarse como input para pipelines de big data, viendo los cambios en la tabla en tiempo real
(por ejemplo recibiendo todos los nuevos petidos que llegan a la tabla).

Uso: python stream_consumer.py
Mientras corre, realizar ABM en la tabla para ver cómo aparecen los eventos.
"""
import time

import boto3

from common import REGION, TABLE_NAME


def main():
    dynamodb = boto3.client("dynamodb", region_name=REGION)
    streams = boto3.client("dynamodbstreams", region_name=REGION)

    table_desc = dynamodb.describe_table(TableName=TABLE_NAME)["Table"]
    stream_arn = table_desc.get("LatestStreamArn")
    if not stream_arn:
        raise SystemExit("La tabla no tiene streams habilitados.")

    print(f"== escuchando stream de '{TABLE_NAME}' ==\n{stream_arn}\n")

    shards = streams.describe_stream(StreamArn=stream_arn)["StreamDescription"]["Shards"]
    iterators = []
    for shard in shards:
        it = streams.get_shard_iterator(
            StreamArn=stream_arn,
            ShardId=shard["ShardId"],
            ShardIteratorType="LATEST",
        )["ShardIterator"]
        iterators.append(it)

    print("Ctrl+C para salir.\n")

    try:
        while True:
            next_iterators = []
            for it in iterators:
                resp = streams.get_records(ShardIterator=it, Limit=100)
                for record in resp.get("Records", []):
                    event = record["eventName"]
                    keys = record["dynamodb"].get("Keys", {})
                    print(f"[{event}] {keys}")
                if resp.get("NextShardIterator"):
                    next_iterators.append(resp["NextShardIterator"])
            iterators = next_iterators
            time.sleep(1)
    except KeyboardInterrupt:


if __name__ == "__main__":
    main()
