*** Define macros ***
global data_dir_Housing "$data_dir/Input/HousingData"


*** Clean infutor dataset
use "$data_dir_Housing/FL_Infutor.dta", clear
keep ID PID PID2 FNAME MNAME LNAME SUFFIX FNAME2 MNAME2 LNAME2 SUFFIX2 RECTYPE ///
	RECTYPE HOUSE PREDIR STREET STRTYPE POSTDIR APTTYPE APTNBR CITY STATE ZIP Z4 ///
	PROP_FIPSCD PROP_CENSUSTRACT PROP_LATITUDE PROP_LONGITUDE PROP_OWNEROCC PROP_CORPIND ///
	PROP_VALCALC PROP_VAL_CALCIND PROP_YRBLD PROP_ACRES PROP_UNVBLDSQFT PROP_RMS PROP_BEDRMS ///
	PROP_BATHS PROP_DOCYR PROP_RECDATE PROP_SALEDATE PROP_SALEAMT ///
	PROP_INPUT_ADDRESS PROP_INPUT_CITY PROP_INPUT_STATE PROP_INPUT_ZIP

* Make variable names and string variables lowercase 	
rename *, lower
foreach var in fname mname lname suffix suffix fname2 mname2 lname2 suffix2 ///
	house predir street strtype apttype aptnbr city state prop_input_address prop_input_city prop_input_state {
	replace `var' = lower(`var')
}

* Create proxy for owner occupied
gen owner_occ = (prop_ownerocc == "O" | prop_ownerocc == "S")
replace owner_occ = . if prop_ownerocc == ""

* Clean dummy variable for if name of the property owner has been recognized as a corporation or business
replace prop_corpind = "1" if prop_corpind == "Y"
destring prop_corpind, replace

* Make acres variable into actual acre units 
replace prop_acres = prop_acres/10000

* Make number of bathrooms variable into actual bathroom units 
replace prop_baths = prop_baths/100

* Create variable for the year, month, and day the sales transaction was legally completed
tostring prop_saledate, replace
gen prop_saleedate = date(prop_saledate, "YMD")

* Create variable for the year, month, and day the sales transaction was recorded at the county
tostring prop_recdate, replace
gen prop_recedate = date(prop_recdate, "YMD")
drop prop_recdate prop_saledate

* Keep only residential houses (i.e. exclude businesses)
keep if rectype == "R"

* Drop homes with missing lat and long. This appears to be coming from a mixture of missing house number, street, name or zipcode information 
drop if prop_latitude == . | prop_longitude == . //Lat and Long are missing on 0.73% of observations

* Keep if we have the recorded sales data. 
drop if prop_recedate == . // Lose 14% of observations

**** Predict property owner races **** 
* Run R code that predicts owner race using Kaplan,J(2023)
if "`c(os)'"=="MacOSX" | "`c(os)'"=="UNIX" {
    rsource using "$code_dir/Predict_races.R", rpath("/usr/local/bin/R") roptions(`"--vanilla"')
}
else {  // windows
    rsource using "$code_dir/Predict_races.R", rpath(`"c:\r\R-3.5.1\bin\Rterm.exe"') roptions(`"--vanilla"')  // change version number, if necessary
}


* Merge back to original dataset
merge m:1 fname lname using "/Users/shuqingchen/Library/CloudStorage/Box-Box/Neighbors/Datasets/Intermediate/Predicted_race_FL.dta"
drop _merge
gen white=1 if race=="white"
replace white=0 if white==.
gen black=1 if race=="black"
replace black=0 if black==.
gen hispanic=1 if race=="hispanic"
replace hispanic=0 if hispanic==.
gen asian=1 if race=="asian"
replace asian=0 if asian==.
compress
save "/Users/shuqingchen/Library/CloudStorage/Box-Box/Neighbors/Datasets/Intermediate/FL_Infutor_clean.dta", replace
