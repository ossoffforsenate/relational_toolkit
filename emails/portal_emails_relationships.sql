SELECT reach_id, SUBSTRING(state_file_id, 4) AS sos_id, user_id, user_name, relationship_type
FROM `reach.relationships` 
WHERE relationship_status = "Active" AND state_file_id IS NOT NULL
