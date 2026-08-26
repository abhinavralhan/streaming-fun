{% macro token_cost(uncached_col, cached_col, output_col, input_rate, output_rate, cached_discount=0.10) %}
    (
        ({{ uncached_col }} / 1000.0) * {{ input_rate }}
      + ({{ cached_col }}   / 1000.0) * {{ input_rate }} * {{ cached_discount }}
      + ({{ output_col }}   / 1000.0) * {{ output_rate }}
    )
{% endmacro %}