WITH voter_tiers_by_reach_id AS (
  SELECT reach_id, MAX(tier) AS tier
  FROM `views.voter_tiers` 
    JOIN voter_file_data USING (person_id)
    JOIN crosswalks.reach_to_sos_id USING (sos_id)
  GROUP BY reach_id
)
SELECT * REPLACE (IFNULL(sos_id, "Reach Add") AS sos_id, IF(sos_id IS NULL, 4, tier) AS tier),
  CASE 
    WHEN tier IS NULL OR tier = 4 THEN "Not a Target" 
    WHEN tier = 3 THEN "Tier 3" 
    WHEN tier = 2 THEN "Tier 2"
    WHEN tier = 1 THEN "Tier 1"
  END AS tier_str,
  CASE
    WHEN voting_status = "Has Voted!" THEN 10
    WHEN voting_status IS NULL THEN 5
    ELSE 0
  END AS sort_1,
  CASE
    WHEN support_id_numeric IN (1, 2) THEN 10
    WHEN support_id_numeric = 3 THEN 5
    WHEN support_id_numeric IS NULL THEN 3
    ELSE 1
  END AS sort_2
FROM (
  SELECT DISTINCT user_id, reach_id, ARRAY_TO_STRING([person_first_name, person_last_name], " ") AS voter
  FROM reach.relationships
  WHERE relationship_status = "Active"
    JOIN `views.cm_reach_users` USING (user_id)
    LEFT JOIN `views.reach_voters_wide` voters USING (reach_id)
    LEFT JOIN `views.voting_statuses` voting_statuses USING (reach_id)
    LEFT JOIN voter_tiers_by_reach_id USING (reach_id)
