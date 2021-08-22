SELECT user_id, first_name, last_name, email_address, zip_code, state, phone_number
FROM `reach.users`
WHERE user_id NOT IN (
  SELECT note_text
  FROM `voter_contact_data.contacts_notes_myc` WHERE note_category_name = "Reach ID"
)
