WITH 
responses AS (
  SELECT user_id, reach_id, canvass_timestamp, 
    "Marked Survey Response",
    CASE
      WHEN question_name = "Support" THEN "(1) Support ID"
      WHEN question_name = "RUNOFF - How are you planning to vote?" THEN "(2) Vote Plan"
      WHEN question_name = "Vote Plan Detailed" THEN "(2b) Plan Details"
      WHEN question_name = "Join a friendbank?" THEN "(3) Vol Ask"
    END || ": " || response_value AS response_readable,
  FROM reach.responses
  WHERE response_id IS NOT NULL
),
activities AS (
  SELECT user_id, reach_id, action_timestamp, "Contacted" AS action, action_type AS value
  FROM reach.contact_actions
    UNION ALL
  SELECT 
    user_id, reach_id, relationship_created_timestamp, 
    "Added Relationship", 
    relationship_type || CASE WHEN relationship_status <> "Active" THEN " (Inactive)" ELSE "" END
  FROM reach.relationships
    UNION ALL
  SELECT *
  FROM responses
  WHERE response_readable IS NOT NULL
    UNION ALL
  SELECT user_id, reach_id, tag_timestamp, "Added Tag", tag_name
  FROM reach.tag_history
    UNION ALL
  SELECT user_id, "", TIMESTAMP(date_joined), "Joined Reach", NULL
  FROM reach.users
),
all_people AS (
  SELECT reach_id, sos_id, INITCAP(first_name) AS first_name, INITCAP(last_name) AS last_name
  FROM `crosswalks.reach_to_sos_id`
  JOIN voter_file_data USING (sos_id)
  
  UNION DISTINCT
  
  SELECT reach_id, NULL, person_first_name, person_last_name
  FROM reach.relationships
  WHERE state_file_id IS NULL
  
  UNION DISTINCT
  
  SELECT reach_id, NULL, person_first_name, person_last_name
  FROM reach.contact_actions
  WHERE state_file_id IS NULL
)
SELECT 
  users.*,
  action_timestamp,
  action, value, 
  ARRAY_TO_STRING([p.first_name, p.last_name], " ") AS voter,
  IF(action = "Joined Reach", NULL, IFNULL(sos_id, "Reach Add")) AS sos_id
FROM activities
  JOIN `views.cm_reach_users` users USING (user_id)
  LEFT JOIN all_people p USING (reach_id)
  ORDER BY action_timestamp DESC
