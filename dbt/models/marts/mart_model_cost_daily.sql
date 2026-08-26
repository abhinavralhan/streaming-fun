-- Daily cost and token usage per model.

with usage as (
    select * from {{ ref('stg_usage') }}
),
models as (
    select * from {{ ref('stg_models') }}
)

select
    date_trunc('day', u.created_at)::date as usage_date,
    m.name as model_name,
    m.provider as provider,

    count(*) as generation_count,
    sum(u.uncached_input_tokens) as uncached_input_tokens,
    sum(u.cached_input_tokens) as cached_input_tokens,
    sum(u.output_tokens) as output_tokens,

    round(sum(
        {{ token_cost('u.uncached_input_tokens', 'u.cached_input_tokens', 'u.output_tokens',
                      'm.input_cost_per_1k', 'm.output_cost_per_1k') }}
    )::numeric, 4) as total_cost_usd

from usage u
join models m on u.model_id = m.id
group by 1, 2, 3
order by 1, 2