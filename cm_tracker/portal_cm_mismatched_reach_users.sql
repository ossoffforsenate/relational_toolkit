WITH
cms_prime AS (
  SELECT 
    * EXCEPT(invite_code, phone_number), 
    TRIM(invite_code) AS invite_code,
    phone_number AS phone_number_old,  
    clean_phone_number(phone_number) AS phone_number,
    ROW_NUMBER() OVER () as rownum
  FROM `gsheets.cm_training_tracker`
),
cms AS (
  SELECT *
  FROM cms_prime
  WHERE invite_code IS NOT NULL
),
reach_users AS (
  SELECT *
  FROM `reach.users`
),
duplicate_numbers AS (
  SELECT phone_number
  FROM cms
  GROUP BY phone_number
  HAVING COUNT(*) > 1
)
SELECT 
  cms.invite_code, 
  cms.cm_name,
  cms.email_address, 
  cms.phone_number_old AS phone_original, 
  cms.phone_number AS phone_clean,
  CASE 
    WHEN cms.phone_number IS NULL THEN "Invalid phone number."
    WHEN codes.invite_code IS NULL THEN "Can't find given RMM Reach Code in RMM Reach Code Sheet."
    WHEN reach_users.phone_number IS NULL THEN "Phone number does not match any Reach users."
    WHEN duplicate_numbers.phone_number IS NOT NULL THEN "More than one onboarded CM has this phone number."
  END AS matching_error
FROM cms
  LEFT JOIN `gsheets.cm_rmm_reach_codes` codes USING (invite_code)
  LEFT JOIN reach_users USING (phone_number)
  LEFT JOIN duplicate_numbers USING (phone_number)
WHERE  
  codes.invite_code IS NULL OR 
  codes.invite_code IS NULL OR 
  reach_users.phone_number IS NULL OR 
  duplicate_numbers.phone_number IS NOT NULL
ORDER BY rownum DESC
