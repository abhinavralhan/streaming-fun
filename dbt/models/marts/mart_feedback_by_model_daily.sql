-- Daily feedback quality per model.

with feedback as (
    select * from {{ ref('stg_feedback') }}
),
messages as (
    select * from {{ ref('stg_messages') }}
),
models as (
    select * from {{ ref('stg_models') }}
)

select
    date_trunc('day', f.created_at)::date as feedback_date,
    md.name  as model_name,
    md.provider as provider,

    count(*) as feedback_count,
    sum(case when f.rating = 1  then 1 else 0 end) as thumbs_up,
    sum(case when f.rating = -1 then 1 else 0 end) as thumbs_down,
    round(sum(case when f.rating = 1 then 1 else 0 end)::numeric
        / nullif(count(*), 0), 4 ) as satisfaction_rate

from feedback f
join messages m on f.message_id = m.id
join models md  on m.model_id = md.id
group by 1, 2, 3
order by 1, 2