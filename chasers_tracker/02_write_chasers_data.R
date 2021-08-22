library(googlesheets4)
library(lubridate)
library(tidyverse)
library(jsonlite)

get_spreadsheet <- function() {
  sheet_ids <-
    gs4_find() %>%
    filter(name ==  "[PUBLIC DEMO] Ossoff: Relational Chasers") %>%
    pull(id)

  sheet_names <-
    c(
      "users_export_raw",
      "voters_reached_raw"
    )

  ss <- gs4_get(sheet_ids[[1]])
  map(sheet_names, . %>% range_clear(ss, sheet = .))
  ss
}

df <-
  here::here("chasers_tracker", "chasers_data.json") %>%
  fromJSON() %>%
  map_if(is.data.frame, list) %>%
  as_tibble() %>%
  pivot_longer(everything(), names_to = "dummy", values_to = "users") %>%
  select(-dummy) %>%
  unnest(users) %>%
  unnest(network) %>%
  mutate(across(date_joined, parse_date))

gs4_auth(email = "")
ss <- get_spreadsheet()

## users_export_raw ##
df %>%
  group_by(
    user_id, user_name,
    phone_number, date_joined,
    zip_code, state
  ) %>%
  summarize(
    voters = n(),
    matched_voters = sum(auto_applied_tag == "Voter"),
    voters_voted = sum(voting_status == "Has Voted!"),
    voters_uncontactable = sum(only_reachable_by_reacher == "y")
  ) %>%
  ungroup() %>%
  arrange(date_joined) %>%
  relocate(zip_code, state, .after = voters_uncontactable) %>%
  sheet_write(ss, sheet = "users_export_raw")

## voters_reached_raw ##
df %>%
  select(
    reach_id,
    user_id,
    user_name,
    auto_applied_tag,
    person_first_name,
    person_last_name,
    support_id,
    vote_plan,
    detailed_plan,
    vol_ask,
    voting_status,
    only_reachable_by_reacher,
    triplers,
    tier
  ) %>%
  arrange(user_name) %>%
  sheet_write(ss, sheet = "voters_reached_raw")
