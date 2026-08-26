with source as (
    select * from {{ source('raw', 'assistants') }}
),
deduped as (
    select *,
        row_number() over (partition by id order by created_at desc) as _row_num
    from source
)
select
    id, name, description, system_prompt, created_by, created_at
from deduped
where _row_num = 1