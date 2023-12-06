cd "/Volumes/T7/Ethan RA/Neighbors"
****************Install packages
cap ssc install geonear
cap ssc install geodist
***************Merge together CA Voter registration data and Geodata for 2020 file.
clear all
use "CAVotingData/CA_full_geocoded_tulare_address_sorted.dta",clear
merge 1:1 num using "CAVotingData/id_correspondence.dta"
drop if _merge!=3
drop _merge
merge 1:1 registrantid using "CAVotingData/CA2020_clean_Tulare.dta"
drop _merge
drop if score==0
encode party,gen(party_code)
tempfile geocoded
save `geocoded',replace
****Find the nearest neighbors. Up till 10 people, then only select the closest 3 that do not live together
geonear registrantid latitude longitude using `geocoded',neighbors(registrantid latitude longitude) nearcount(10)  ignoreself miles
drop if mi_to_nid10==0 //Very likely to be the elderly living in elderly care home?
reshape long nid mi_to_nid,i(registrantid) j(nearest)
bysort registrantid: gen nearest_count=_n
drop if nearest_count>3
drop nearest
save "CAVotingData/geocoded_temp.dta",replace

****Create a file with neighbors ID
frame create neighbors
frame change neighbors
use `geocoded',clear
foreach var of varlist _all{
	rename `var' `var'_neighbor
}
rename registrantid_neighbor nid
tempfile neighbors
save `neighbors',replace

****Merge with the original file
frame change default
use "CAVotingData/geocoded_temp.dta",clear
merge m:1 nid using `neighbors'
drop if _merge!=3
drop _merge
reshape wide nid mi_to_nid *neighbor,i(registrantid) j(nearest_count)
foreach x in party_code_neighbor1 party_code_neighbor2 party_code_neighbor3 party_code {
	replace `x'=0 if `x'>1
}
save "CAVotingData/geocoded_analysis.dta",replace
*****Analysis
use "CAVotingData/geocoded_analysis.dta",clear
eststo: estpost tabstat mi_to_nid1 mi_to_nid2 mi_to_nid3,stat(N mean sd p25 median p75 min max) col(stat)
esttab est1 using "Output/Summary.rtf", cells("count(fmt(0)) mean(fmt(3)) sd(fmt(3)) p25(fmt(3)) p50(fmt(3)) p75(fmt(3)) min(fmt(3)) max(fmt(3))") coeflabels(mi_to_nid1 "Nearest neighbor" mi_to_nid2 "2nd nearest neighbor" mi_to_nid3 "3rd nearest neighbor") noabbrev nonumber replace
reg party_code party_code_neighbor1 party_code_neighbor2 party_code_neighbor3
est store reg1
reg party_code party_code_neighbor1 party_code_neighbor2 party_code_neighbor3 if mi_to_nid1<1
est store reg2

esttab reg1 reg2, coeflabels(party_code_neighbor1 "nearest Dem" party_code_neighbor2 "2nd nearest Dem" party_code_neighbor3 "3rd nearest Dem") mtitle("Dem" "Dem with near neighbors") nonumber noconstant noabbrev





clear all
use "CAVotingData/CA_full_geocoded_tulare_address_sorted.dta",clear
merge 1:1 num using "CAVotingData/id_correspondence.dta"
drop if _merge!=3
drop _merge
merge 1:1 registrantid using "CAVotingData/CA2020_clean_Tulare.dta"
drop _merge
drop if score==0
encode party,gen(party_code)
tempfile geocoded
save `geocoded',replace
geonear registrantid latitude longitude using "Housing Data/Analysis_data/treatment_tulare_infutor.dta",neighbors(id prop_latitude prop_longitude) within(0.5)  ignoreself miles long
merge m:1 registrantid using `geocoded'

/*
*****Prepare the Infutor dataset to make it match the format of the CAVote dataset
clear all
use "Housing Data/Infutor_data/TULARE_06107/CRD4_CA_TULARE.dta",clear
rename First_Name firstname
rename Last_Name lastname
rename Middle_Name middlename
rename Suffix suffixname

*** Clean suffixname variable
replace suffixname = "sr" if suffixname == "1" | suffixname == "i" | suffixname == "s" | suffixname == "sr." 
replace suffixname = "jr" if suffixname == "2" | suffixname == "ii" | suffixname == "j" | suffixname == "jr." | suffixname == "jr e" | suffixname == "il" 
replace suffixname = "iii" if suffixname == "3" | suffixname == "111" | suffixname == "iil" | suffixname == "ill" 
replace suffixname = "iv" if suffixname == "4" | suffixname == "iiii" 
replace suffixname = "v" if suffixname == "5"
replace suffixname = "vi" if suffixname == "6" | suffixname == "viu"  

replace suffixname = "" if suffixname != "sr" & suffixname != "jr" & suffixname != "iii" & suffixname != "iv" & ///
	suffixname != "v" & suffixname != "vi" & suffixname != "vii" & suffixname != "viii" & suffixname != "ix" & suffixname != "x"
	
foreach x in firstname lastname middlename suffixname{
	replace `x'=lower(`x')
}
*gen master_id=_n
reclink firstname lastname middlename suffixname using `CAVote',idmaster(master_id) idusing(id) gen(score)

*/
