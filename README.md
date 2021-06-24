# pches-collaboration

This repository includes all of the code and scripts used to run `gcamland` coupled to WBM, DNDC, and DREM in the PCHES project. The repository includes:
 - `run_gcamland.sh`: the main bash script that runs all code
 - `process_inputs.R`: an R script that reformats the outputs of DNDC and DREM so they can be used as inputs into `gcamland`
 - `run_gcamland.R`: an R script that runs `gcamland`
 - `process_output.R`: an R script that reformats the `gcamland` outputs so that they can be used by DREM and WBM
 
 We also include template files (in the `ExampleFiles` folder) to help with the input data reformatting, a mapping file (`mapping.csv`) between DREM regions and `gcamland` states, and example output files from DREM (`DREM_test.csv`) and DNDC (`DNDC_test.csv`) to show the format expected and use for testing. The final `gcamland` outputs will be put in a folder called `FinalOutput` when the run is completed.