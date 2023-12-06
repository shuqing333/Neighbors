/*
This do file:
	1. Geocode CA voter registration files.
*/
*********************************Geocode 2020 voter registration data*********************************

use "Datasets/Output/CA2020clean.dta",clear
tostring zip,replace
gen proper_address=address+","+city+","+state+","+zip
collapse (firstnm) proper_address,by(address)
export delimited using "Datasets/Output/2020_address.csv", replace

*Run the python code to geocode the addresses

*Merge back to original dataset
import delimited "Datasets/Output/2020_geocoded.csv", clear
split address,parse(,)
drop address
rename address1 address
rename address2 city
rename address3 state
rename address4 zip
destring zip,replace

merge 1:m address using "Datasets/Output/CA2020clean.dta"
drop _merge

destring,replace

save "Datasets/Output/CA2020_geocoded.dta",replace

*********************************Geocode Other years*********************************
*Save the 2020 addresses
use "Datasets/Output/CA2020_geocoded.dta",clear
collapse (firstnm)latitude longitude match_addr score,by(address)
save "Datasets/Output/Address_2020",replace

use "Datasets/Output/CA2023clean.dta",clear
local datayrs "2017 2013 2011 2008 2006"
foreach year of local datayrs{
	append using "Datasets/Output/CA`year'clean.dta"
}
*save the addresses
sort address
collapse (firstnm) city state zip ,by(address)
save "Datasets/Output/Address2006-2023",replace

*Merge the addresses, keep those that are matched
merge 1:1 address using "Datasets/Output/Address_2020"

preserve
keep if _merge==3
drop _merge
save "Datasets/Output/Matched_address.dta",replace
restore

*Geocode those that were not matched
keep if _merge==1
tostring zip,replace
gen proper_address=address+","+city+","+state+","+zip

export delimited using "Datasets/Output/2006-2023_address.csv", replace

*Run the python code to geocode the addresses

*Combine the geocoded addresses with matched addresses dataset
import delimited "Datasets/Output/2006-2023_geocoded.csv", clear
split address,parse(,)
drop address
rename address1 address
rename address2 city
rename address3 state
rename address4 zip
destring zip,replace
append using "Datasets/Output/Matched_address.dta"

gen address_id=_n
save "Datasets/Output/All_address.dta",replace
*Merge back to original voter data
local datayrs "2023 2017 2013 2011 2008 2006"
foreach year of local datayrs{
	preserve
	merge 1:m address using "Datasets/Output/CA`year'clean.dta"
	drop if _merge==1
	drop _merge
	save "Datasets/Output/CA`year'_geocoded.dta",replace
	restore
}


erase "Datasets/Output/Matched_address.dta"
erase "Datasets/Output/Address_2006.dta"
erase "Datasets/Output/Address_2008.dta"
erase "Datasets/Output/Address_2011.dta"
erase "Datasets/Output/Address_2013.dta"
erase "Datasets/Output/Address_2017.dta"
erase "Datasets/Output/Address_2023.dta"
