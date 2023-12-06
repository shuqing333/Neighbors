/*
This do file:
	1. Conduct analysis at the household level
*/

***********Save the 2020 addresses***********
use "Datasets/Output/CA2020_geocoded.dta",clear
collapse (firstnm)latitude longitude match_addr score,by(address)
save "Datasets/Output/Address_2020",replace

***********save the 2017 addresses***********
use "Datasets/Output/CA2017clean.dta",clear
sort address
collapse (firstnm) city state zip ,by(address)
save "Datasets/Output/Address_2017",replace

***********Merge 2017 and 2020 addresses, keep those that are matched (Might be inaccurate. Check later)***********
use  "Datasets/Output/Address_2017",clear
merge 1:1 address using "Datasets/Output/Address_2020"

keep if _merge==3
drop _merge
gen address_id=_n
save "Datasets/Output/Matched_address.dta",replace

foreach year in 2017 2020{
	use "Datasets/Output/CA`year'_geocoded.dta",clear
	merge m:1 address using "Datasets/Output/Matched_address.dta"
	drop if _merge!=3

	gen dem=1 if party_code==1
	replace dem=0 if dem==.
	collapse dem (firstnm) address latitude longitude, by(address_id)
	save "Datasets/Output/Household_`year'.dta",replace
}


****************Find the nearest household neighbors in 2017 using voters appeared in both 2017 and 2020****************
foreach year in 2017{
	//Find the nearest neighbors
	use "Datasets/Output/Homeowners.dta",clear
	geonear id prop_latitude prop_longitude using "Datasets/Output/Household_`year'.dta",neighbors(address_id latitude longitude) nearcount(40) miles long

	//Merge in address information of neighbors and homeowners themselves
	preserve
	use "Datasets/Output/Household_`year'.dta",clear
	keep address_id dem address
	tempfile neighbor
	save `neighbor',replace
	restore
	merge m:1 address_id using `neighbor'
	drop if _merge==2
	drop _merge
	merge m:1 id using "Datasets/Output/Homeowners.dta"
	drop if _merge!=3
	drop _merge
	
	
	//Filter out those themselves
	sort id mi_to_address_id
	by id:gen rank=_n
	gen dup=rank if address==prop_input_address
	bysort id: egen max_dup=max(dup)
	drop if rank<=dup & max_dup!=.
	drop if rank>20
	rename dem dem_2017_
	
	
	//Merge in 2020 voter registration data
	preserve
	use "Datasets/Output/Household_2020.dta",clear
	keep address_id dem
	rename dem dem_2020_
	tempfile neighbor
	save `neighbor',replace
	
	restore
	merge m:1 address_id using `neighbor'
	drop if _merge!=3
	drop _merge
	
	reshape wide address_id address mi_to_address_id dem_2017_ dem_2020_,i(id) j(rank)

	*keep if mi_to_registrantid20<1
	save "Datasets/Output/neighbor`year'_hh.dta",replace
}

egen Nearest_5_2017=rowmean(dem_2017_1 dem_2017_2 dem_2017_3 dem_2017_4 dem_2017_5)
egen Nearest_10_2017=rowmean(dem_2017_6 dem_2017_7 dem_2017_8 dem_2017_9 dem_2017_10)
egen Nearest_20_2017=rowmean(dem_2017_11 dem_2017_12 dem_2017_13 dem_2017_14 dem_2017_15 dem_2017_16 dem_2017_17 dem_2017_18 dem_2017_19 dem_2017_20)

egen Nearest_5_2020=rowmean(dem_2020_1 dem_2020_2 dem_2020_3 dem_2020_4 dem_2020_5)
egen Nearest_10_2020=rowmean(dem_2020_6 dem_2020_7 dem_2020_8 dem_2020_9 dem_2020_10)
egen Nearest_20_2020=rowmean(dem_2020_11 dem_2020_12 dem_2020_13 dem_2020_14 dem_2020_15 dem_2020_16 dem_2020_17 dem_2020_18 dem_2020_19 dem_2020_20)

gen diff_5=Nearest_5_2020-Nearest_5_2017
gen diff_10=Nearest_10_2020-Nearest_10_2017
gen diff_20=Nearest_20_2020-Nearest_20_2017

****************Analysis****************
reg Nearest_5_2020 minority Nearest_5_2017 if prop_recyr>=2017
est store est1
reg Nearest_10_2020 minority Nearest_10_2017 if prop_recyr>=2017
est store est2
reg Nearest_20_2020 minority Nearest_20_2017 if prop_recyr>=2017
est store est3

reg diff_5 minority if prop_recyr>=2017
est store est4
reg diff_10 minority if prop_recyr>=2017
est store est5
reg diff_20 minority if prop_recyr>=2017
est store est6

esttab est1 est2 est3,noabbrev replace mtitles("Nearest 5" "Nearest 5-10" "Nearest 11-20") keep(minority) nonumber se

esttab est4 est5 est6,noabbrev replace mtitles("Nearest 5" "Nearest 5-10" "Nearest 11-20") keep(minority) nonumber se



