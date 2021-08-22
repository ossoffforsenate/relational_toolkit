WITH most_recent AS (
  SELECT DATE(MAX(most_recent_canvass)) AS canvass_date, MAX(most_recent_canvass) AS canvass_timestamp, reach_id, question_id, name_short, MIN(response_value) AS response_value
  FROM (
    SELECT *, MAX(canvass_timestamp) OVER (PARTITION BY reach_id, question_id) AS most_recent_canvass
    FROM reach.users
      JOIN reach_sqs USING (question_id)
    WHERE response_value IS NOT NULL
  )
  WHERE canvass_timestamp = most_recent_canvass
  GROUP BY reach_id, question_id, name_short
),
# Get distinct ID responses, and their parsed BQ Array equivalents.
ids_parsed AS (
  SELECT response_value, JSON_EXTRACT_ARRAY(response_value, "$") AS id_array
  FROM (
    SELECT DISTINCT response_value
    FROM most_recent
    WHERE name_short = "ID"
  )
),
# Score those IDs
ids_scored AS (
  SELECT response_value, 
    CAST(CEIL(AVG(CASE 
      WHEN single_id LIKE "%Strongly supporting Jon%" THEN 1
      WHEN single_id LIKE "%Leaning Jon%" THEN 2
      WHEN single_id LIKE "%Undecided%" THEN 3
      WHEN single_id LIKE "%Lean Perdue%" THEN 4
      WHEN single_id LIKE "%Strongly supporting Perdue%" THEN 5
    END)) AS INT64) AS response_numeric
  FROM ids_parsed, ids_parsed.id_array AS single_id
  WHERE single_id NOT LIKE "%Not Voting%"
  GROUP BY response_value
)
SELECT 
  * REPLACE (
    CASE
      WHEN name_short IN ("ID", "Plan")
        THEN REPLACE(ARRAY_TO_STRING(JSON_EXTRACT_ARRAY(response_value, "$"), "\n"), "\"", "")
      ELSE response_value
    END AS response_value
  )
FROM most_recent
  LEFT JOIN ids_scored USING (response_value)
