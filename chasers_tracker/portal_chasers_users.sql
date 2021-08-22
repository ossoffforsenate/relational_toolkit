WITH
voters_tbl AS (
  SELECT user_id, COUNT(DISTINCT reach_id) AS voters
  FROM `reach.relationships`
  GROUP BY user_id
),
matched_voters_tbl AS (
  SELECT user_id, COUNT(DISTINCT reach_id) AS matched_voters
  FROM `reach.relationships` 
  WHERE state_file_id IS NOT NULL
  GROUP BY user_id
),
voters_voted_tbl AS (
  SELECT user_id, COUNT(DISTINCT reach_id) AS voters_voted
  FROM `reach.relationships` 
      JOIN `views.voting_statuses` USING (reach_id)
  WHERE auto_applied_tag = "Voter" AND voting_status IN ("Early Voted", "Ballot Received")
  GROUP BY user_id
)
SELECT
  user_id,
  ARRAY_TO_STRING([first_name, last_name], " ") AS name,
  phone_number,
  date_joined,
  IFNULL(voters, 0) AS voters,
  IFNULL(matched_voters, 0) AS matched_voters,
  IFNULL(voters_voted, 0) AS voters_voted
FROM `reach.users`
  LEFT JOIN (SELECT user_id FROM `views.cm_reach_users`) cm USING (user_id)
  LEFT JOIN voters_tbl USING (user_id)
  LEFT JOIN matched_voters_tbl USING (user_id)
  LEFT JOIN voters_voted_tbl USING (user_id)
WHERE cm.user_id IS NULL 
