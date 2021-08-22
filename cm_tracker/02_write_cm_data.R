library(googlesheets4)
library(lubridate)
library(tidyverse)
library(jsonlite)

get_spreadsheet <- function() {
  sheet_ids <-
    gs4_find() %>%
    filter(name ==  "[PUBLIC DEMO] Ossoff: Community Mobilization Tracker DATA") %>%
    pull(id)

  sheet_names <-
    c(
      "cm_voters_wide",
      "cm_topline_cm",
      "cm_topline_rmm",
      "cm_topline_pod",
      "cm_topline_program",
      "cm_growth_metrics_program",
      "cm_growth_metrics_pod",
      "cm_growth_metrics_rmm"
    )

  if (length(sheet_ids) == 0) {
    ss <- gs4_create(
      name = "[PUBLIC DEMO] Ossoff: Community Mobilization Tracker DATA",
      sheets = sheet_names
    )
  } else {
    ss <- gs4_get(sheet_ids[[1]])
    map(sheet_names, . %>% range_clear(ss, sheet = .))
  }
  ss
}

# Assumes `df` is grouped by relevant variables.
compute_topline <- function(df) {
  cm_days <-
    df %>%
    distinct(user_id, cm_days) %>%
    summarize(cm_days = sum(cm_days))

  df %>%
    summarize(
      users = n_distinct(user_id),
      matched_voters = sum(sos_id != "Reach Add"),
      reach_adds = sum(sos_id == "Reach Add"),
      ids = sum(!is.na(support_id_numeric)),
      plans = sum(vote_plan != ""),
      votes = sum(voting_status == "Has Voted!"),
      pct_votes = votes / matched_voters,
      pct_matched_voters =
        matched_voters / (matched_voters + reach_adds),
      support_id_ones =
        sum(support_id_numeric == 1, na.rm = TRUE),
      support_id_twos =
        sum(support_id_numeric == 2, na.rm = TRUE),
      support_id_threes =
        sum(support_id_numeric == 3, na.rm = TRUE),
      support_id_fours =
        sum(support_id_numeric == 4, na.rm = TRUE),
      support_id_fives =
        sum(support_id_numeric == 5, na.rm = TRUE),
      avg_support_id =
        mean(support_id_numeric, na.rm = TRUE),
      num_nonvoting_voters =
        sum(sos_id != "Reach Add" & voting_status != "Has Voted!"),
      nonvoting_support_ids	= sum(
        sos_id != "Reach Add" &
        !is.na(support_id_numeric) &
          voting_status != "Has Voted!"
      ),
      pct_nonvoting_support_ids =
        nonvoting_support_ids / num_nonvoting_voters,
      nonvoting_plans = sum(
        sos_id != "Reach Add" &
        vote_plan != "" & voting_status != "Has Voted!"
      ),
      pct_nonvoting_plans =
        nonvoting_plans / num_nonvoting_voters,
      tier1 = sum(tier == "1"),
      tier2 = sum(tier == "2"),
      tier3 = sum(tier == "3"),
      tier4 = sum(tier == "4")
    ) %>%
    left_join(cm_days) %>%
    mutate(cm_days, voters_per_cm_week = matched_voters / cm_days * 7)
}

compute_growth_metrics <- function(df, template) {
  build_group_tibble <- function(users, matched_voters, reach_adds, votes, voters_per_cm_week, ...) {
    random_group <-
      template %>%
      distinct(group) %>%
      sample_n(size = 1) %>%
      .[[1]]

    template %>%
      filter(group == random_group) %>%
      transmute(
        ...,
        day,
        users = round(users_ptg * users),
        matched_voters = round(matched_voters_ptg * matched_voters),
        reach_adds = round(reach_adds_ptg * reach_adds),
        votes = round(votes_ptg * votes),
        pct_votes = votes / matched_voters,
        voters_per_cm_week = voters_per_cm_week_ptg * voters_per_cm_week
      ) %>%
      arrange(day)
  }

  df %>%
    pmap_dfr(build_group_tibble)
}


df <-
  fromJSON(here::here("toolkit/cm_data.json")) %>%
  map_if(is.data.frame, list) %>%
  as_tibble() %>%
  pivot_longer(everything(), names_to = "pod", values_to = "rmms") %>%
  unnest(cols = c(rmms)) %>%
  unnest(cols = c(cms)) %>%
  rename(cm_voting_status = voting_status) %>%
  unnest(cols = c(network)) %>%
  mutate(
    date_joined = parse_date(date_joined),
    support_id_numeric = as.integer(support_id_numeric),
    cm_days = interval(date_joined, ymd(20210106)) / days(1)
  )

gs4_auth(email = "")
ss <- get_spreadsheet()

## cm_topline_cm ##
df %>%
  group_by(user_id, date_joined, cm_days, last_activity, user_name, email_address, phone_number, rmm, pod) %>%
  compute_topline() %>%
  ungroup() %>%
  left_join(distinct(df, user_id, cm_voting_status), by = "user_id") %>%
  sheet_write(ss, sheet = "cm_topline_cm")

## cm_topline_rmm ##
df %>%
  group_by(rmm, pod) %>%
  compute_topline() %>%
  ungroup() %>%
  sheet_write(ss, sheet = "cm_topline_rmm")

## cm_growth_metrics_rmm ##
df %>%
  group_by(rmm, pod) %>%
  compute_topline() %>%
  select(rmm, pod, users, matched_voters, reach_adds, votes, voters_per_cm_week) %>%
  compute_growth_metrics(
    read_csv(here::here("toolkit", "cm_growth_metrics_rmm_template.csv"))
  ) %>%
  sheet_write(ss, sheet = "cm_growth_metrics_rmm")

## cm_topline_pod ##
df %>%
  group_by(pod) %>%
  compute_topline() %>%
  sheet_write(ss, sheet = "cm_topline_pod")

## cm_growth_metrics_pod ##
df %>%
  group_by(pod) %>%
  compute_topline() %>%
  select(pod, users, matched_voters, reach_adds, votes, voters_per_cm_week) %>%
  compute_growth_metrics(
    read_csv(here::here("toolkit", "cm_growth_metrics_pod_template.csv"))
  ) %>%
  sheet_write(ss, sheet = "cm_growth_metrics_pod")

## cm_topline_program ##
df %>%
  group_by(program = "CM") %>%
  compute_topline() %>%
  ungroup() %>%
  sheet_write(ss, sheet = "cm_topline_program")

## cm_growth_metrics_program ##
df %>%
  group_by(program = "CM") %>%
  compute_topline() %>%
  ungroup() %>%
  select(users, matched_voters, reach_adds, votes, voters_per_cm_week) %>%
  compute_growth_metrics(
    read_csv(here::here("toolkit", "cm_growth_metrics_program_template.csv"))
  ) %>%
  sheet_write(ss, sheet = "cm_growth_metrics_program")

## cm_voters_wide ##
  # A bit too big for the API, try writing to CSV, then uploading manually to GSheet
df %>%
  select(
    user_id,
    voter,
    user_name,
    email_address,
    phone_number,
    date_joined,
    rmm,
    pod,
    support_id,
    support_id_numeric,
    vote_plan,
    detailed_plan,
    vol_ask,
    triplers,
    outreach,
    sos_id,
    voting_status,
    tier,
    tier_str
  ) %>% count(is.na(sos_id)) %>%
  sheet_write(ss, sheet = "cm_voters_wide")
