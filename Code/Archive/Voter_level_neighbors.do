cd "/Users/shuqingchen/Library/CloudStorage/GoogleDrive-cshuqing@umd.edu/.shortcut-targets-by-id/1-24MJrBecnnPHbVkhUaek1q-D2MnZi_h/Ethan RA/Neighbors"
****************Install packages
ssc install geonear
ssc install geodist
*Merge with Infutor dataset
use "CAVotingData/CA_full_geocoded_tulare_address_sorted.dta",clear
merge 1:1 num using "CAVotingData/id_correspondence.dta"
drop if _merge!=3
drop _merge
merge 1:1 registrantid using "CAVotingData/CA2020_clean_Tulare.dta"
drop _merge
drop if score==0
encode party,gen(party_code)
save "geocoded.dta",replace

*Find neighbors within 0.5 miles
geonear registrantid latitude longitude using "Housing Data/Analysis_data/treatment_tulare_infutor.dta",neighbors(id prop_latitude prop_longitude) within(0.5)  ignoreself miles long
sort registrantid
drop if mi_to_id>0.5
egen distance_cat=cut(mi_to_id),at(0 0.1 0.2 0.3 0.4 0.5)
replace distance_cat=distance_cat*10+1
label define distance 1 "Between 0 and 0.1 miles" 2 "Between 0.1 and 0.2 miles" 3 "Between 0.2 and 0.3 miles" 4 "Between 0.3 and 0.4 miles" 5 "Between 0.4 and 0.5 miles"
label values distance_cat distance
save "neighbor.dta",replace

*Reshape to wide format
by registrantid: gen distance_rank=_n
reshape wide id mi_to_id,i(registrantid) j(distance_rank) //This takes a long time
save "neighbor_wide.dta",replace


*Merge with voter registration data and property data
clear
use "neighbor_wide.dta",clear
merge 1:1 registrantid using "geocoded.dta"
drop _merge
tempfile neighbor
save `neighbor',replace

tempfile infutor
forvalues rank=1/1967{
	frame change infutor
	use "Housing Data/Analysis_data/treatment_tulare_infutor.dta",clear
	keep id pid pid2 fname mname lname suffix prop_latitude prop_longitude prop_saleedate prop_recedate prop_input_address owner_occ
	rename id id`rank'
	foreach var in pid pid2 fname mname lname suffix prop_latitude prop_longitude prop_saleedate prop_recedate prop_input_address owner_occ{
		rename `var' `var'_`rank'
	}
	save `infutor',replace
	frame change default
	use `neighbor',clear
	keep registrantid id`rank' mi_to_id`rank' score match_addr longitude latitude city state zip address num countycode lastname firstname middlename suffixname addressnumber addressnumbersuffix streetdirprefix streetname streettype streetdirsuffix unitnumber language party placeofbirth datayear birthyear birthmonth birthday edatedob regyear regmonth regday edatereg party_code
	drop if id`rank'==.
	merge m:1 id`rank' using `infutor'
	drop if _merge==2
	drop _merge
	save "Output/Nearest_neighbors/nearest_`rank'.dta",replace
}

forvalues rank=1/1967{
	use "Output/Nearest_neighbors/nearest_`rank'.dta",clear
	drop _merge
	save,replace
}
*Merge everything
clear
set maxvar 25000
use "Output/Nearest_neighbors/nearest_1.dta",clear
forvalues rank=2/1967{
	merge 1:1 registrantid using "Output/Nearest_neighbors/nearest_`rank'.dta"
	drop _merge
}

