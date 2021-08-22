WITH
support_ids_tbl AS (
  SELECT myv_van_id, master_survey_response_name AS support_id
    FROM `voter_contact_data.responses_myv`
    JOIN `voter_contact_data.master_survey_responses` USING (master_survey_question_id, master_survey_response_id)
  WHERE 
    master_survey_question_id = "" AND 
    msq_currency = 1                                            -- Most recent response
),
vote_plan_tbl AS (
  SELECT myv_van_id, survey_response_name AS vote_plan
    FROM `voter_contact_data.responses_myv`
    JOIN `voter_contact_data.survey_responses` USING (survey_question_id, survey_response_id)
  WHERE 
    survey_question_id = "" AND   -- RO Vote Plan
    sq_currency = 1                     -- Most recent response
),
vol_ask_tbl AS (
  SELECT SUBSTRING(state_file_id, 4) AS sos_id, response_value AS vol_ask
  FROM (
    SELECT *, MAX(canvass_timestamp) OVER (PARTITION BY question_id, reach_id) AS most_recent_canvass
    FROM `reach.response_list` 
    WHERE question_name = "Join a friendbank?"
  )
  WHERE canvass_timestamp = most_recent_canvass
),
relational_network AS (
  SELECT DISTINCT SUBSTRING(state_file_id, 4) AS sos_id
  FROM `reach.relationships` 
  WHERE relationship_status = "Active"
),
expanded_network AS (
  SELECT DISTINCT sos_id
  FROM voter_file_data
  WHERE voting_address_id IN (
    SELECT voting_address_id
    FROM relational_network
    JOIN voter_file_data USING (sos_id)
  )
),
voting_statuses AS (
  SELECT 
    myv_van_id,
    CASE
      WHEN date_early_voted IS NOT NULL THEN "Early Voted"
      WHEN date_ballot_received IS NOT NULL THEN "Ballot Received"
      WHEN date_ballot_mailed IS NOT NULL THEN "Ballot Mailed"
      WHEN date_request_received IS NOT NULL THEN "Request Received"
      ELSE "Needs to Vote"
    END AS voting_status
  FROM `voter_contact_data.contacts_absentees`
),
reach_phones AS (
  SELECT DISTINCT SUBSTRING(state_file_id, 4) AS sos_id, phone
  FROM `reach.people` 
  WHERE state_file_id IS NOT NULL AND phone IS NOT NULL
),
voted_general AS (
  SELECT registration_id AS master_registration_id
  FROM `voter_file_data.election_voted` 
  WHERE election_id = "88502397"
),
coordinated_gotv_scores AS (
  SELECT person_id, gotv_score AS coordinated_score
  FROM gotv_scores
)
SELECT DISTINCT
  vf.myv_van_id, 
  vf.last_name, 
  vf.first_name, 
  vf.middle_name, 
  vf.age_combined AS age, 
  vf.gender_combined AS gender,
  CASE 
    WHEN reach_phones.phone IS NULL THEN vf.primary_phone_number
    ELSE reach_phones.phone
  END AS primary_phone_number,
  vf.voting_street_address, vf.voting_street_address_2, 
  vf.voting_city, vf.state_code, vf.voting_zip,
  support_id, 
  vote_plan, vol_ask,
  IFNULL(voting_status, "Needs to Vote") AS voting_status,
  vf.master_registration_id IN (SELECT master_registration_id FROM voted_general) AS voted_general,
  coordinated_gotv_scores.coordinated_score AS gotv_score,
  vf.voting_address_id,
  vf.household_id,
  vf.sos_id,
  voter_tiers.tier
FROM expanded_network
  JOIN voter_file_data vf USING (sos_id)
  LEFT JOIN voting_statuses USING (myv_van_id)
  LEFT JOIN reach_phones USING (sos_id)
  LEFT JOIN support_ids_tbl USING (myv_van_id)
  LEFT JOIN vote_plan_tbl USING (myv_van_id)
  LEFT JOIN vol_ask_tbl USING (sos_id)
  LEFT JOIN `views.voter_tiers` voter_tiers USING (person_id)
  LEFT JOIN coordinated_gotv_scores USING (person_id)
WHERE vf.reg_on_current_file;
