/*start-header
################################################################################
#
# Purpose           : Get CARRIER ADRD claims for a single year of data using Julie Bynum definitions
#
# Input files       : Single year of CARRIER data (.sas7bdat format; both Line and Claims files)
#
# Output files      : diag_adrd_carrier_&year    : Beneficiary-Diagnosis level file with all ADRD Dx. codes found in claims
#                     servdt_adrd_carrier_&year  : Beneficiary-Service Date level file derived from diag_adrd_carrier_&year
#
# Notes             : Update below local variables as necessary
#
#                     Program assumes that the diagnosis variables (often ICD_DGNS_CD1 - ICD_DGNS_CD12)
#                     are sequential. If this is not the case for your files, you may need
#                     to find the locations of macro variables `dx_first' and `dx_last'
#                     to update the list to match your data using individual variable names
#                     or other methods appropriate for your data. (as tested, non-sequential
#					  diagnosis variables have not been an issue, but will at least cause inefficiency)
#
################################################################################
end-header*/
clear

cd "~" /* set WD to root */

/*****************************************************************************/
/* START - USERS MUST UPDATE */
/*****************************************************************************/
* Update the paths to fit your file setup;
local output_folder "PATH"  /* Update with location where files from previous step are saved */


* Update the following macro variables to fit your file;
local HOF_file_name = "servdt_adrd_hof_2018.dta" /* Name of the HOF Claim file */
local Carrier_file_name = "servdt_adrd_carrier_2018.dta" /* Name of the HOF Revenue Center file */
local data_year = 2018 /* Used in File Names - See "Output files" above */

/*****************************************************************************/
/* END - USERS MUST UPDATE */
/*****************************************************************************/

cd "`output_folder'"

use `HOF_file_name', clear
append using  `Carrier_file_name'

sort BENE_ID SERVICE_DT SERVICE_THRU_DT

display "benes and observations BEFORE collapsing on visit"
codebook BENE_ID


/* Collapse to Beneficiary level */
gen one_placeholder = 1
collapse (count) HOF_CARRIER_ADRD_CLMS=one_placeholder (min) MIN_SERVICE_DT=SERVICE_DT (max) MAX_SERVICE_DT=SERVICE_DT, by(BENE_ID ADRD_DX)

display "benes and observations AFTER collapsing on visit"
codebook BENE_ID

generate TIME_BETWEEN_DX = (MAX_SERVICE_DT - MIN_SERVICE_DT)
generate GE7 = 0 
	replace GE7=1 if TIME_BETWEEN_DX >= 7 & TIME_BETWEEN_DX != .

sort GE7	

bysort GE7: summarize TIME_BETWEEN_DX
	
keep if GE7==1

drop GE7 MIN_SERVICE_DT MAX_SERVICE_DT TIME_BETWEEN_DX


* final cleanup
generate HOF_CARRIER_ADRD_DX = ADRD_DX

label variable HOF_CARRIER_ADRD_CLMS "Total number of ADRD claims by bene_id in HOF/CARRIER"
label variable HOF_CARRIER_ADRD_DX "In HOF/CARRIER, presence of ADRD diagnosis. 1/0"

tab1 ADRD_DX HOF_CARRIER_ADRD_DX HOF_CARRIER_ADRD_CLMS

save "bene_adrd_HOF_Carrier_`data_year'.dta", replace

codebook, compact















