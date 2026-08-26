with source as (
    select * from {{ source('raw', 'usage') }}
),
deduped as (
    select *,
        row_number() over (partition by id order by created_at desc) as _row_num
    from source
)
select
    id, user_id, model_id,
    uncached_input_tokens, cached_input_tokens, output_tokens,
    created_at
from deduped
where _row_num = 1