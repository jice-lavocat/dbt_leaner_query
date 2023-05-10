{% set partitions_to_replace = [
    'date(date_add(current_date, interval -3 day))',
    'date(date_add(current_date, interval -2 day))',
    'date(date_add(current_date, interval -1 day))',
    'date(current_date)'
] %}

{{ 
    config(
        cluster_by = ['job_key', 'user_key', 'user_agent_key'],
        partition_by={
            "field": "statement_date",
            "data_type": "date",
            "granularity": "day"
        },
        materialized = 'incremental',
        partitions = partitions_to_replace,
        incremental_strategy = 'insert_overwrite'
) }}

with source as (

    select *
    from {{ ref('stg_bigquery_audit_log__data_access') }}
    {% if is_incremental() %}
      where date(event_timestamp) >= current_date - 3
    {% endif %}

),

final as (

    select distinct
        start_time,
        date(start_time) as statement_date,
        end_time,
        total_processed_bytes,
        total_billed_bytes,
        output_row_count,
        total_slot_ms,
        billing_tier,
        if(error_result_code is null, 'NONE', error_result_code) as error_result_code,
        if(error_result_message is null, 'NONE', error_result_message) as error_result_message,
        job_id,
        principal_email,
        caller_supplied_user_agent
    from source

)

select
{{ generate_surrogate_key ([
        'job_id'
    ]) }} as job_key,
{{ generate_surrogate_key([
        'error_result_code'
        , 'error_result_message'
    ]) }} as error_message_key,
{{ generate_surrogate_key([
        'principal_email'
    ]) }} as user_key,
{{ generate_surrogate_key([
        'caller_supplied_user_agent'
    ]) }} as user_agent_key,
    * except(error_result_code,
        error_result_message,
        job_id,
        principal_email,
        caller_supplied_user_agent)
from final