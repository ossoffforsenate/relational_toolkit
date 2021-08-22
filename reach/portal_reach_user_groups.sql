SELECT 
  DISTINCT user_id, 
  CASE
    WHEN cm_reach_users.user_id IS NOT NULL THEN "ef9c1747-4610-4591-97be-bd29b05e2571" ## Community Mobilizers
    WHEN state <> "GA" THEN "38a46928-bc34-4160-b379-c0c44e209f78" ## Out-of-state
    ELSE "4b3aeade-08a1-4279-afc0-2a3ab44529e8" ## Everyone else
  END AS group_id
FROM reach.users
  LEFT JOIN `views.cm_reach_users` cm_reach_users USING (user_id)
