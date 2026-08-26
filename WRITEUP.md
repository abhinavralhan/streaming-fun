# Design Writeup

## How it works

The pipeline has three layers, each with a single responsibility:

**Ingestion: native Postgres logical replication (CDC).** The source database
has `wal_level=logical` enabled, so it emits a row level change events. The
warehouse subscribes to a publication on the source and continuously applies
every insert, update, and delete.

**Transformation: dbt.** Raw replicated tables land in the warehouse's `public`
schema. dbt builds two layers on top, in the `analytics` schema:
- *Staging* (`stg_*`): one model per source table doing casting, renaming,
  and deduplication.
- *Marts* (`mart_*`): joined and aggregated business metrics — cost, usage,
  feedback quality — materialized as tables for fast dashboard reads.
- The dbt project includes tests, model/column descriptions, and
a shared `token_cost` macro.

**Presentation: Metabase**, reading the marts directly.

## Architecture at a glance

```
┌─────────────┐   logical      ┌─────────────┐    dbt      ┌──────────────┐   ┌──────────┐
│  Source     │  replication   │  Warehouse  │  (staging   │  Data Models │   │ Metabase │
│  (Postgres) │ ─────────────► │  (Postgres) │ ──────────► │              │──►│dashboards│
│             │   (CDC, WAL)   │             │   + marts)  │ (marts/views)│   │          │
└─────────────┘                └─────────────┘             └──────────────┘   └──────────┘
     ▲                                                          
     │ streamer inserts                                         
     │ live traffic                                             
```

## Why this architecture

*Note - Most of the decisions were based on the requirement of the task given, and not how I would implement in a real world project.*

**Why Native logical replication over Kafka / other streaming services?** Kafka would be necessary in a production environment for many reasons. Multiple independent producers/consumers, dead letter queues, cross-engine delivery, partitioning or independent producer/consumer scaling. This pipeline has a single destination and runs on a single machine, so their operational
weight (Kafka brokers, Temporal, extra containers) isn't justified. Native
logical replication already provides single consumer durability via the
source's replication slot.

**Why Postgres for Warehouse?** The workload is analytical (aggregations over a
large fact table), which normally points to a columnar engine like ClickHouse.
Postgres as warehouse was chosen deliberately for the constraints: it keeps the
stack lightweight and fully reproducible with one `docker compose up`, needs no
Clickhouse cloud account (for this POC), and native logical replication into it is a built-in feature
rather than an extra tool. At production scale, I would keep this exact pipeline
shape but swap the destination to Clickhouse.

**Operational vs analytical schema.** The warehouse tables intentionally drop
the source's foreign keys. In an ideal world, a columnar storage like Clikchouse, where defining partitions and sort key are enough along with a dedup job.
The warehouse's job is to store what arrives and be fast to query. I would prefer to store duplicates as it is in raw layer in an analytical warehouse. Analytical indexes are added on the warehouse for
the join/aggregation patterns the marts use (these are not carried over by
replication, which copies data, not indexes).

## Why DBT?

- **ETL vs ELT:** Would prefer ELT approach to store all the data and then decide on Transformations required in the warehouse.
- **Layers:** In an ideal world, I would have created 3 layers to have staging / intermediate / mart layer. This would allow 3 different layers solving for their own purpose.
- **Features:** Allows to store semantics / macros / tests / freshness checks. Apart from this, I can also define model dependencies and run them accordignly via Airflow / Dagster. Materialization and updation strategies are also very useful at scale.
- **Freshness:** Marts are materialized tables,
  rebuilt on a cadence (via a scheduled `dbt run`). Marts are refreshed every 5 mins. This
  trades a few minutes of mart staleness for fast, pre aggregated dashboard reads. It is a useful lever to have.

This split is deliberate: dashboards read pre-computed tables instantly, while a
background refresh absorbs the compute cost where no user is waiting on it.

## How I would address scaling?

- **Columnar warehouse.** As the fact table grows, row store Postgres becomes
  the bottleneck for analytical scans. I'd move the destination to **ClickHouse**, using Kafka/Flink to stream data for reliability and extra features which become necessary at scale.
- **Incremental models.** The `messages` and `usage` marts are append heavy which is
  ideal for dbt `incremental` materializations that append only new rows instead
  of rebuilding the whole table each run. This shrinks both refresh time and the
  ingestion/transform contention window.
- **Observability.** I would introduce Grafana, Kafdrop to montior performance, latency, uptime and health of existing and newly introduced systems / events.

## What I'd do with more time

- **Incremental materializations.** Convert the append-heavy marts (`messages`,
  `usage`) to dbt `incremental` models so each run appends only new rows rather
  than rebuilding the whole table — cutting both refresh time and the
  ingestion/transform contention on the warehouse.
- **Intermediate layer.** Introduce an `intermediate/` layer between staging and
  marts for reusable domain logic (e.g. a shared "message enriched with model,
  assistant, and cost" model) so several marts build on one canonical join
  instead of repeating it.
- **Semantic layer.** Define governed metrics (cost, satisfaction, active users)
  via dbt semantic models / MetricFlow, so metric definitions live in one place
  and are consistent across every dashboard and consumer.
- **Dashboards as code + AI** Commit the Metabase dashboard set (via serialization)
  so dashboards live in the repo and reproduce automatically rather than requiring a manual rebuild.
  Metabase also allows for AI usage and I would definitely intergrate some model to allow stakeholders to make their own reports.
- **Replication monitoring.** With Kafka, a small panel for replication lag and rows ingested,
  surfacing the freshness guarantee as an observable metric.
- **Graceful teardown.** Drop the subscription (releasing the source's
  replication slot) when the warehouse is torn down independently of a
  long-lived source, to avoid WAL retention on the source.


## Assumptions

- **Deduplication.** Staging models dedupe on primary key defensively (keeping
  the latest row per `id`). Native logical replication applies changes by
  primary key and does not normally produce duplicate `id` rows.
- **Dev credentials.** The provided `postgres` / `secret` credentials are used
  directly, read via environment variables with safe defaults. They are already
  public in the challenge repo. Production should inject credentials from the
  environment / a secrets manager (Vault, AWS Secrets Manager).
