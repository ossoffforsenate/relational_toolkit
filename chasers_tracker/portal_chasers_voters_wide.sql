SELECT DISTINCT
  reach_id,
  user_id,
  user_name,
  auto_applied_tag,
  person_first_name, person_last_name,
  support_id, vote_plan, detailed_plan, vol_ask,
  IF(voting_status = "Needs to Vote", "", voting_status) AS voting_status
FROM reach.relationships
  LEFT JOIN (SELECT user_id FROM `views.cm_reach_users`) cm USING (user_id)
  LEFT JOIN `views.reach_voters_wide` USING (reach_id)
WHERE cm.user_id IS NULL AND (voting_status IS NULL OR voting_status NOT IN ("Early Voted", "Ballot Received"))
ORDER BY user_name
