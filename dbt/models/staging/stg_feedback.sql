with source as (
    select * from {{ source('raw', 'feedback') }}
),
deduped as (
    select *,
        row_number() over (partition by id order by created_at desc) as _row_num
    from source
)
select
    id, message_id, user_id, rating, comment, created_at
from deduped
where _row_num = 1