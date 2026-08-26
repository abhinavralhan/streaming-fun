-- Daily cost-to-serve by plan tier and department.

with usage as (
    select * from {{ ref('stg_usage') }}
),
models as (
    select * from {{ ref('stg_models') }}
),
users as (
    select * from {{ ref('stg_users') }}
)

select
    date_trunc('day', u.created_at)::date as usage_date,
    usr.plan as plan,
    usr.department as department,
    count(*) as generation_count,
    count(distinct u.user_id) as active_users,
    round(sum(
        {{ token_cost('u.uncached_input_tokens', 'u.cached_input_tokens', 'u.output_tokens',
                      'm.input_cost_per_1k', 'm.output_cost_per_1k') }}
    )::numeric, 4) as total_cost_usd
from usage u
join models m on u.model_id = m.id
join users usr on u.user_id = usr.id
group by 1, 2, 3
order by 1, 2, 3