-- (4 distinct portal jobs)

-- (1) SQL RUNNER: BUILD TABLE
CREATE OR REPLACE TABLE `reach_avev.needs_reach_tag` AS
WITH 
reach_tags_most_recent AS (
  SELECT *
  FROM (
    SELECT *, ROW_NUMBER() OVER (PARTITION BY reach_id, tag_id ORDER BY tag_timestamp DESC) AS rownum
    FROM reach.tag_history
  ) 
  WHERE rownum = 1
),
reach_tags AS (
  SELECT DISTINCT
    state_file_id AS alloy_sos_id, 
    CASE
      WHEN tag_id = "QWPRZK6M" THEN "early_voted"
      WHEN tag_id = "7J4RYZJA" THEN "ballot_mailed"
      WHEN tag_id = "GJ2NM36R" THEN "ballot_received"
      WHEN tag_id = "AJEDGPW3" THEN "request_received"
    END AS voting_status
  FROM reach_tags_most_recent
  WHERE tag_action = "Added"
  
  UNION DISTINCT
  
  SELECT DISTINCT
    alloy_sos_id,
    voting_status
  FROM `reach_avev.tag_log`
),
reach_vote_status_tags AS (
  SELECT *
  FROM reach_tags
  WHERE voting_status IS NOT NULL
),
most_recent_voting_statuses AS (
  SELECT 
    "GA_" || sos_id AS alloy_sos_id,
    CASE
      WHEN date_early_voted IS NOT NULL THEN "early_voted"
      WHEN date_ballot_received IS NOT NULL THEN "ballot_received"
      WHEN date_ballot_mailed IS NOT NULL THEN "ballot_mailed"
      WHEN date_request_received IS NOT NULL THEN "request_received"
    END AS voting_status
  FROM `voter_contact_data.contacts_absentees`
    JOIN voter_file_data USING (myv_van_id)
  WHERE (
    date_early_voted IS NOT NULL OR
    date_ballot_received IS NOT NULL OR
    date_ballot_mailed IS NOT NULL OR 
    date_request_received IS NOT NULL
  )
)
-- Grabs the most recent voting statuses, and removes those in Reach that already have that respective tag.
SELECT *
  FROM most_recent_voting_statuses
  LEFT JOIN reach_vote_status_tags USING (alloy_sos_id, voting_status)
WHERE reach_vote_status_tags.alloy_sos_id IS NULL;

-- (2) GSHEET: EARLY VOTED 
SELECT *
FROM `reach_avev.needs_reach_tag`
WHERE voting_status = "early_voted"

-- (3) GSHEET: BALLOT RECEIVED 
SELECT *
FROM `reach_avev.needs_reach_tag`
WHERE voting_status = "ballot_received"

-- (2) GSHEET: BALLOT MAILED 
SELECT *
FROM `reach_avev.needs_reach_tag`
WHERE voting_status = "ballot_mailed"

-- (2) GSHEET: REQUEST RECEIVED 
SELECT *
FROM `reach_avev.needs_reach_tag`
WHERE voting_status = "request_received"
