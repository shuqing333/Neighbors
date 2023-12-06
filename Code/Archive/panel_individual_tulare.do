/*
This do file:
	1. Conduct analysis at the individual level
*/
/*
****************Find voters in both datasets****************
//Need to check if there are false positives and false negatives
use "Datasets/Output/CA2020_geocoded.dta",clear
merge 1:1 registrantid using "Datasets/Output/CA2017_geocoded.dta"

//Check unmatched names are the same person
preserve
keep if _merge==1
save "Datasets/Unmerged_2020.dta",replace
restore

preserve
keep if _merge==2
rename registrantid registrantid2017
save "Datasets/Unmerged_2017.dta",replace

use "Datasets/Unmerged_2020.dta",clear
reclink firstname lastname middlename edatedob address using "Datasets/Unmerged_2017.dta",idmaster(registrantid) idusing(registrantid_2017) gen(reclink_score)
keep if reclink_score!=.
save "Datasets/Merged_supp.dta",replace

*/

****************Find voters in both datasets****************
global path "C:\Users\kaplan\Box\Neighbors"

use "$path\Datasets\Output\Voter_Panel.dta", clear

keep latitude longitude match_addr zip registrantid firstname streetname addressnumber party gender datayear

reshape wide latitude longitude match_addr zip firstname streetname addressnumber party gender, i(registrantid) j(datayear) 

keep if streetname2006==streetname2008 & streetname2006~=""

sort registrantid

merge 1:1 registrantid using "Datasets/Output/CA2017_geocoded.dta"
keep if _merge==3
keep registrantid
save "Datasets/Output/Repeated_voters.dta",replace


****************Find the nearest individual neighbors in 2017 using voters appeared in both 2017 and 2020****************
foreach year in 2017{
	//Only use repeated voters
	use "Datasets/Output/CA`year'_geocoded.dta",clear
	merge 1:1 registrantid using "Datasets/Output/Repeated_voters.dta"
	keep if _merge==3
	drop _merge
	tempfile CA2017_repeated
	save `CA2017_repeated',replace
	
	//Find the nearest neighbors
	use "Datasets/Output/Homeowners.dta",clear
	geonear id prop_latitude prop_longitude using `CA2017_repeated',neighbors(registrantid latitude longitude) nearcount(40) miles long
	
	//Merge in address information of neighbors and homeowners themselves
	preserve
	use `CA2017_repeated',clear
	gen dem=1 if party_code==1
	replace dem=0 if dem==.
	keep registrantid dem address
	tempfile neighbor
	save `neighbor',replace
	restore
	merge m:1 registrantid using `neighbor'
	drop if _merge==2
	drop _merge
	merge m:1 id using "Datasets/Output/Homeowners.dta"
	drop if _merge!=3
	drop _merge
	
	
	//Filter out those themselves
	sort id mi_to_registrantid
	by id:gen rank=_n
	gen dup=rank if address==prop_input_address
	bysort id: egen max_dup=max(dup)
	drop if rank<=dup & max_dup!=.
	drop if rank>20
	rename dem dem_2017_
	
	
	//Merge in 2020 voter registration data
	preserve
	use "Datasets/Output/CA2020_geocoded.dta",clear
	merge 1:1 registrantid using "Datasets/Output/Repeated_voters.dta"
	keep if _merge==3
	gen dem=1 if party_code==1
	replace dem=0 if dem==.
	keep registrantid dem
	rename dem dem_2020_
	tempfile neighbor
	save `neighbor',replace
	
	restore
	merge m:1 registrantid using `neighbor'
	drop if _merge!=3
	drop _merge
	
	reshape wide registrantid address mi_to_registrantid dem_2017_ dem_2020_,i(id) j(rank)

	keep if mi_to_registrantid20<1
	save "Datasets/Output/neighbor`year'.dta",replace
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

//Analysis
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

