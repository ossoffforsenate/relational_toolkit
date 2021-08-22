WITH distinct_reach_users AS (
  SELECT DISTINCT user_id, first_name, last_name
  FROM `reach.users` 
),
reach_adds_by_user AS (
  SELECT user_id, COUNT(DISTINCT reach_id) AS num_reach_adds
  FROM `reach.relationships` 
  WHERE state_file_id IS NULL
  GROUP BY user_id
),
cm_rmm_emails AS (
  SELECT user_id, rmm_email
  FROM `views.cm_reach_users`
)
SELECT 
  user_id, 
  first_name, 
  last_name, 
  email_address,
  phone_number,
  myv_van_id AS canvasser_vanid,
  rmm_email,
  role,
  date_joined,
  added_method,
  invite_code,
  invite_code_name,
  added_by_user_id,
  IFNULL(num_reach_adds, 0) AS num_reach_adds
FROM `reach.users` users
  LEFT JOIN reach_adds_by_user USING (user_id)
  LEFT JOIN `crosswalks.reachid_to_vanid` ON user_id = reach_user_id
  LEFT JOIN cm_rmm_emails USING (user_id)
