SELECT 
  reach_id,
  MAX(IF(name_short = "ID", response_value, NULL)) AS support_id,
  MAX(IF(name_short = "ID", response_numeric, NULL)) AS support_id_numeric,
  MAX(IF(name_short = "Plan", response_value, NULL)) AS vote_plan,
  MAX(IF(name_short = "Detailed Plan", response_value, NULL)) AS detailed_plan,
  MAX(IF(name_short = "Vol Ask", response_value, NULL)) AS vol_ask,
  MAX(IF(name_short = "Triplers", response_value, NULL)) AS triplers,
  MAX(IF(name_short = "OutReach", response_value, NULL)) AS outreach
FROM `views.reach_runoff_responses`
GROUP BY reach_id
