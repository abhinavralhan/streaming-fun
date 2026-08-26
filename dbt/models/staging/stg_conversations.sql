with source as (
    select * from {{ source('raw', 'conversations') }}
),
deduped as (
    select *,
        row_number() over (partition by id order by created_at desc) as _row_num
    from source
)
select
    id, user_id, assistant_id, title, source, created_at
from deduped
where _row_num = 1