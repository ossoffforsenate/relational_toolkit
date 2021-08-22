SELECT DISTINCT note_text AS reach_user_id, myc_van_id, myv_van_id
FROM `voter_contact_data.contacts_notes_myc`
  JOIN `voter_contact_data.person_records_myc` USING (myc_van_id)
WHERE note_category_name = "Reach ID"
