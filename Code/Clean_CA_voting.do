/*This do-file
	1. Cleans CA voting data from 2006-2023
*/

***************Define global variables
global variablestokeep "registrantid lastname firstname middlename suffixname addressnumber addressnumbersuffix streetdirprefix streetname streettype streetdirsuffix  unitnumber city state zip language dob party placeofbirth registrationdate dob gender"
global datayrs "2006 2008 2011 2013 2017 2020 2023"
global data_dir_CA "$data_dir/Input/CAVotingData"

foreach d of global datayrs {
	********************************************************************************
	* Append Raw Data  
	********************************************************************************
	use "$data_dir_CA/CA`d'RegData", clear

	cap rename addrnum addressnumber
	cap rename addressnum addressnumber
	cap rename suffix suffixname
	cap rename namesuffix suffixname
	cap rename addrnumsuff addressnumbersuffix
	cap rename stdirprefix streetdirprefix
	cap rename stdirsuffix streetdirsuffix
	cap rename dateofbirth dob
	cap rename partycode party

	keep $variablestokeep

	gen datayear = `d'

	********************************************************************************
	* Clean Variables 
	********************************************************************************	

	*** Trim string variables and make lowercase
	foreach var in lastname firstname middlename suffixname ///
		addressnumber addressnumbersuffix streetdirprefix streetname streettype streetdirsuffix /// 
		unitnumber city state zip language dob gender party registrationdate placeofbirth {	
			cap replace `var' = strtrim(`var')
			cap replace `var' = stritrim(`var')
			cap replace `var' = "" if `var' == "."
			cap replace `var' = strlower(`var')
	}
	if `d'>=2017{
		gen edatedob = date(dob,"YMD")
		format edatedob %tdnn/dd/CCYY
		gen edatereg=date(registrationdate,"YMD")
		format edatereg %tdnn/dd/CCYY
	}

	else{
		gen edatedob = date(dob,"MDY")
		format edatedob %tdnn/dd/CCYY
		gen edatereg=date(registrationdate,"MDY")
		format edatereg %tdnn/dd/CCYY

	}


	drop dob registrationdate

	*** Clean suffixname variable
	replace suffixname = "sr" if suffixname == "1" | suffixname == "i" | suffixname == "s" | suffixname == "sr." 
	replace suffixname = "jr" if suffixname == "2" | suffixname == "ii" | suffixname == "j" | suffixname == "jr." | suffixname == "jr e" | suffixname == "il" 
	replace suffixname = "iii" if suffixname == "3" | suffixname == "111" | suffixname == "iil" | suffixname == "ill" 
	replace suffixname = "iv" if suffixname == "4" | suffixname == "iiii" 
	replace suffixname = "v" if suffixname == "5"
	replace suffixname = "vi" if suffixname == "6" | suffixname == "viu"  

	replace suffixname = "" if suffixname != "sr" & suffixname != "jr" & suffixname != "iii" & suffixname != "iv" & ///
		suffixname != "v" & suffixname != "vi" & suffixname != "vii" & suffixname != "viii" & suffixname != "ix" & suffixname != "x"

	*** Create party affiliation (there will be four types: Republican (rep), Democrat (dem), Independent (ind), and Other (other).  
	replace party = "ind" if party == "npp"
	replace party = "other" if party != "dem" & party != "rep" & party != "ind" & party != "" 

	gen address = addressnumber + " " + streetdirprefix + " " + streetname + " " + streettype + " " + streetdirsuffix
	replace address = proper(address)
	replace address = subinstr(address, "  ", " ", .)
	sort address

	compress 
	save "$data_dir/Intermediate/CA`d'_clean.dta", replace	
}

***Combine them together and form 2 panels(2006-2013)
foreach year in 2006 2011{
	use "$data_dir/Intermediate/CA`year'_clean.dta",clear
	generate byte non_numeric = indexnot(zip, "0123456789.-")
	drop if non_numeric
	destring zip,replace
	save,replace
}
foreach year in 2011 2013{
	use "$data_dir/Intermediate/CA`year'_clean.dta",clear
	tostring registrantid,replace
	save,replace
}

use "$data_dir/Intermediate/CA2006_clean.dta",clear
foreach year in 2008 2011 2013{
	append using "$data_dir/Intermediate/CA`year'_clean.dta"
}

save "$data_dir/Intermediate/CA_06-13_panel.dta",replace

*Save a copy of the addresses
tostring zip,replace
fcollapse datayear, by(address city state zip)
save "$data_dir/Intermediate/CA_06-13_address.dta",replace


***Combine them together and form 2 panels (2017-2023)
foreach year in 2017 2020 2023{
	use "$data_dir/Intermediate/CA`year'_clean.dta",clear
	replace zip=substr(zip,1,5)
	generate byte non_numeric = indexnot(zip, "0123456789.-")
	drop if non_numeric
	drop non_numeric
	destring zip,replace
	save,replace
}

use "$data_dir/Intermediate/CA2017_clean.dta",clear
foreach year in 2020 2023{
	append using "$data_dir/Intermediate/CA`year'_clean.dta"
}

save "$data_dir/Intermediate/CA_17-23_panel.dta",replace

*Save a copy of the addresses
tostring zip,replace
fcollapse datayear, by(address city state zip)
save "$data_dir/Intermediate/CA_17-23_address.dta",replace


use "$data_dir/Intermediate/CA_06-13_address.dta",clear
append using "$data_dir/Intermediate/CA_17-23_address.dta"
fcollapse datayear, by(address city state zip)
drop datayear
drop if address=="  "
save "$data_dir/Intermediate/CA_voter_address.dta",replace

erase "$data_dir/Intermediate/CA_17-23_address.dta"
erase "$data_dir/Intermediate/CA_06-13_address.dta"
