#!/bin/bash   

# Set environment variables
export SCEN_NAME="Scen1_Iter1"
export DREM_FILE_NAME="DREM_test.csv"
export DNDC_FILE_NAME="DNDC_test.csv"
export ITER1="TRUE"

# Clone gcamland
# Using clone instead of install_github because we need to know where it is installed
if [ ! -d "gcamland" ]; then
	echo "Cloning gcamland"
	git clone https://github.com/JGCRI/gcamland.git
	cd gcamland
	git checkout pches-statesandconstraints
	cd ..
fi

# Next, make directories, copy files from DNDC & DREM
mkdir -p DNDCInputs
mkdir -p DREMInputs
mkdir -p FinalInput

cp $DREM_FILE_NAME ./DREMInputs
cp $DNDC_FILE_NAME ./DNDCInputs

# Then, run the pre-processing code
Rscript -e "source('./process_inputs.R'); run_process_inputs('$DNDC_FILE_NAME', '$DREM_FILE_NAME', '$SCEN_NAME', '$ITER1')"

# Next, copy the pre-processing results into the gcamland directory
cp ./FinalInput/AgPrices_PCHES.csv ./gcamland/inst/extdata/scenario-data/
cp ./FinalInput/AgProdChange_PCHES.csv ./gcamland/inst/extdata/scenario-data/

# Now, run gcamland
Rscript -e "source('./run_gcamland.R')"

# Next, copy outputs to the right directory
mkdir -p FinalOutput
cp ./gcamland/outputs/output_Reference_Perfect_PCHES.csv FinalOutput
Rscript -e "source('./process_output.R'); run_process_outputs('$SCEN_NAME')"