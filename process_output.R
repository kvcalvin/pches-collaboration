# *****************************************************
# * Process results into an output format for WBM
# *****************************************************

library(tidyr)
library(dplyr)

# ==============
# Set current year
CURRENT.YEAR <- 2015
SCEN.NAME <- "Scen1_Iter1"

# ==============
# Read gcamland output
bau_output <- read.csv("./BAU_Output_PCHES.csv")
cntf_output <- read.csv("./FinalOutput/output_Reference_Perfect_PCHES.csv")

# ==============
# Filter for states
PCHES_STATES <- c("Washington", "Oregon", "California", "Arizona", "New Mexico",
                  "Utah", "Nevada", "Colorado", "Idaho", "Montana", "Wyoming")

run_process_outputs <- function( SCEN_NAME = SCEN.NAME ) {
  # ==============
  # Calculate ratio to BAU
  bau_output %>%
    select(name, year, land.allocation) %>%
    rename(BAU.land = land.allocation) ->
    bau_output
  
  cntf_output %>%
    filter(!is.na(harvested.land)) %>% # Only include crops
    select(name, year, land.allocation) %>%
    left_join(bau_output, by=c("name", "year")) %>%
    mutate(delta.land = land.allocation / BAU.land) %>%
    rename(CurrIteration.land = land.allocation) %>%
    filter(year == CURRENT.YEAR) %>%
    arrange(name) ->
    pches_output
  
  # =============
  # Filter for PCHES states and reformat
  pches_output %>%
    separate(name, into=c("Crop", "State", "Management"), sep="_") %>%
    filter(State %in% PCHES_STATES) ->
    pches_output
  
  # =============
  # Format for easier import into DREM
  pches_output %>%
    mutate(State = if_else(State == "New Mexico", "New_Mexico", State)) %>%
    rename(CurrIteration_Land = CurrIteration.land) %>% 
    rename(BAU_land = BAU.land ) %>% 
    rename(delta_land = delta.land) ->
    pches_output
  
  write.csv(pches_output, paste0("./FinalOutput/pches_output_", SCEN_NAME, ".csv"), row.names = FALSE)
}