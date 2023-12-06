cd "/Users/shuqingchen/Library/CloudStorage/GoogleDrive-cshuqing@umd.edu/Other computers/My Mac/Ethan RA/Neighbors/"
****************Install packages
ssc install geonear
ssc install geodist
ssc install rsource

****************Geocode the 2020 voter registration data merging with the address provided by ArcGIS, save different samples

use "Datasets/CAVotingData/CA_full_geocoded_tulare_address_sorted.dta",clear //All of the addresses
merge 1:1 num using "Datasets/Input/CAVotingData/id_correspondence.dta"
drop if _merge!=3
drop _merge
merge 1:1 registrantid using "Datasets/Input/CAVotingData/CA2020_clean_Tulare.dta"
drop _merge
drop if score==0
encode party,gen(party_code)
save "Datasets/Output/CA2020_geocoded.dta",replace

****************Find the 20 nearest neighbors for all the properties using neighbors data and voter registration data
use "Datasets/Input/Housing Data/Analysis_data/treatment_tulare_infutor.dta",clear
geonear id prop_latitude prop_longitude using "Datasets/geocoded_`sample'.dta",neighbors(registrantid latitude longitude) nearcount(20)  ignoreself miles
save "Datasets/Output/neighbors_infutor.dta",replace


use "Datasets/Output/neighbors_infutor_`sample'.dta",clear
cap frame drop geocoded
frame create geocoded
forvalues rank=1/20{
	frame change geocoded
	use "Datasets/Output/CA2020_geocoded",clear
	gen dem=1 if party_code==1
	replace dem=0 if dem==.
	keep registrantid dem
	rename registrantid nid`rank'
	rename dem dem`rank'
	tempfile geocoded_neighbor
	save `geocoded_neighbor',replace
	frame change default
	merge m:1 nid`rank' using `geocoded_neighbor'
	drop if _merge!=3
	drop _merge
}

egen Nearest_5=rowmean(dem1-dem5)
egen Nearest_10=rowmean(dem6-dem10)
egen Nearest_20=rowmean(dem11-dem20)
drop nid* dem* mi_*

****************Use R to predict races of the home owner. ****************
export delimited using "Datasets/Input/owner_surname", replace

if "`c(os)'"=="MacOSX" | "`c(os)'"=="UNIX" {
    rsource using "Code/Predict_races.R", rpath("/usr/local/bin/R") roptions(`"--vanilla"')
}
else {  // windows
    rsource using "Code/Predict_races.R", rpath(`"c:\r\R-3.5.1\bin\Rterm.exe"') roptions(`"--vanilla"')  // change version number, if necessary
}

****************Merge back to the original dataset****************
cap frame drop predicted_races
frame create predicted_races
frame change predicted_races
import delimited "Datasets/Output/Predicted_races.csv", varnames(1) clear
drop if likely_race=="NA" //Drop any names that have no predictions
destring,replace
drop match_name
rename name lname
collapse (firstnm) likely_race probability_american_indian probability_asian probability_black probability_hispanic probability_white probability_2races,by(lname)
tempfile predicted_races
save `predicted_races',replace


frame change default
merge m:1 lname using `predicted_races'
drop if _merge!=3
drop _merge

*Generate treatment variable
gen minority=1 if likely_race!="white"
replace minority=0 if minority==.

gen exposed_year=2020-prop_saleyr

****************Static models
reg Nearest_5 minority
est store est1
reg Nearest_5_10 minority
est store est2
reg Nearest_11_20 minority
est store est3

reg Nearest_5 minority if owner_occ==1
est store est4
estadd local Owner "X"
reg Nearest_5_10 minority if owner_occ==1
est store est5
estadd local Owner "X"
reg Nearest_11_20 minority if owner_occ==1
est store est6
estadd local Owner "X"


esttab est1 est2 est3 est4 est5 est6 using "Output/Static.tex",noabbrev coeflabels(_cons Constant Ownder "Owner occupied") se nonumber scalar(Owner) replace mtitles("Nearest 5" "Nearest 5-10" "Nearest 11-20" "Nearest 5" "Nearest 5-10" "Nearest 11-20")

****************Static models (Black probability as indepdent variable)
reg Nearest_5 probability_black
est store est1
reg Nearest_5_10 probability_black
est store est2
reg Nearest_11_20 probability_black
est store est3

reg Nearest_5 probability_black if owner_occ==1
est store est4
estadd local Owner "X"
reg Nearest_5_10 probability_black if owner_occ==1
est store est5
estadd local Owner "X"
reg Nearest_11_20 probability_black if owner_occ==1
est store est6
estadd local Owner "X"

esttab est1 est2 est3 est4 est5 est6,noabbrev coeflabels(_cons Constant Owner "Owner occupied") se nonumber scalar(Owner) replace mtitles("Nearest 5" "Nearest 5-10" "Nearest 11-20" "Nearest 5" "Nearest 5-10" "Nearest 11-20")

****************Dynamic model
foreach outcome in 5 10 20{
	reg Nearest_`outcome' minority##i.exposed_year if owner_occ==1
	matrix C=e(b)
	mata st_matrix("A",sqrt(diagonal(st_matrix("e(V)"))))
	matrix C = C \ A'
	mat list C
	mat C=C[1..2,79..89]
	mat colnames C="2" "3" "4" "5" "6" "7" "8" "9" "10" "11" "12"
	if `outcome'==5{
		coefplot matrix(C[1]), se(C[2]) vertical xtitle("year since moved") ytitle("Percentage of democrats") title("5 nearest") ytick(0(0.02)0.16) ylabel(0(0.02)0.16)
	}
	if `outcome'==10{
		coefplot matrix(C[1]), se(C[2]) vertical xtitle("year since moved") ytitle("Percentage of democrats") title("6-10 nearest") ytick(0(0.02)0.16) ylabel(0(0.02)0.16)
	}
	if `outcome'==20{
		coefplot matrix(C[1]), se(C[2]) vertical xtitle("year since moved") ytitle("Percentage of democrats") title("11-20 nearest") ytick(0(0.02)0.16) ylabel(0(0.02)0.16)
	}
	
	graph export "Output/Dynamic_`outcome'.png", as(png) name("Graph") replace

}





