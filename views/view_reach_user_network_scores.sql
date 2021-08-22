WITH active_nonvoter_reach_relationships AS (
  SELECT DISTINCT user_id, reach_id
  FROM reach.relationships
    JOIN `crosswalks.reach_to_sos_id` USING (reach_id)
    JOIN voter_file_data USING (sos_id)
    LEFT JOIN `voter_contact_data.contacts_absentees` USING (myv_van_id)
  WHERE relationship_status = "Active" AND date_ballot_received IS NULL AND date_early_voted IS NULL
),
network_scores_v2 AS (
    SELECT 
      user_id,
      COUNTIF(tier = 1) AS tier1,
      COUNTIF(tier = 2) AS tier2,
      COUNTIF(tier = 3) AS tier3,
      COUNTIF(tier = 4) AS tier4,
      COUNT(person_id) AS scored_network_size
  FROM active_nonvoter_reach_relationships
    JOIN `crosswalks.reach_to_sos_id` USING (reach_id)
    JOIN voter_file_data USING (sos_id)
    JOIN `views.voter_tiers` USING (person_id)
  WHERE reg_on_current_file
  GROUP BY user_id
)
SELECT *
FROM network_scores_v2
