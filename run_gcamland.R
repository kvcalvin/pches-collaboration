run_gcamland <- function(SCEN3="FALSE") {
  setwd("./gcamland")
  devtools::load_all('.')
  source("R/generate_price_data.R")
  myScen <- PCHES.SCENARIO.INFO
  if(SCEN3 == "TRUE") {
    myScen$mIncludeConstraint <- TRUE
  } 
  run_model(myScen, aVerbose=TRUE)
  export_results(myScen)
  setwd("..")
}
