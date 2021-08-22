library(tidyverse)

read_csv("~/Downloads/cm_topline_cm.csv") %>%
  left_join(read_csv("~/Downloads/reach_users.csv"), by = "user_id") %>%
  select(date_joined, matched_voters, reach_adds) %>% 
  replace_na(list(matched_voters = 0, reach_adds = 0)) %>%
  write_csv("cm_topline_cm_template.csv")
