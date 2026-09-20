# Guion del demo de DynamoDB — Unidad 3 (NoSQL)

Este documento reemplaza las diapositivas: es el guion que sigues en vivo,
comando por comando, con qué decir en cada parte. Cubre los 4 temas pedidos:
**sharding, buenas prácticas, escalamiento y aplicación en big data**.

## 0. Antes del día de la presentación

1. Instalar boto3 en el venv del curso:
   ```bash
   cd "big data"
   ./venv/bin/pip install -r "unidad 3 — NoSQL/dynamodb-demo/requirements.txt"
   ```
2. Confirmar que la AWS CLI ya tiene credenciales configuradas:
   ```bash
   aws sts get-caller-identity
   ```
3. **Hacer un ensayo completo** siguiendo todo este runbook de principio a
   fin (incluyendo el teardown) al menos una vez antes de presentar. Esto:
   - Confirma que el throttling del hot key se ve de forma confiable con tu
     conexión (si no throttlea lo suficiente, sube `WORKERS` en
     `hot_key_writer.py`/`sharded_writer.py`; si throttlea demasiado incluso
     con key repartida, baja `WORKERS`).
   - Confirma que Application Auto Scaling realmente dispara en un tiempo
     razonable (normalmente unos minutos después de sostener carga por
     encima del 70% del baseline).
   - Te deja con los tiempos reales para calcular cuánto durará cada sección
     el día de la presentación.
4. Activar todos los scripts de `infra/` como ejecutables una sola vez:
   ```bash
   chmod +x "unidad 3 — NoSQL/dynamodb-demo/infra/"*.sh
   ```

## 1. Costo — cuánto vas a gastar

Precios oficiales de DynamoDB Provisioned en `us-east-1` (confirmados en la
página de pricing de AWS): **WCU = $0.00065/hora**, **RCU = $0.00013/hora**.
El billing es por capacidad *provisionada* por hora, no por request — o sea
que "martillar" la tabla con tráfico no cuesta más, solo cuesta la capacidad
que tengas asignada en cada momento.

| Fase | Capacidad | Duración estimada | Costo |
|---|---|---|---|
| Baseline (deploy, entre secciones) | 5 RCU / 5 WCU | ~30-40 min en total | ~$0.003 |
| Ventana de sharding | 100 RCU / 2000 WCU | ~15 min | ~$0.33 |
| Autoscaling (sube de 5 a ~15-20 WCU) | promedio ~12 WCU | ~8 min | ~$0.001 |
| **Total por corrida completa** | | | **~$0.33-0.40** |

Si haces un ensayo completo Y la presentación real, multiplica por 2:
**~$0.70-0.80 en total**, muy por debajo de $1. El costo real depende de
cuánto tiempo te quedes en la ventana de sharding — por eso el script te
pide confirmación explícita antes de subir la capacidad, y por eso
**siempre corres `scale_down.sh` inmediatamente después de esa sección**.

## 2. Arrancar el demo

```bash
cd "unidad 3 — NoSQL/dynamodb-demo"
source "../../venv/bin/activate"   # o usa ../../venv/bin/python directamente
./infra/deploy.sh
```

**Qué decir:** "Voy a crear una tabla DynamoDB real. Fíjense que no defino un
schema de columnas — solo una partition key (`pk`) y una sort key (`sk`).
Eso es lo primero raro comparado con SQL: DynamoDB es schema-less para los
atributos, pero exige definir de entrada las claves con las que va a
particionar los datos."

## 3. Sharding — cómo DynamoDB reparte los datos

**Contexto para la audiencia:** DynamoDB divide una tabla en *particiones*
físicas independientes. Cada partición tiene su propia porción del
throughput total de la tabla. AWS calcula el número de particiones así:

```
particiones = techo( RCU/3000 + WCU/1000 )
particiones_por_storage = techo( tamaño_tabla_GB / 10 )
particiones_totales = max(particiones, particiones_por_storage)
```

Con la capacidad baseline (5/5) todo cabe en **una sola partición** — por
eso, para que se note la diferencia entre una partition key "mala" (hot key)
y una "buena" (bien distribuida), subimos la capacidad un momento:

```bash
./infra/scale_up_for_sharding.sh
```

Esto deja la tabla en 100 RCU / 2000 WCU → **2 particiones reales**
(2000/1000 = 2). Confirma escribiendo `si` cuando el script te lo pida.

### 3.1 Partition key mala (hot key)

```bash
cd demo
python hot_key_writer.py 20 40
```

Todas las escrituras usan la **misma** partition key
(`"hot-partition-demo"`), así que se concentran en una sola de las 2
particiones. Vas a ver el contador de `throttled` subir en vivo —
eso es `ProvisionedThroughputExceededException`, el error real que
lanza DynamoDB cuando una partición se satura, aunque la tabla en total
tenga capacidad de sobra.

**Qué decir:** "Aunque la tabla tiene 2000 unidades de escritura, esta
partición específica solo tiene su porción — y la estoy superando porque
todo el tráfico usa la misma clave."

### 3.2 Partition key buena (alta cardinalidad)

```bash
python sharded_writer.py 20 40
```

Mismo volumen, misma duración, mismos workers — pero cada escritura usa una
partition key distinta (`device#0` a `device#9999`). Debería throttlear
mucho menos (o nada), porque el tráfico se reparte entre las 2 particiones.

**Qué decir:** "Mismo código, misma carga — la única diferencia es el diseño
de la partition key. Esto es la lección número uno de modelado en
DynamoDB: la partition key determina literalmente cómo se reparten físicamente
tus datos."

### 3.3 Bajar la capacidad — IMPORTANTE

```bash
cd ..
./infra/scale_down.sh
```

**No sigas sin correr esto.** Deja la tabla otra vez en 5/5 antes de pasar
a la siguiente sección, para no seguir pagando la capacidad alta.

## 4. Buenas prácticas (ya aplicadas en este demo)

Repásalas hablando, señalando dónde están en el código/infra:

- **Partition key de alta cardinalidad** para evitar hot partitions — visto
  recién en 3.2.
- **TTL habilitado** (`infra/deploy.sh`, atributo `ttl`): DynamoDB puede
  expirar y borrar ítems automáticamente sin gastar capacidad de escritura,
  útil para datos con vencimiento (sesiones, eventos, caché).
- **Provisioned + Auto Scaling** en vez de capacidad fija a mano: se explica
  y se demuestra en la sección 5. Contraste: *On-Demand* es mejor cuando el
  tráfico es impredecible y no quieres gestionar capacidad en absoluto;
  *Provisioned + Auto Scaling* es más barato cuando el patrón de tráfico es
  medianamente previsible.
- **Permisos mínimos (IAM least privilege)**: mira
  `iam/demo-least-privilege-policy.json` — una aplicación que solo escribe y
  lee la tabla del demo NO necesita permisos de administrador ni acceso a
  otras tablas. Contrástalo con las credenciales de tu usuario (las que usan
  `deploy.sh`/`teardown.sh`), que sí son administrativas porque crean y
  borran infraestructura.
- **Monitoreo con CloudWatch**: se usa en vivo en la sección 5 para ver
  `ConsumedWriteCapacityUnits` vs. capacidad provisionada.

## 5. Escalamiento — Application Auto Scaling

Con la tabla ya en baseline (5/5, confirmado en 3.3):

```bash
cd demo
python autoscale_load.py 420 15
```

Esto sostiene ~15 escrituras/segundo (bien por encima del 70% del baseline
de 5 WCU) durante 7 minutos. Mientras corre:

1. Abre la consola de AWS → DynamoDB → tu tabla → pestaña **Monitor** (o
   CloudWatch → Metrics → DynamoDB) y muestra `ConsumedWriteCapacityUnits`
   subiendo por encima de la línea de capacidad provisionada.
2. Después de un par de minutos sostenidos por encima del umbral, deberías
   ver la capacidad provisionada subir sola (Application Auto Scaling
   reaccionando a la política de target tracking configurada en
   `deploy.sh`).

**Qué decir:** "No estoy tocando nada manualmente — configuré una policy de
'target tracking' al 70% de utilización cuando desplegué la tabla. AWS mismo
decide subir la capacidad cuando la demanda lo justifica, y la vuelve a bajar
sola cuando el tráfico cae."

Puedes cortar el script antes con `Ctrl+C` una vez que se vea el efecto en
la consola — no hace falta esperar los 7 minutos completos si ya se nota.

## 6. Aplicación en Big Data — DynamoDB Streams

En otra terminal (con el venv activado), deja corriendo:

```bash
cd demo
python stream_consumer.py
```

Y en otra terminal más (o reusando `sharded_writer.py` por 10 segundos),
genera algo de tráfico. Vas a ver los eventos `INSERT` aparecer en vivo en
`stream_consumer.py`.

**Qué decir:** "Esto que estoy leyendo es el Change Data Capture de la
tabla — cada escritura, actualización o borrado genera un evento en el
stream. Esta es exactamente la pieza que conecta DynamoDB con arquitecturas
de big data: en vez de leer el stream con un script como este, en producción
ese mismo stream alimenta un pipeline de analítica."

Diagrama conceptual para explicar (no se despliega, solo se narra):

```
   Apps escribiendo          DynamoDB Streams         Procesamiento          Data Lake / Analítica
  (transaccional, OLTP) ──▶  (CDC en tiempo real) ──▶  Kinesis / Firehose ──▶  S3 (Parquet/JSON)
                                                                                     │
                                                                              Athena / EMR / Glue
                                                                              (consultas batch/SQL
                                                                               sobre TB de historial)
```

**Punto clave para la audiencia:** DynamoDB es la base transaccional
(OLTP) de baja latencia — no está pensada para hacer analítica pesada sobre
TB de datos históricos. La forma en que "big data" y DynamoDB conviven es
justo este patrón: DynamoDB atiende el tráfico operacional en milisegundos,
y Streams exporta cada cambio hacia el lado analítico (data lake) sin
sobrecargar la tabla operacional ni pagar de más por escaneos masivos.

Cierra con `Ctrl+C` el `stream_consumer.py` cuando termines.

## 7. Cierre — borrar todo

**Obligatorio, no dejar para después:**

```bash
cd ..
./infra/teardown.sh
```

Confirma escribiendo `borrar`. Esto borra las scaling policies, los
scalable targets y la tabla completa (con su stream). Después, verifica en
la consola de AWS:

- DynamoDB → Tables: no debe aparecer `EventosBigData`.
- CloudWatch → Alarms: no deben quedar alarmas de auto scaling asociadas.
- (Opcional) Billing → Cost Explorer, filtrando por el tag
  `proyecto=demo-dynamodb-unidad3`, para confirmar el gasto real.

## Resumen para cerrar la presentación (hablado, sin slide)

- **Sharding**: la partition key decide en qué partición física vive cada
  ítem; una key de baja cardinalidad crea hot partitions y throttling real,
  aunque la tabla tenga capacidad de sobra.
- **Buenas prácticas**: keys de alta cardinalidad, TTL para expirar datos,
  Auto Scaling en vez de capacidad fija, permisos IAM mínimos, monitoreo con
  CloudWatch.
- **Escalamiento**: Application Auto Scaling ajusta la capacidad provisionada
  sola, en base a una política de utilización objetivo, sin intervención
  manual.
- **Big data**: DynamoDB Streams es el puente entre la base transaccional
  (OLTP, baja latencia) y el mundo analítico (data lake, consultas batch
  sobre históricos) — cada uno resuelve un problema distinto.
