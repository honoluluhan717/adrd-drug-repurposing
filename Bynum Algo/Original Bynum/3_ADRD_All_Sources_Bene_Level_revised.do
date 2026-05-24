/*start-header
################################################################################
#
# Purpose           : Combine Hospital Outpatient File (HOF) Service-Date-Level ADRD claims 
#                     with Carrier File Serive-Date-Level ADRD claims to produce beneficiary-level file
#                     that includes only those with 2+ claims that are 7+ days apart
#
# Input files       : bene_adrd_HOF_Carrier_`year' (output from 2_ADRD_Carrier_HOF_Bene_Level) 
#                     bene_adrd_MedPAR_`year' (output from 1_ADRD_MedPAR_Claims)
#                     bene_adrd_HHA_`year' (output from 1_ADRD_HHA_Claims)
#                     bene_adrd_Hospice_`year' (output from 1_ADRD_Hospice_Claims)
#
# Output files      : bene_ADRD_all_sources_&year.
#
# Notes             : Update below local variables as necessary
#
################################################################################
end-header*/


/*****************************************************************************/
/* START - USERS MUST UPDATE */
/*****************************************************************************/
* Update the paths to fit your file setup;
local output_folder "J:\Geriatrics\Litke_CMS\2019\Output\in_progress"  /* Update with location where files from previous step are saved */

* Update the following macro variables to fit your file;
local HOF_Carrier_file_name = "bene_adrd_HOF_Carrier_2019" /* Name of the HOF/Carrier Bene-level file */
local MedPAR_file_name = "bene_adrd_medpar_2019" /* Name of the MedPAR Bene-level file */
local Hospice_file_name = "bene_adrd_hospice_2019" /* Name of the Hospice Bene-level file */
local data_year = 2019 /* Used in File Names - See "Output files" above */


/*****************************************************************************/
/* END - USERS MUST UPDATE */
/*****************************************************************************/

cd "`output_folder'"
use `HOF_Carrier_file_name', clear
merge 1:1 BENE_ID using `MedPAR_file_name'
	drop _merge

merge 1:1 BENE_ID using `Hospice_file_name'
	drop _merge
	
replace MEDPAR_ADRD_DX = 0 if MEDPAR_ADRD_DX == .
replace MEDPAR_ADRD_CLMS = 0 if MEDPAR_ADRD_CLMS == .

replace HOSPICE_ADRD_DX = 0 if HOSPICE_ADRD_DX == .
replace HOSPICE_ADRD_CLMS = 0 if HOSPICE_ADRD_CLMS == .

replace HOF_CARRIER_ADRD_DX = 0 if HOF_CARRIER_ADRD_DX == .
replace HOF_CARRIER_ADRD_CLMS = 0 if HOF_CARRIER_ADRD_CLMS == .

 
tab1 MEDPAR_ADRD_DX MEDPAR_ADRD_CLMS HOSPICE_ADRD_DX HOSPICE_ADRD_CLMS HOF_CARRIER_ADRD_DX HOF_CARRIER_ADRD_CLMS, missing

codebook

save "bene_ADRD_all_sources_`data_year'.dta", replace