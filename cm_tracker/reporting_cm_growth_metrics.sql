DECLARE group_vars ARRAY<STRING> DEFAULT ["user_id, user_name, rmm, pod, email_address, phone_number", "rmm, pod", "pod", "program"];
DECLARE table_names ARRAY<STRING> DEFAULT ["cm", "rmm", "pod", "program"];
DECLARE i INT64 DEFAULT 0;

LOOP
  SET i = i + 1;
  IF i > ARRAY_LENGTH(group_vars) THEN
    LEAVE;
  END IF;
  EXECUTE IMMEDIATE REPLACE(REPLACE("""
    CREATE OR REPLACE TABLE `reporting.cm_growth_metrics_{table_name}_v2` AS
    WITH

    cm_reach_users AS (
      SELECT *, "CM" AS program
      FROM `views.cm_reach_users`
    ),

    # Grab the different groups and dates.
    group_values AS (
      SELECT DISTINCT {group_var}
      FROM cm_reach_users
    ),
    dates AS (
      SELECT *
      FROM UNNEST(GENERATE_DATE_ARRAY('2020-07-01', CURRENT_DATE("US/Eastern"), INTERVAL 1 DAY)) AS day
      CROSS JOIN group_values
    ),

    # Generate timeseries for users who have joined within each group.
    cm_count_timeseries AS (
      SELECT date_joined AS day, {group_var}, COUNT(DISTINCT user_id) n_new_users
        FROM cm_reach_users
      GROUP BY date_joined, {group_var}
    ),

    # Generate timeseries for unique voters added within group.
    # We consider networks within our grouping variable of interest.
    # We count the additional voter on the *first* day they are added within the group.
    cm_relationships AS (
      SELECT reach_id, relationship_created_timestamp, relationship_created_date, auto_applied_tag, cm_reach_users.*
      FROM reach.relationships
        JOIN cm_reach_users USING (user_id)
      WHERE relationship_status = "Active"
    ),
    relationships_unique_prime AS (
      SELECT *, MIN(relationship_created_timestamp) OVER (PARTITION BY reach_id, {group_var}) AS creation_timestamp
      FROM cm_relationships
    ),
    relationships_unique AS (
      SELECT relationship_created_date AS day, reach_id, {group_var}, auto_applied_tag
      FROM relationships_unique_prime
      WHERE creation_timestamp = relationship_created_timestamp
    ),
    network_count_timeseries AS (
      SELECT day, {group_var}, COUNT(DISTINCT reach_id) n_new_voters
      FROM relationships_unique
      GROUP BY day, {group_var}
    ),
    matched_voter_count_timeseries AS (
      SELECT day, {group_var}, COUNT(DISTINCT reach_id) n_new_matched_voters
      FROM relationships_unique
      WHERE auto_applied_tag = "Voter"
      GROUP BY day, {group_var}
    ),
    reach_add_count_timeseries AS (
      SELECT day, {group_var}, COUNT(DISTINCT reach_id) n_new_reach_adds
      FROM relationships_unique
      WHERE auto_applied_tag = "Reach Add" 
      GROUP BY day, {group_var}
    ),
    
    # Survey Responses: count the response on the first day marked (not necessarily in the group (pod, RMM, etc) since
    # all users can see all responses)
    responses_unique_prime AS (
      SELECT *, MIN(canvass_timestamp) OVER (PARTITION BY question_name, reach_id) AS first_canvass_timestamp
      FROM reach.responses
    ),
    responses_unique AS (
      SELECT canvass_date AS day, question_name, reach_id
      FROM responses_unique_prime
      WHERE first_canvass_timestamp = canvass_timestamp AND response_id IS NOT NULL
    ),
    responses_with_relationships AS (
      SELECT *
      FROM responses_unique
        JOIN cm_relationships USING (reach_id)
    ),
    ids_count_timeseries AS (
      SELECT day, {group_var}, COUNT(DISTINCT reach_id) AS n_new_ids
      FROM responses_with_relationships
      WHERE question_name = "Support"
      GROUP BY day, {group_var}
    ),
    plans_count_timeseries AS (
      SELECT day, {group_var}, COUNT(DISTINCT reach_id) AS n_new_plans
      FROM responses_with_relationships 
      WHERE question_name = "RUNOFF - How are you planning to vote?"
      GROUP BY day, {group_var}
    ),

    # Generate timeseries for votes of voters within each group.
    vote_dates AS (
      SELECT GREATEST(relationships_unique.day, date_voted) AS day, reach_id, {group_var}
      FROM `views.voted_by_reach_id` voted
        JOIN relationships_unique USING (reach_id)
    ),
    vote_count_timeseries AS (
      SELECT vote_dates.day, {group_var}, COUNT(DISTINCT reach_id) n_votes
      FROM vote_dates
      GROUP BY day, {group_var}
    ),

    # Generate *cumulative* timeseries for above metrics.
    cumulative_totals_prime AS (
      SELECT 
        day,
        {group_var},
        SUM(n_new_users) OVER(PARTITION BY {group_var} ORDER BY day RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) users,
        SUM(n_new_voters) OVER(PARTITION BY {group_var} ORDER BY day RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) voters,
        SUM(n_new_matched_voters) OVER(PARTITION BY {group_var} ORDER BY day RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) matched_voters,
        SUM(n_new_reach_adds) OVER(PARTITION BY {group_var} ORDER BY day RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) reach_adds,
        SUM(n_new_ids) OVER(PARTITION BY {group_var} ORDER BY day RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) ids,
        SUM(n_new_plans) OVER(PARTITION BY {group_var} ORDER BY day RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) plans,
        SUM(n_votes) OVER(PARTITION BY {group_var} ORDER BY day RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) votes,
      FROM dates
        LEFT JOIN cm_count_timeseries USING (day, {group_var})
        LEFT JOIN network_count_timeseries USING (day, {group_var})
        LEFT JOIN matched_voter_count_timeseries USING (day, {group_var})
        LEFT JOIN reach_add_count_timeseries USING (day, {group_var})
        LEFT JOIN ids_count_timeseries USING (day, {group_var})
        LEFT JOIN plans_count_timeseries USING (day, {group_var})
        LEFT JOIN vote_count_timeseries USING (day, {group_var})
    ),
    # Add CM-Days variable.
    cumulative_totals AS (
        SELECT 
        *,
        SUM(users) OVER(PARTITION BY {group_var} ORDER BY day RANGE BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) cm_days
      FROM cumulative_totals_prime
    ),

    # Calculate metrics based on existing variables.
    results_prime AS (
      SELECT
        *, 
        matched_voters/cm_days*7 AS voters_per_cm_week,
        (voters - IFNULL(reach_adds, 0)) / voters AS pct_matched_voters,
        ids / voters AS pct_ids, 
        plans / voters AS pct_plans, 
        votes/voters AS pct_votes
      FROM cumulative_totals
    ),

    # Grab today's metric values, to be used for sorting in the GDS reporting.
    metrics_today AS (
      SELECT {group_var}, voters_per_cm_week AS todays_voters_per_cm_week, pct_votes AS todays_pct_votes
      FROM results_prime
      WHERE day = CURRENT_DATE("US/Eastern")
    )

    # Generate the final query.
    SELECT *
    FROM results_prime
      LEFT JOIN metrics_today USING ({group_var})
    WHERE day >= "2020-12-14"
  """,
    "{group_var}", 
    group_vars[ORDINAL(i)]
  ), "{table_name}", table_names[ORDINAL(i)]);
  
  EXECUTE IMMEDIATE REPLACE(REPLACE(""" 
    CREATE OR REPLACE TABLE `reporting.cm_topline_{table_name}_v2` AS
    WITH ordered_metrics AS (
      SELECT *, ROW_NUMBER() OVER (PARTITION BY {group_var} ORDER BY day DESC) AS rownum
      FROM `reporting.cm_growth_metrics_{table_name}_v2`
    ),
    cm_reach_users AS (
      SELECT *, "CM" AS program
      FROM `views.cm_reach_users`
    ),
    relationships_unique AS (
      SELECT DISTINCT {group_var}, reach_id
      FROM (SELECT DISTINCT user_id, reach_id FROM `reach.relationships`  WHERE relationship_status = "Active")
        JOIN cm_reach_users USING (user_id)
    ),
    nonvoting_relationships AS (
      SELECT DISTINCT {group_var}, reach_id
      FROM relationships_unique
        JOIN voting_statuses USING (reach_id)
      WHERE voting_status <> "Has Voted!"
    ),
    nonvoting_voter_counts AS (
      SELECT {group_var}, COUNT(reach_id) AS num_nonvoting_voters
      FROM nonvoting_relationships
      GROUP BY {group_var}
    ),
    nonvoting_responses AS (
      SELECT 
        {group_var}, 
        COUNTIF(support_id_numeric IS NOT NULL) AS nonvoting_support_ids, 
        COUNTIF(support_id_numeric IS NOT NULL) / COUNT(reach_id) AS pct_nonvoting_support_ids, 
        COUNTIF(vote_plan IS NOT NULL) AS nonvoting_plans,
        COUNTIF(vote_plan IS NOT NULL) / COUNT(reach_id) AS pct_nonvoting_plans
      FROM nonvoting_relationships
        LEFT JOIN `views.reach_voters_wide` USING (reach_id)
      GROUP BY {group_var}
    ),
    avg_support_id AS (
      SELECT 
        {group_var}, 
        COUNTIF(support_id_numeric = 1) AS support_id_ones,
        COUNTIF(support_id_numeric = 2) AS support_id_twos,
        COUNTIF(support_id_numeric = 3) AS support_id_threes,
        COUNTIF(support_id_numeric = 4) AS support_id_fours,
        COUNTIF(support_id_numeric = 5) AS support_id_fives,
        COUNTIF(support_id_numeric >= 1 AND support_id_numeric <= 5) AS support_id_total,
        AVG(support_id_numeric) AS avg_support_id
      FROM relationships_unique
        LEFT JOIN `views.reach_voters_wide` voters USING (reach_id)
      WHERE support_id_numeric IS NOT NULL
      GROUP by {group_var}
    ),
    network_scores AS (
      SELECT {group_var}, COUNTIF(tier = 1) AS tier1, COUNTIF(tier = 2) AS tier2, COUNTIF(tier = 3) AS tier3, COUNTIF(tier = 4) AS tier4,
      FROM nonvoting_relationships
        JOIN `crosswalks.reach_to_sos_id` USING (reach_id)
        JOIN voter_file_data USING (sos_id)
        JOIN voter_tiers USING (person_id)
      WHERE reg_on_current_file
      GROUP BY {group_var}
    )
    SELECT *
    FROM ordered_metrics
      LEFT JOIN avg_support_id USING ({group_var})
      LEFT JOIN nonvoting_responses USING ({group_var})
      LEFT JOIN network_scores USING ({group_var})
      LEFT JOIN nonvoting_voter_counts USING ({group_var})
    WHERE rownum = 1
  """,
    "{group_var}", 
    group_vars[ORDINAL(i)]
  ), "{table_name}", table_names[ORDINAL(i)]);
END LOOP;

CREATE OR REPLACE TABLE `reporting.cm_topline_cm_v2` AS
SELECT * REPLACE (IFNULL(voting_status, "Unable to match to Voter File") AS voting_status, IFNULL(voting_status_priority, 5) AS voting_status_priority)
FROM `reporting.cm_topline_cm_v2`
  LEFT JOIN (SELECT DISTINCT user_id FROM `views.cm_reach_users`) USING (user_id)
  LEFT JOIN `views.cm_last_activity` USING (user_id)
  LEFT JOIN (
    SELECT DISTINCT user_id, voting_status_raw, voting_status, voting_status_priority
    FROM `reach.users`  
    JOIN `crosswalks.reachid_to_vanid` ON user_id = reach_user_id
    JOIN `views.voting_statuses` USING (myv_van_id)
  ) USING (user_id)
