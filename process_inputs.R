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
CURRENT.PERIOD <- 2
SCEN.NAME <- "BAU"
DNDC.FILE.NAME <- "DNDCInputs/DNDCe_to_IMPLAN_yield_deficit_STATE_scenario_1state_iteration_1.csv"
REM.FILE.NAME <- "REMInputs/DREM_state_scenario1_iteration1_prices.csv"
WBM.FILE.NAME <- "WBMInputs/WBM_test.csv"

# ==============
# Calculate weighted-average prices
run_process_inputs <- function(DNDC_FILE=DNDC.FILE.NAME, DREM_FILE=REM.FILE.NAME, SCEN_NAME=SCEN.NAME, ITER1="FALSE", SCEN3="FALSE") {
  # For iteration 1, we use BAU prices. For all other iterations, process DREM input
  if(ITER1 == "FALSE") {
    # Read in data
    reg_mapping <- read.csv("./mapping.csv")
    price <- read.csv(DREM_FILE)
    price_template <- read.csv("./ExampleFiles/AgPrices_PCHES_template.csv", skip = 1)
    
    # Tidy data
    price %>%
      gather(year, rem_price, -region, -crop) ->
      price
    
    # Map these to the gcamland price file
    price_template %>%
      gather(year, value, -scenario, -region, -subregion, -sector, -Units) %>%
      left_join(reg_mapping, by=c("subregion" = "GCAM_state")) %>%
      left_join(price, by=c("REM_region" = "region", "sector" = "crop", "year")) %>%
      spread(year, rem_price) %>%
      replace_na(list(X2010 = 1, X2015 = 1, X2020 = 1, X2050 = 1)) %>%
      select(scenario, region, subregion, sector, X2010, X2015, X2020, X2050, Units) %>%
      #    rename(`2010` = X2010, `2015` = X2015, `2020` = X2020, `2050` = X2050) %>%
      mutate(scenario = SCEN_NAME) ->
      gcamland_price
  } else {
    gcamland_price <- read.csv("./gcamland/inst/extdata/scenario-data/AgPrices_PCHES.csv", skip=1)
  }
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
    gather(subregion, multiplier, -IMPLAN_crop) %>%
    # Multipliers of 0 only happen when region doesn't produce. For gcamland, make those equal to 1
    mutate(multiplier = if_else(multiplier == 0, 1, multiplier)) %>%
    # Rename states
    mutate(subregion = if_else(subregion == "New_Mexico", "New Mexico", subregion)) %>%
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
  
  # For scenario 3, we use inputs directly from WBM
  if(SCEN3 == "TRUE") {
    # Read data
    WBM <- read.csv(WBM.FILE.NAME)
    if(grepl("Iter1", SCEN_NAME)) {
      PREV.GCAM.FILE.NAME <- "./BAU_output_PCHES.csv"
    } else {
      name <- substr(SCEN_NAME, 1, nchar(SCEN_NAME)-1)
      iter <- as.integer(substr(SCEN_NAME, nchar(SCEN_NAME), nchar(SCEN_NAME))) - 1
      PREV.GCAM.FILE.NAME <- paste0("./FinalOutput/all_output_PCHES_", name, iter, ".csv")
    }
    gcamland_results <- read.csv(PREV.GCAM.FILE.NAME)
    
    # Calculate total irrigated land by state
    gcamland_results %>%
      filter(grepl("Irrigated", name)) %>%
      separate(name, into=c("crop", "state", "IRR"), sep="_") %>%
      group_by(state, IRR, year) %>%
      summarize(land.allocation = sum(land.allocation)) %>%
      ungroup() %>%
      filter(year == CURRENT.YEAR) %>%
      left_join(WBM, by=c("state" = "X")) %>%
      na.omit() %>%                         # Rest of USA is assumed to not need to reduce ground water
      mutate(value = land.allocation * (1 - ugw.frac),
             period = CURRENT.PERIOD,
             string = paste(state, "Irrigated", sep="_")) %>%
      select(string, period, value) ->   # Only irrigation allowed is amount that isn't unsustainable
      pches_constraint
    
    write.csv(pches_constraint, "./FinalInput/PCHES_constraint.csv", row.names = FALSE)
  }
}
