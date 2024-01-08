# Calculate number and pct of people within drive time polygons and outside
# For bordering polygons, asign population proportionally using calculated overlap field

#######################
source("R/01-setup.R")
#######################

# bg_overlap <- read.csv("data/09-get-census-population/block-group-isochrone-overlap.csv", colClasses = c("geoid" = "character"))
#
# #done in exploratory.io
# table_of_women_for_map <- read_csv("data/09-get-census-population/table_of_women_for_map.csv") %>% select(-NAME)
#
# demographics <- read_csv("data/09-get-census-population/trying_to_make_demographics_bg.csv") %>%
#   separate(NAME, into = c("block_group", "tract", "county", "fips_state"), sep = ";", remove = FALSE) %>%
#   left_join(table_of_women_for_map, by = "GEOID") %>%
#   rename(population = race_universe_number)
# write_csv(demographics, "data/10-calculate-polygon-demographics/demographics.csv")

#View(demographics)

regions <- read.csv("data/fips-appalachia-delta.csv", colClasses = c("fips_county" = "character"))
state_fips <- read.csv("data/fips-states.csv", colClasses = "character")
state_fips <- state_fips %>% select(fips_state, state_code)

###########################################################################
# Join files
###########################################################################
# bg_full <- full_join(demographics, bg_overlap, by = c("GEOID" = "geoid"))
#
# # nonmatch
# nonmatch <- bg_full %>% filter(is.na(fips_state))
# summary(nonmatch$population)
#
# # A couple blocks have nonzero population, investigate further
# nonmatch_check <- nonmatch %>% filter(population > 0)
#
# # Actual join to use
# bg <- left_join(bg_overlap, demographics, by = c("geoid" = "GEOID")) %>%
#   impute_na(overlap, type = "value", val = 0) %>%
#   mutate(state_code = str_sub(geoid,1 ,2))
#
# colnames(bg)
# bg <- bg %>% select(fips_state, state_code, geoid, everything())
# head(bg)
#
# write_csv(bg, "data/10-calculate-polygon-demographics/bg.csv")

###########################################################################
# Calculate population in/out of isochrones by state
###########################################################################

# Jesus I did this in exploratory and it just works
state_sums <- read_csv("data/08.5-prep-the-census-variables/end_state_sums.csv")

paste0("within_total:  ", format_and_round(state_sums$within_total), " is the total female population of all ages covered by the isochrones: sum(population * overlap)")

paste0("population_total: ", format_and_round(state_sums$population_total), " is the total female population.")

paste0("within_black: ", format_and_round(state_sums$within_black), " is the number of black women of all ages covered by the isochrones.")

paste0("population_black: ", format_and_round(state_sums$population_black), " is the total Black female population.")

paste0("within_white: ", format_and_round(state_sums$within_white), " is the number of white women of all ages covered by the isochrones.")

paste0("population_white: ", format_and_round(state_sums$population_white), " is the total White female population.")

paste0("within_two_numbers: ", format_and_round(state_sums$within_two_number), " is the number of women of two races of all ages covered by the isochrones.")

paste0("population_two_number: ", format_and_round(state_sums$population_two_number), " is the number of women describing two races of all ages covered by the isochrones.")

paste0("within_nhpi: ", format_and_round(state_sums$within_nhpi), " is the number of Native Hawaiian/Pacific Islander women population of all ages covered by the isochrones.")

paste0("population_nhpi: ", format_and_round(state_sums$population_nhpi), " is the number of women describing Native Hawaiian/Pacific Islanders of all ages.")

paste0("within_hispanic: ", format_and_round(state_sums$within_hispanic), " is the number of Hispanic women population of all ages covered by the isochrones.")

paste0("population_hispanic ", format_and_round(state_sums$population_hispanic), " is the number of women describing Hispanic women of all ages.")





# summary(bg$overlap)
# state_sums <- bg %>% #select(state_code, geoid, population, race_black_number, race_white_number) %>%
#   #pivot_longer(cols = starts_with("overlap_"), names_to = "certification_type", values_to = "overlap") %>%
#   group_by(state_code) %>%
#   summarize(within_total = sum(population * overlap),
#             population_total = sum(population),
#             within_black = sum(race_black_number * overlap),
#             population_black = sum(race_black_number),
#             within_white = sum(race_white_number * overlap),
#             population_white = sum(race_white_number)) %>%
#   mutate(within_total_pct = within_total/population_total,
#          within_black_pct = within_black/population_black,
#          within_white_pct = within_white/population_white) %>%
#   select(state_code, certification_type, ends_with("_pct"), everything()) %>%
#   ungroup() %>%
#   mutate(certification_type = case_when(
#     certification_type == "overlap_all" ~ "any",
#     certification_type == "overlap_c" ~ "compthromb"
#   ))


# Make table for use in story, charts
# Ridiculous pivoting but it works
# state_table <- state_sums %>% select(state_code, certification_type,
#                                      within_total_pct, within_black_pct, within_white_pct) %>%
#   pivot_wider(names_from = certification_type, values_from = starts_with("within"), names_prefix = "type_") %>%
#   pivot_longer(-state_code, names_sep = "_pct_type_",
#                names_to = c("race", "certification_type"), values_to = "within_pct") %>%
#   pivot_wider(names_from = certification_type, values_from = within_pct) %>%
#   rename(within_any = any, within_compthromb = compthromb) %>%
#   mutate(within_none = 1 - within_any,
#          within_primaryacute_only = within_any - within_compthromb) %>%
#   select(state_code, race, within_none, within_primaryacute_only, within_compthromb, within_any) %>%
#   mutate(race = case_when(race == "within_total" ~ "Total",
#                           race == "within_black" ~ "Black",
#                           race == "within_white" ~ "White"))
#
# write.csv(state_table, "data/state-stroke-access.csv", na = "", row.names = F)

# Chart data
state_chart <- state_table %>% filter(race == "Total" & state_code != "NY") %>%
  arrange(within_any)

# Add names
state_names <- read.csv("data/fips-states.csv", colClasses = "character")
state_names <- state_names %>% select(state_name, state_code)
state_chart <- left_join(state_chart, state_names, by = "state_code")
state_chart <- state_chart %>% select(state_name, within_none, within_primaryacute_only, within_compthromb)

write.csv(state_chart, "data/state-stroke-chart.csv", na = "", row.names = F)
#
# ###########################################################################
# # Calculate population in/out of isochrones by region
# ###########################################################################
# regions_min <- regions %>% select(fips_county, delta, appalachia)
# bg <- left_join(bg, regions_min, by = "fips_county")
#
# delta <- bg %>% filter(delta == 1 )%>%
#   select(geoid, overlap_all, overlap_c, population, race_black_number, race_white_number) %>%
#   pivot_longer(cols = starts_with("overlap_"), names_to = "certification_type", values_to = "overlap") %>%
#   group_by(certification_type) %>%
#   summarize(within_total = sum(population * overlap),
#             population_total = sum(population),
#             within_black = sum(race_black_number * overlap),
#             population_black = sum(race_black_number),
#             within_white = sum(race_white_number * overlap),
#             population_white = sum(race_white_number)) %>%
#   mutate(within_total_pct = within_total/population_total,
#          within_black_pct = within_black/population_black,
#          within_white_pct = within_white/population_white) %>%
#   mutate(region = "Mississippi Delta") %>%
#   select(region, certification_type, ends_with("_pct"), everything()) %>%
#   ungroup() %>%
#   mutate(certification_type = case_when(
#     certification_type == "overlap_all" ~ "any",
#     certification_type == "overlap_c" ~ "compthromb"
#   ))
#
# appalachia <- bg %>% filter(appalachia == 1 )%>%
#   select(geoid, overlap_all, overlap_c, population, race_black_number, race_white_number) %>%
#   pivot_longer(cols = starts_with("overlap_"), names_to = "certification_type", values_to = "overlap") %>%
#   group_by(certification_type) %>%
#   summarize(within_total = sum(population * overlap),
#             population_total = sum(population),
#             within_black = sum(race_black_number * overlap),
#             population_black = sum(race_black_number),
#             within_white = sum(race_white_number * overlap),
#             population_white = sum(race_white_number)) %>%
#   mutate(within_total_pct = within_total/population_total,
#          within_black_pct = within_black/population_black,
#          within_white_pct = within_white/population_white) %>%
#   mutate(region = "Appalachia") %>%
#   select(region, certification_type, ends_with("_pct"), everything()) %>%
#   ungroup() %>%
#   mutate(certification_type = case_when(
#     certification_type == "overlap_all" ~ "any",
#     certification_type == "overlap_c" ~ "compthromb"
#   ))
#
# region_sums <- bind_rows(appalachia, delta)
#
# # Make table for use in story, charts
# # Ridiculous pivoting but it works
# region_table <- region_sums %>% select(region, certification_type,
#                                        within_total_pct, within_black_pct, within_white_pct) %>%
#   pivot_wider(names_from = certification_type, values_from = starts_with("within"), names_prefix = "type_") %>%
#   pivot_longer(-region, names_sep = "_pct_type_",
#                names_to = c("race", "certification_type"), values_to = "within_pct") %>%
#   pivot_wider(names_from = certification_type, values_from = within_pct) %>%
#   rename(within_any = any, within_compthromb = compthromb) %>%
#   mutate(within_none = 1 - within_any,
#          within_primaryacute_only = within_any - within_compthromb) %>%
#   select(region, race, within_none, within_primaryacute_only, within_compthromb, within_any) %>%
#   mutate(race = case_when(race == "within_total" ~ "Total",
#                           race == "within_black" ~ "Black",
#                           race == "within_white" ~ "White"))
# write.csv(region_table, "data/appalachia-delta-stroke-access.csv", na = "", row.names = F)
