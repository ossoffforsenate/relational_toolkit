WITH activities AS (
  SELECT user_id, NULL, date_joined AS reach_date
  FROM `reach.users`
    UNION ALL
  SELECT user_id, reach_id, action_date AS reach_date
  FROM `reach.contact_actions` 
    UNION ALL
  SELECT user_id, reach_id, relationship_created_date AS reach_date
  FROM `reach.relationships`
    UNION ALL
  SELECT user_id, reach_id, canvass_date AS reach_date
  FROM `reach.responses`
  WHERE response_id IS NOT NULL
    UNION ALL
  SELECT user_id, reach_id, tag_date AS reach_date 
  FROM `reach.tag_history`
),
last_activity_by_user AS (
  SELECT 
    user_id, 
    MIN(DATE_DIFF(CURRENT_DATE("US/Eastern"), reach_date, DAY)) AS last_activity
  FROM activities
  GROUP BY user_id
)
SELECT *,
  IF(last_activity = 0, "Today", IF(last_activity = 1, "Yesterday", last_activity || " days ago")) AS last_activity_readable
FROM last_activity_by_user 
