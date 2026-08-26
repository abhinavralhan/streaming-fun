with source as (
    select * from {{ source('raw', 'models') }}
),
deduped as (
    select *,
        row_number() over (partition by id order by id) as _row_num
    from source
)
select
    id, name, provider, input_cost_per_1k, output_cost_per_1k
from deduped
where _row_num = 1