# *****************************************************
# * Process IMPLAN & DNDC input into gcamland formats
# *
# * First, calculate USA prices from IMPLAN by taking
# * weighted average of regional prices
# *
# * Then, calculate ag prod growth from DNDC yield multipliers
# *****************************************************

library(tidyr)
library(dplyr)

# ==============
# Set current year
CURRENT.YEAR <- 2015
SCEN.NAME <- "BAU"
DNDC.FILE.NAME <- "DNDCInputs/DNDCe_to_IMPLAN_yield_deficit_STATE_scenario_1state_iteration_1.csv"
REM.FILE.NAME <- "REMInputs/DREM_state_scenario1_iteration1_prices.csv"

# ==============
# Calculate weighted-average prices
run_process_inputs <- function(DNDC_FILE=DNDC.FILE.NAME, DREM_FILE=REM.FILE.NAME, SCEN_NAME=SCEN.NAME) {
  # Read in data
  reg_mapping <- read.csv("./mapping.csv")
  price <- read.csv(DREM_FILE)
  price_template <- read.csv("./ExampleFiles/AgPrices_PCHES_template.csv", skip = 1)
  
  # Tidy data
  price %>%
    rename(sector = X.1, State = X) %>%
    gather(year, rem_price, -sector, -State) ->
    price
  
  # Map these to the gcamland price file
  price_template %>%
    gather(year, value, -scenario, -region, -subregion, -sector, -Units) %>%
    left_join(reg_mapping, by=c("subregion" = "GCAM_state")) %>%
    left_join(price, by=c("REM_region" = "State", "sector", "year")) %>%
    select(-value) %>%
    spread(year, rem_price) %>%
    replace_na(list(X2010 = 1, X2015 = 1, X2020 = 1, X2050 = 1)) %>%
    select(scenario, region, subregion, sector, X2010, X2015, X2020, X2050, Units) %>%
    mutate(scenario = SCEN_NAME) ->
    gcamland_price
  
  # Write output
  cat('AgPrices \n',  file = "./FinalInput/AgPrices_PCHES.csv")
  write.table(gcamland_price, "./FinalInput/AgPrices_PCHES.csv", row.names = FALSE, append = TRUE, sep=",")
  
  # ==============
  # Calculate ag prod change
  
  # Read data
  DNDC <- read.csv(DNDC_FILE)
  gcamland_APG <- read.csv("./ExampleFiles/AgProdChange_PCHES_template.csv")
  
  # Reformat data
  DNDC %>%
    select(-X) %>%
    gather(subregion, multiplier, -IMPLAN_crop) %>%
    # Multipliers of 0 only happen when region doesn't produce. For gcamland, make those equal to 1
    mutate(multiplier = if_else(multiplier == 0, 1, multiplier)) %>%
    # Rename states
    mutate(subregion = if_else(subregion == "New.Mexico", "New Mexico", subregion)) %>%
    # Construct supplysector name and compute ag prod growth
    mutate(AgSupplySubsector = paste(IMPLAN_crop, subregion, sep="_"),
           NewAgProdChange = multiplier^(1/5) - 1,
           year = CURRENT.YEAR) %>%
    select(AgSupplySubsector, year, NewAgProdChange) ->
    DNDC_formatted
  
  # Map in APG
  gcamland_APG %>%
    left_join(DNDC_formatted, by=c("AgSupplySubsector", "year")) %>%
    mutate(AgProdChange = as.numeric(AgProdChange)) %>%
    # Remove NA
    replace_na(list(NewAgProdChange = 0)) %>%
    # These deficits only affect irrigated crops
    mutate(AgProdChange = if_else(grepl("Irrigated", AgProductionTechnology), NewAgProdChange, AgProdChange)) %>%
    select(-NewAgProdChange) ->
    updated_gcamland_APG
  
  write.csv(updated_gcamland_APG, "./FinalInput/AgProdChange_PCHES.csv", row.names = FALSE)
}
