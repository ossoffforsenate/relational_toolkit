WITH status_raw AS (
  SELECT 
    reach_id,
    sos_id,
    myv_van_id,
    CASE
      WHEN date_early_voted IS NOT NULL THEN "Early Voted"
      WHEN date_ballot_received IS NOT NULL THEN "Ballot Received"
      WHEN date_ballot_mailed IS NOT NULL THEN "Ballot Mailed"
      WHEN date_request_received IS NOT NULL THEN "Request Received"
      ELSE "Needs to Vote"
    END AS voting_status_raw
  FROM `crosswalks.reach_to_sos_id`
  JOIN voter_file_data USING (sos_id)
  LEFT JOIN `voter_contact_data.contacts_absentees` USING (myv_van_id)
  WHERE reg_on_current_file 
)
SELECT *,
  CASE 
    WHEN voting_status_raw IN ("Early Voted", "Ballot Received") THEN "Has Voted!"
    WHEN voting_status_raw = "Ballot Mailed" THEN "Needs to Return Ballot"
    ELSE "Needs to Vote"
  END AS voting_status,
  CASE 
    WHEN voting_status_raw IN ("Early Voted", "Ballot Received") THEN 10
    WHEN voting_status_raw IS NULL THEN 5
    WHEN voting_status_raw = "Ballot Mailed" THEN 3
    ELSE 1
  END AS voting_status_priority
FROM status_raw
