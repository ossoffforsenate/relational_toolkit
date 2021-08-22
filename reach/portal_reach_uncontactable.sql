WITH 
person_support_scores AS (
  SELECT DISTINCT 
    person_id,
    CASE
      -- Strong/Lean Ossoff/Warnock/Dem
      WHEN master_survey_response_id IN () THEN 100
      -- Undecided
      WHEN master_survey_response_id IN () THEN 50
      ELSE model_support_score
    END as support_score
  FROM (
    SELECT *
    FROM `voter_contact_data.responses_myv`
    WHERE 
    master_survey_question_id IN () AND   -- Ossoff/Warnock/Both
    msq_currency = 1                                            -- Most recent response
  )
    FULL JOIN all_scores_2020 USING (person_id)
)
SELECT DISTINCT "GA_" || sos_id AS state_file_id
FROM `views.voting_statuses`
  JOIN voter_file_data USING (sos_id)
  LEFT JOIN person_support_scores USING (person_id)
WHERE
  voting_status <> "Has Voted!" AND
  reach_id NOT IN (
    SELECT reach_id
    FROM voter_file_data
      JOIN `crosswalks.reach_to_sos_id` USING (sos_id)
      JOIN phone_numbers USING (myv_van_id)
    WHERE phone_number IS NOT NULL
  ) AND
  (support_score IS NULL OR support_score >= 50) AND
  "GA_" || sos_id NOT IN (
    SELECT DISTINCT state_file_id
    FROM reach.tag_history
    WHERE tag_action = "Added" AND tag_id = "RJY829J8"  -- phoenix_uncontactable
  ) AND
  reg_on_current_file
