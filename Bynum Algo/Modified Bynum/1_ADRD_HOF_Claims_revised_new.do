/*start-header
################################################################################
#
# Purpose           : Get Hospital Outpatient File (HOF) ADRD claims for a single year of data using Julie Bynum definitions
#
# Input files       : Single year of HOF data (.sas7bdat format; both Revenue and Claims files)
#
# Output files      : diag_adrd_hof_&year    : Beneficiary-Diagnosis level file with all ADRD Dx. codes found in claims
#                     servdt_adrd_hof_&year  : Beneficiary-Service Date level file derived from diag_adrd_hof_&year
#
# Notes             : Update below local variables as necessary
#
#                     Program assumes that the diagnosis variables (often ICD_DGNS_CD1 - ICD_DGNS_CD25)
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
local output_folder "J:\Geriatrics\Litke_CMS\2019\Output\in_progress\new_bynum" /* update with location of you want data stored to */
local medicare_folder "J:\Geriatrics\Litke_CMS\2019\Raw Data\bynum codes" /* update with location of medicare data */


* Update the following macro variables to fit your file;
* Use UPPER CASE for variable names;
local claim_file_name = "op19clms.sas7bdat"
local rev_file_name = "op19revs.sas7bdat"
local data_year = 2019 /* Used in File Names - See "Output files" above */
local claim_begin_date = "CLM_FROM_DT" /* If necessary, update with the variable name of the claim from/admission date */
local claim_thru_date = "CLM_THRU_DT" /* If necessary, update with the variable name of the claim thru/discharge date */
local dx_prncpal = "PRNCPAL_DGNS_CD" /* If necessary, update with the variable name of the ADMITTING diagnosis code in your data */
local dx_first = "ICD_DGNS_CD1" /* If necessary, update with the variable name of the FIRST diagnosis code in your data */
local dx_last = "ICD_DGNS_CD25" /* If necessary, update with the variable name of the LAST diagnosis code in your data */
local clm_query_code = "CLAIM_QUERY_CODE" /* if necessary, updated with variable name of the Claim Query Code */
local claim_id = "CLM_ID" /* If necesscary, update with variable name of the Claim ID in the revenue and Claim files */
local provider_num = "PRVDR_NUM" /* If necessary, update with the variable name of the Provider Number in your data */
local claim_fac_type_code = "CLM_FAC_TYPE_CD" /* If necessary, update with the variable name of the Claim Facility Type Code in your data */
local claim_srvc_class_code = "CLM_SRVC_CLSFCTN_TYPE_CD" /* If necessary, update with the variable name of the Claim Service Classification Type Code in your data */
local rev_cntr_code = "REV_CNTR" /* If necessary, update with the variable name of the Revenue Center Code in your data */
local revenue_date = "REV_CNTR_DT" /* If necessary, update with the variable name of the Revenue Center Date */

/*****************************************************************************/
/* END - USERS MUST UPDATE */
/*****************************************************************************/

local DemDx "F0150 F0151 F0280 F0281 F0390 F0391 G300 G301 G308 G309 G3101 G3109 G3183 F04 G311 G312 R4181 G310 G3184 F067 2900 2901 29010 29011 29012 29013 2902 29020 29021 2903 2904 29040 29041 29042 29043 2941 29410 29411 2942 29420 29421 331 3310 33111 33119 33182 2908 2940 3312 3317 3318 33189 797"

* import the Revenue file
local vars_to_keep	BENE_ID `claim_id' `claim_id' `revenue_date' `rev_cntr_code'

cd "`medicare_folder'"
import sas using `rev_file_name', clear case(upper)
keep `vars_to_keep'

sort BENE_ID `claim_id'

tempfile revenue
save `revenue'


* import the line file
local vars_to_keep 	BENE_ID `claim_id' `clm_query_code' `claim_begin_date' `claim_thru_date' `dx_prncpal' `dx_first'-`dx_last' `provider_num' `claim_fac_type_code' `claim_srvc_class_code'


import sas using `claim_file_name', clear case(upper)
keep `vars_to_keep'
keep if `clm_query_code' == "3"


sort BENE_ID `claim_id' 

merge 1:m BENE_ID `claim_id' using `revenue'


generate RHC_FQHC = 0
	replace RHC_FQHC = 1 if (`claim_fac_type_code'=="7" & inlist(`claim_srvc_class_code', "1", "3") & inrange(`rev_cntr_code', "0510", "0529"))

generate CAH_Opt2 = 0
	replace CAH_Opt2 = 1 if (substr(`provider_num', 3, 2)=="13" & `rev_cntr_code'=="0960")
	


tabulate RHC_FQHC CAH_Opt2, missing

drop if (RHC_FQHC==0 & CAH_Opt2==0)


codebook, compact
list in 1/10, clean


* Generate standard variables 
generate SERVICE_DT = `claim_begin_date'
	replace SERVICE_DT = `revenue_date' if `claim_begin_date' ==.
format SERVICE_DT %td
label variable SERVICE_DT "Date of ADRD Dx claim"

generate SERVICE_THRU_DT = `claim_thru_date'
	replace SERVICE_THRU_DT = SERVICE_DT if `claim_thru_date' ==.
format SERVICE_THRU_DT %td
label variable SERVICE_THRU_DT "Thru date of ADRD Dx claim"

generate DX = ""
label variable DX "ADRD ICD9/10 Dx"

generate ADRD_DX = 0
label variable ADRD_DX "Presence of ADRD diagnosis. 1/0"


* Generate new diagnosis variables to ensure similar vaming conventions
local orig_dx_vars `dx_admit' `dx_first'-`dx_last'

local i = 0

foreach v of varlist `orig_dx_vars' {
	generate NEW_ICD_DGNS_CD`i' = `v'
	local i = `i' + 1
}



* loop through codes across all newly created variables
foreach var of varlist NEW_ICD_DGNS_CD* {
	foreach icd_code in `DemDx' {
		quietly replace ADRD_DX = 1 if `var' == "`icd_code'"
	}
}



* clean up data - only keep if observations with at least one ADRD diagnosis
* remove any duplicates
sort BENE_ID SERVICE_DT SERVICE_THRU_DT ADRD_DX
quietly by BENE_ID SERVICE_DT SERVICE_THRU_DT ADRD_DX:  gen dup = cond(_N==1,0,_n)
tabulate dup
drop if dup > 1


display "benes BEFORE dropping those without ADRD"
codebook BENE_ID
tabulate ADRD_DX

keep if ADRD_DX==1

display "benes AFTER dropping those without ADRD"
codebook BENE_ID

drop `claim_begin_date' `claim_thru_date' `orig_dx_vars' `revenue_date' `line_prcsg_ind_cd' `line_alowd_chrg_amt' dup 


* Reshape to get all ADRD diagnosis codes 
reshape long NEW_ICD_DGNS_CD, i(BENE_ID SERVICE_DT SERVICE_THRU_DT) j(DX_NUM)

replace ADRD_DX = 0 /* re-initialize so we can just capture relevant codes this time */

foreach icd_code in `DemDx'{
	replace ADRD_DX = 1 if NEW_ICD_DGNS_CD == "`icd_code'"
	replace DX = NEW_ICD_DGNS_CD if NEW_ICD_DGNS_CD == "`icd_code'"
}


* Check numbers
display "benes and observations BEFORE dropping those without ADRD"
codebook BENE_ID

keep if ADRD_DX==1 /* keep only dx codes indicating ADRD */

display "benes and observations AFTER dropping those without ADRD"
codebook BENE_ID


sort BENE_ID SERVICE_DT SERVICE_THRU_DT DX
quietly by BENE_ID SERVICE_DT SERVICE_THRU_DT DX :  gen dup = cond(_N==1,0,_n)
tabulate dup
drop if dup > 1

display "benes and observations AFTER dropping duplicates"
codebook BENE_ID

tab1 ADRD_DX DX

keep BENE_ID SERVICE_DT SERVICE_THRU_DT ADRD_DX DX

codebook, compact

cd "`output_folder'"
save "diag_adrd_hof_`data_year'.dta", replace

codebook
list in 1/10
tabulate DX

/* Collapse to Service Date level */
gen ONE = 1
collapse (count) NUM_ADRD_DX=ONE, by(BENE_ID SERVICE_DT SERVICE_THRU_DT ADRD_DX)

label variable NUM_ADRD_DX "Total ADRD Dx. by Service Date"

display "benes and observations AFTER collapsing on visit"
codebook BENE_ID

tabulate ADRD_DX, missing
summarize NUM_ADRD_DX


save "servdt_adrd_hof_`data_year'.dta", replace

codebook, compact














