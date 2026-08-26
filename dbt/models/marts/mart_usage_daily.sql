-- Daily usage & engagement, sliceable by channel, department, country, and plan.

with messages as (
    select * from {{ ref('stg_messages') }}
),
conversations as (
    select * from {{ ref('stg_conversations') }}
),
users as (
    select * from {{ ref('stg_users') }}
)

select
    date_trunc('day', m.created_at)::date as usage_date,
    c.source as channel,
    u.department  as department,
    u.country as country,
    u.plan as plan,
    count(*) as message_count,
    count(distinct m.conversation_id) as conversation_count,
    count(distinct m.user_id)  as active_users

from messages m
join conversations c on m.conversation_id = c.id
join users u on m.user_id = u.id
group by 1, 2, 3, 4, 5
order by 1, 2