WITH 
person_support_scores AS (
  SELECT person_id, modeled_support_score AS score
  FROM all_scores
),
has_voted AS (
  SELECT DISTINCT person_id
  FROM `voter_contact_data.contacts_absentees` 
    JOIN voter_file_data USING (myv_van_id)
  GROUP BY person_id
  HAVING 
    COALESCE(MAX(date_early_voted), MAX(date_ballot_received)) IS NOT NULL 
),
vbm_not_voted AS (
  SELECT DISTINCT person_id
  FROM `voter_contact_data.contacts_absentees` 
    JOIN voter_file_data USING (myv_van_id)
  GROUP BY person_id
  HAVING 
    COALESCE(MAX(date_early_voted), MAX(date_ballot_received)) IS NULL AND 
    COALESCE(MAX(date_request_received), MAX(date_ballot_mailed)) IS NOT NULL
),
coordinated_gotv_scores AS (
  SELECT person_id, gotv_score AS coordinated_score
  FROM all_scores
),
support_ids_all AS (
  SELECT 
    person_id, CASE
      WHEN master_survey_response_id IN () THEN 1 -- Dem
      WHEN master_survey_response_id IN () THEN 3                            -- Undecided
      WHEN master_survey_response_id IN () THEN 5 -- GOP
      ELSE -1  -- Not Voting
    END AS value,
    datetime_canvassed
  FROM `voter_contact_data.responses_myv`
  WHERE 
    master_survey_question_id IN ()
    
  UNION ALL
  
  -- The only reason we do this is so we don't have to wait for the Reach --> VAN --> Phoenix sync to complete (~2 hrs).
  -- Doesn't properly deal with "Not Voting" case but that's small enough that I don't care.
  SELECT person_id,
    CASE 
      WHEN response_numeric IN (1, 2) THEN 1
      WHEN response_numeric IN (4, 5) THEN 5
      ELSE response_numeric
    END,
    canvass_timestamp
  FROM `views.reach_runoff_responses` 
    JOIN `crosswalks.reach_to_sos_id` USING (reach_id)
    JOIN voter_file_data USING (sos_id)
  WHERE response_numeric IS NOT NULL
),
support_ids AS (
  SELECT person_id, MAX(value) AS value
  FROM (
    SELECT *, MAX(datetime_canvassed) OVER (PARTITION BY person_id) AS most_recent_canvass
    FROM support_ids_all
  )
  WHERE datetime_canvassed = most_recent_canvass
  GROUP BY person_id
),

tiered_score AS (
  SELECT person_id,
    CASE
      -- Tier By Support ID.
      WHEN support_ids.value IN (5, -1) THEN 4  -- Opponent or Not Voting --> Not a Target
      WHEN support_ids.value = 3 THEN 3         -- Undecideds             --> Tier 3
      WHEN support_ids.value = 1 THEN 1         -- Supporters             --> Tier 1
      
      -- If no ID, tier by score.
      WHEN 
        -- TIER 1: High-impact targets.
        -- Likely supporter & Requested Ballot or Needs to Return
        -- High GOTV score
        (
          person_support_scores.score >= 0.8 AND
          vbm_not_voted.person_id IS NOT NULL
        ) OR 
        (gotv.coordinated_score >= 0.8)
      THEN 1
      
      -- TIER 2: Supporters
      -- Mid-Tier GOTV Score
      -- Likely supporter, if no GOTV score
      WHEN
        (gotv.coordinated_score >= 0.4) OR
        (gotv.coordinated_score IS NULL AND person_support_scores.score >= 0.6)
      THEN 2
      
      -- TIER 3: Undecideds and lower-impact targets.
      WHEN
        (gotv.coordinated_score > 0) OR
        (gotv.coordinated_score IS NULL AND person_support_scores.score >= 0.4)
      THEN 3
      
      -- TIER 4: Everyone else, including Perdue supporters, GOTV scores of 0, etc.
      ELSE 4
    END AS tier,
    has_voted.person_id IS NOT NULL AS voted
  FROM voter_file_data
    LEFT JOIN support_ids USING (person_id)
    LEFT JOIN coordinated_gotv_scores gotv USING (person_id)
    LEFT JOIN person_support_scores USING (person_id)
    LEFT JOIN vbm_not_voted USING (person_id)
    LEFT JOIN has_voted USING (person_id)
  WHERE reg_on_current_file 
)
SELECT person_id, IF(voted, 4, tier) AS tier, tier AS tier_raw, voted
FROM tiered_score
