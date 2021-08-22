WITH
cms_prime AS (
  SELECT DISTINCT TRIM(invite_code) AS invite_code, clean_phone_number(phone_number) AS phone_number
  FROM `gsheets.cm_training_tracker`
  WHERE invite_code IS NOT NULL
),
cms AS (
  SELECT *
  FROM cms_prime
  WHERE phone_number IS NOT NULL
),
reach_users AS (
  SELECT *
  FROM `reach.users` 
)
SELECT DISTINCT
  user_id, first_name, last_name, 
  ARRAY_TO_STRING([first_name, last_name], " ") AS user_name,
  email_address, phone_number, date_joined,
  rmm, pod, rmm_email
FROM cms
  JOIN `gsheets.cm_rmm_reach_codes` USING (invite_code)
  JOIN reach_users USING (phone_number)
