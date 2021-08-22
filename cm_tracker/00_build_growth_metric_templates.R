# This file just takes the raw growth metric files (i.e., with real data)
# and converts the raw values to fractions. In `02_write_cm_data.R`, I use these
# to map the fake data to these progressions. (The idea is that I don't mind
# sharing the real trends with the world, but don't want to share the actual
# values.)

mutate_ptg <- function(df, group) {
  group <- enquo(group)
  df %>%
    filter(day <= "2021-01-06") %>%
    select(
      !!group, day, users,
      matched_voters, reach_adds,
      voters_per_cm_week, votes
    ) %>%
    group_by(!!group) %>%
    mutate(across(-day, ~ .x / max(.x, na.rm = TRUE))) %>%
    rename_with(.cols = c(-!!group, -day), str_c, "_ptg") %>%
    rename(group = !!group)
}

read_csv("~/Downloads/cm_growth_metrics_program.csv") %>%
  mutate_ptg(program) %>%
  write_csv("cm_growth_metrics_program_template.csv")

read_csv("~/Downloads/cm_growth_metrics_rmm.csv") %>%
  mutate_ptg(rmm) %>%
  write_csv("cm_growth_metrics_rmm_template.csv")

read_csv("~/Downloads/cm_growth_metrics_pod.csv") %>%
  mutate_ptg(pod) %>%
  write_csv("cm_growth_metrics_pod_template.csv")
