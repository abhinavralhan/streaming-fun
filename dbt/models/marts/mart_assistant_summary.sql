-- Assistant leaderboard: message volume + satisfaction per assistant.

with messages as (
    select * from {{ ref('stg_messages') }}
),
conversations as (
    select * from {{ ref('stg_conversations') }}
),
assistants as (
    select * from {{ ref('stg_assistants') }}
),
feedback as (
    select * from {{ ref('stg_feedback') }}
),
msg_assistant as (
    select
        m.id as message_id,
        c.assistant_id as assistant_id
    from messages m
    join conversations c on m.conversation_id = c.id
    where c.assistant_id is not null
),
msg_feedback as (
    select
        ma.assistant_id,
        ma.message_id,
        f.rating
    from msg_assistant ma
    left join feedback f on f.message_id = ma.message_id
)

select
    a.name as assistant_name,
    count(distinct mf.message_id) as message_count,
    count(mf.rating) as feedback_count,
    sum(case when mf.rating = 1  then 1 else 0 end) as thumbs_up,
    sum(case when mf.rating = -1 then 1 else 0 end) as thumbs_down,
    round(sum(case when mf.rating = 1 then 1 else 0 end)::numeric
        / nullif(count(mf.rating), 0), 4) as satisfaction_rate

from msg_feedback mf
join assistants a on mf.assistant_id = a.id
group by 1
order by message_count desc