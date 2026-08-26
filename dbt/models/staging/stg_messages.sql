with source as (
    select * from {{ source('raw', 'messages') }}
),

deduped as (
    select
        *,
        row_number() over (
            partition by id
            order by created_at desc
        ) as _row_num
    from source
)

select
    id,
    conversation_id,
    user_id,
    model_id,
    role,
    type,
    content,
    tool_payload,
    created_at
from deduped
where _row_num = 1