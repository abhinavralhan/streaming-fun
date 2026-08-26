with source as (
    select * from {{ source('raw', 'users') }}
),
deduped as (
    select *,
        row_number() over (partition by id order by created_at desc) as _row_num
    from source
)
select
    id, email, name, department, country, locale, plan, created_at
from deduped
where _row_num = 1