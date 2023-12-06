/*
This do file:
	1. Conduct analysis at the individual level for three panels: 2017-2020, 2006-2013, 2006-2020
*/

****************************************************************
****************************************************************
************************FD,FE,Level,Joint Time******************
****************************************************************
****************************************************************
********************************2017-2023 panel********************************
local year "2017 2020 2023"
local size:list sizeof year
local size=`size'-1
forval i=1/`size'{
	local start `: word `i' of `year''
	local step=`size'+1-`i'
	forval j=1/`step'{
		local z=`i'+`j'
		local end `: word `z' of `year''
		use "Datasets/Output/CA2017_2023_panel.dta",clear
		sort registrantid datayear
		
		//Filter out voters in both periods
		by registrantid: gen flag_start=1 if datayear==`start'
		sort registrantid flag_start
		bysort registrantid: replace flag_start = flag_start[_n-1] if missing(flag_start) & _n > 1
		by registrantid: gen flag_end=1 if datayear==`end'
		sort registrantid flag_end
		bysort registrantid: replace flag_end = flag_end[_n-1] if missing(flag_end) & _n > 1

		keep if flag_start==1 & flag_end==1 & (datayear==`start' | datayear==`end')
		
		preserve
		//Save voters at the start of the sample
		keep if datayear==`start'
		gen dem_`start'_=1 if party=="dem"
		replace dem_`start'_=0 if dem_`start'_==.
		tempfile `start'_voters
		save ``start'_voters',replace

		//Save voters at the end of the sample
		restore
		keep if datayear==`end'
		gen dem_`end'_=1 if party=="dem"
		replace dem_`end'_=0 if dem_`end'_==.
		tempfile `end'_voters
		save ``end'_voters',replace

		//Find the nearest neighbors
		use "Datasets/Output/Homeowners.dta",clear
		geonear id prop_latitude prop_longitude using ``start'_voters',neighbors(registrantid latitude longitude) nearcount(40) miles long

		drop if mi_to_registrantid==0
		//Merge in address information of neighbors and homeowners themselves
		merge m:1 registrantid using ``start'_voters'

		drop if _merge==2
		drop _merge

		merge m:1 id using "Datasets/Output/Homeowners.dta"
		drop if _merge!=3
		drop _merge
		
		drop if mi_to_registrantid>0.5 //Drop far neighbors
		bysort id:gen rank=_n

		//Merge back voter registration data at the end of the sample
		merge m:1 registrantid using ``end'_voters'
		drop if _merge!=3
		drop _merge
		
		keep registrantid address mi_to_registrantid dem_`start'_ dem_`end'_ id rank prop_recyr minority prop_input_zip zip city prop_input_city Hispanic
		reshape wide registrantid address mi_to_registrantid dem_`start'_ dem_`end'_ zip city,i(id) j(rank)
		save "Datasets/Output/neighbor`start'_`end'.dta",replace
	}
}

//Analysis
est clear
local year "2017 2020 2023"
local size:list sizeof year
local size=`size'-1
forval i=1/1{
	local start `: word `i' of `year''
	local step=`size'+1-`i'
	forval j=1/`step'{
		local z=`i'+`j'
		local end `: word `z' of `year''
		di `start' `end'
		use "Datasets/Output/neighbor`start'_`end'.dta",clear

		//Prepare variables
		tostring prop_input_zip,replace
		replace prop_input_zip=substr(prop_input_zip,1,5)
		destring prop_input_zip,replace
		order *,sequential

		foreach k in `start' `end'{
			egen Nearest_5_`k'=rowmean(dem_`k'_1-dem_`k'_5)
			egen Nearest_10_`k'=rowmean(dem_`k'_6-dem_`k'_10)
			egen Nearest_20_`k'=rowmean(dem_`k'_11-dem_`k'_20)
			egen Nearest_30_`k'=rowmean(dem_`k'_21-dem_`k'_30)
		}
		
		gen time=`end'-prop_recyr
		foreach ring in 5 10 20 30{
			gen diff_`ring'=Nearest_`ring'_`end'-Nearest_`ring'_`start'

			*************Level*************
			reg Nearest_`ring'_`end' minority Nearest_`ring'_`start' if prop_recyr>=2017,robust
			est store Level_`ring'_`start'_`end'
			
			*************FD*************
			reg diff_`ring' minority if prop_recyr>=2017,robust
			est store FD_`ring'_`start'_`end'
			
			*************FE*************
			areg diff_`ring' minority if prop_recyr>=2017,a(prop_input_zip) robust
			est store FE_`ring'_`start'_`end'
			
			*************With time*************
			areg diff_`ring' minority##c.time if prop_recyr>=2017,a(prop_input_zip) robust
			est store time_`ring'_`start'_`end'
		}
		*************Joint*************
		reg diff_5 minority diff_10 diff_20 diff_30 if prop_recyr>=2017,a(prop_input_zip) robust
		est store Joint_`start'_`end'
		

		
		//Build the tables
		foreach model in Level FD FE{
			esttab `model'*_`start'_`end'*,replace se star(* 0.10 ** 0.05 *** 0.01) nomtitles keep(minority) cells("b(fmt(3)star)" "se(fmt(3)par)")
			local outcomes `""Nearest 5" "Nearest 6-10" "Nearest 11-20" "Nearest 21-30""'
			
			matrix C=r(coefs)
			matrix Observations=r(stats)
			local j 0
			cap matrix drop b
			cap matrix drop se
			foreach outcome of local outcomes{
				local ++j
				matrix tmp=C[1,3*`j'-2]
				if tmp[1,1]<. {
					matrix colnames tmp = "`outcome'"
					matrix b = nullmat(b), tmp
					matrix tmp[1,1] = C[1, 3*`j'-1]
					matrix se = nullmat(se), tmp
				}
			}
			ereturn post b
			estadd matrix se
			estadd local Observations=Observations[1,1]
			eststo drop `model'_`start'_`end'
			eststo `model'_`start'_`end'
			}
		esttab Level_`start'_`end' FD_`start'_`end' FE_`start'_`end' using "Output/neighbor_`start'_`end'.tex",mtitles("Level" "FD" "FE") noobs nonumber se replace
	}
}
esttab Joint_2017_2020 Joint_2017_2023 using "Output/Joint_2017.tex",nonumber mtitles("2017-2020" "2017-2023") coeflabels(diff_10 "Nearest 6-10" diff_20 "Nearest 11-20" diff_30 "Nearest 21-30") replace se

esttab time* using "Output/time_2017.tex",keep(1.*) coeflabels(1.minority "minority" 1.minority#c.time "minority $\times$ time") mgroup("2017-2020" "2017-2023", pattern(1 0 0 0 1 0 0 0) prefix(\multicolumn{@span}{c}{) suffix(}) span erepeat(\cmidrule(lr){@span})) mtitles("Nearest 5" "Nearest 6-10" "Nearest 11-20" "Nearest 21-30" "Nearest 5" "Nearest 6-10" "Nearest 11-20" "Nearest 21-30") replace se nonumber substitute(\_ _)





****************2006-2013 panel****************
local year "2006 2008 2011 2013"
local size:list sizeof year
local size=`size'-1
forval i=1/`size'{
	local start `: word `i' of `year''
	local step=`size'+1-`i'
	forval j=1/`step'{
		local z=`i'+`j'
		local end `: word `z' of `year''
		use "Datasets/Output/CA2006_2013_panel.dta",clear
		sort registrantid datayear
		
		//Filter out voters in both periods
		by registrantid: gen flag_start=1 if datayear==`start'
		sort registrantid flag_start
		bysort registrantid: replace flag_start = flag_start[_n-1] if missing(flag_start) & _n > 1
		by registrantid: gen flag_end=1 if datayear==`end'
		sort registrantid flag_end
		bysort registrantid: replace flag_end = flag_end[_n-1] if missing(flag_end) & _n > 1

		keep if flag_start==1 & flag_end==1 & (datayear==`start' | datayear==`end')
		
		preserve
		//Save voters at the start of the sample
		keep if datayear==`start'
		gen dem_`start'_=1 if party=="dem"
		replace dem_`start'_=0 if dem_`start'_==.
		tempfile `start'_voters
		save ``start'_voters',replace

		//Save voters at the end of the sample
		restore
		keep if datayear==`end'
		gen dem_`end'_=1 if party=="dem"
		replace dem_`end'_=0 if dem_`end'_==.
		tempfile `end'_voters
		save ``end'_voters',replace

		//Find the nearest neighbors
		use "Datasets/Output/Homeowners.dta",clear
		geonear id prop_latitude prop_longitude using ``start'_voters',neighbors(registrantid latitude longitude) nearcount(40) miles long
		
		drop if mi_to_registrantid==0
		//Merge in address information of neighbors and homeowners themselves
		merge m:1 registrantid using ``start'_voters'
		drop if _merge==2
		drop _merge
		merge m:1 id using "Datasets/Output/Homeowners.dta"
		drop if _merge!=3
		drop _merge
		
		drop if mi_to_registrantid>0.5 //Drop far neighbors
		bysort id:gen rank=_n

		//Merge back voter registration data at the end of the sample
		merge m:1 registrantid using ``end'_voters'
		drop if _merge!=3
		drop _merge
		
		keep registrantid address mi_to_registrantid dem_`start'_ dem_`end'_ id rank prop_recyr minority prop_input_zip zip city prop_input_city
		reshape wide registrantid address mi_to_registrantid dem_`start'_ dem_`end'_ zip city,i(id) j(rank)
		save "Datasets/Output/neighbor`start'_`end'.dta",replace
	}
}

//Analysis
est clear
local year "2006 2008 2011 2013"
local size:list sizeof year
local size=`size'-1
forval i=1/`size'{
	local start `: word `i' of `year''
	local step=`size'+1-`i'
	forval j=1/`step'{
		local z=`i'+`j'
		local end `: word `z' of `year''
		di `start' `end'
		use "Datasets/Output/neighbor`start'_`end'.dta",clear

		//Prepare variables
		tostring prop_input_zip,replace
		replace prop_input_zip=substr(prop_input_zip,1,5)
		destring prop_input_zip,replace
		order *,sequential

		foreach k in `start' `end'{
			egen Nearest_5_`k'=rowmean(dem_`k'_1-dem_`k'_5)
			egen Nearest_10_`k'=rowmean(dem_`k'_6-dem_`k'_10)
			egen Nearest_20_`k'=rowmean(dem_`k'_11-dem_`k'_20)
			egen Nearest_30_`k'=rowmean(dem_`k'_21-dem_`k'_30)
		}
		
		gen time=`end'-prop_recyr

		foreach ring in 5 10 20 30{
			gen diff_`ring'=Nearest_`ring'_`end'-Nearest_`ring'_`start'

			*************Level*************
			reg Nearest_`ring'_`end' minority Nearest_`ring'_`start' if prop_recyr>=`start' & prop_recyr<=`end',robust
			est store Level_`ring'_`start'_`end'
			
			*************FD*************
			reg diff_`ring' minority if prop_recyr>=`start' & prop_recyr<=`end',robust
			est store FD_`ring'_`start'_`end'
			
			*************FE*************
			areg diff_`ring' minority if prop_recyr>=`start' & prop_recyr<=`end',a(prop_input_zip) robust
			est store FE_`ring'_`start'_`end'
			
			*************With time*************
			areg diff_`ring' minority##c.time if prop_recyr>=`start' & prop_recyr<=`end',a(prop_input_zip) robust
			est store time_`ring'_`start'_`end'

		}
		*************Joint*************
		reg diff_5 minority diff_10 diff_20 diff_30 if prop_recyr>=`start' & prop_recyr<=`end',a(prop_input_zip) robust
		est store Joint_`start'_`end'
		
		
		//Build the tables
		foreach model in Level FD FE{
			esttab `model'*_`start'_`end'*,replace se star(* 0.10 ** 0.05 *** 0.01) nomtitles keep(minority) cells("b(fmt(3)star)" "se(fmt(3)par)")
			local outcomes `""Nearest 5" "Nearest 6-10" "Nearest 11-20" "Nearest 21-30""'
			
			matrix C=r(coefs)
			matrix Observations=r(stats)
			local j 0
			cap matrix drop b
			cap matrix drop se
			foreach outcome of local outcomes{
				local ++j
				matrix tmp=C[1,3*`j'-2]
				if tmp[1,1]<. {
					matrix colnames tmp = "`outcome'"
					matrix b = nullmat(b), tmp
					matrix tmp[1,1] = C[1, 3*`j'-1]
					matrix se = nullmat(se), tmp
				}
			}
			ereturn post b
			estadd matrix se
			estadd local Observations=Observations[1,1]
			eststo drop `model'_`start'_`end'
			eststo `model'_`start'_`end'
			}
		esttab Level_`start'_`end' FD_`start'_`end' FE_`start'_`end' using "Output/neighbor_`start'_`end'.tex",mtitles("Level" "FD" "FE") noobs nonumber se replace
	}
}
esttab Joint* using "Output/Joint_2006.tex",nonumber mtitles("2006-2008" "2006-2011" "2006-2013" "2008-2011" "2008-2013" "2011-2013") coeflabels(diff_10 "Nearest 6-10" diff_20 "Nearest 11-20" diff_30 "Nearest 21-30") replace se

esttab time_*2006_2008 time*2006_2011 using "Output/time_2006_1.tex", keep(1.*) coeflabels(1.minority "minority" 1.minority#c.time "minority $\times$ time") mgroup("2006-2008" "2006-2011", pattern(1 0 0 0 1 0 0 0) prefix(\multicolumn{@span}{c}{) suffix(}) span erepeat(\cmidrule(lr){@span})) mtitles("Nearest 5" "Nearest 6-10" "Nearest 11-20" "Nearest 21-30" "Nearest 5" "Nearest 6-10" "Nearest 11-20" "Nearest 21-30") replace se nonumber substitute(\_ _)

esttab time_*2006_2013 time*2008_2011 using "Output/time_2006_2.tex", keep(1.*) coeflabels(1.minority "minority" 1.minority#c.time "minority $\times$ time") mgroup("2006-2013" "2008-2011", pattern(1 0 0 0 1 0 0 0) prefix(\multicolumn{@span}{c}{) suffix(}) span erepeat(\cmidrule(lr){@span})) mtitles("Nearest 5" "Nearest 6-10" "Nearest 11-20" "Nearest 21-30" "Nearest 5" "Nearest 6-10" "Nearest 11-20" "Nearest 21-30") replace se nonumber substitute(\_ _) 

esttab time_*2008_2013 time*2011_2013 using "Output/time_2006_3.tex", keep(1.*) coeflabels(1.minority "minority" 1.minority#c.time "minority $\times$ time") mgroup("2008-2013" "2011-2013", pattern(1 0 0 0 1 0 0 0) prefix(\multicolumn{@span}{c}{) suffix(}) span erepeat(\cmidrule(lr){@span})) mtitles("Nearest 5" "Nearest 6-10" "Nearest 11-20" "Nearest 21-30" "Nearest 5" "Nearest 6-10" "Nearest 11-20" "Nearest 21-30") replace se nonumber substitute(\_ _)








****************************************************************
****************************************************************
************************Movers by party registration************
****************************************************************
****************************************************************
use "Datasets/Output/Homeowners.dta",clear
geonear id prop_latitude prop_longitude using "Datasets/Output/All_address.dta",neighbors(address_id latitude longitude) nearcount(10) miles long
keep if mi_to_address_id==0 //These are the properties that appear in both datasets

merge m:1 id using "Datasets/Output/Homeowners.dta"
drop if _merge!=3
drop _merge

merge m:1 address_id using "Datasets/Output/All_address.dta"
drop if _merge!=3
drop _merge

merge m:m address using "Datasets/Output/CA_geocoded.dta"
drop if _merge!=3
drop _merge

keep if firstname==fname & lastname==lname
drop if datayear>2017 | prop_recyr<2006

gen distance=abs(datayear-prop_recyr)
sort id distance
by id:gen order=_n
drop if order!=1

keep id-minority party
rename party mover_party

gen Hispanic=1 if likely_race=="hispanic"
replace Hispanic=0 if Hispanic==.

save "Datasets/Output/Homeowners_voters.dta",replace



local year "2017 2023"
local size:list sizeof year
local size=`size'-1
forval i=1/`size'{
	local start `: word `i' of `year''
	local step=`size'+1-`i'
	forval j=1/`step'{
		local z=`i'+`j'
		local end `: word `z' of `year''
		use "Datasets/Output/CA2017_2023_panel.dta",clear
		sort registrantid datayear
		
		//Filter out voters in both periods
		by registrantid: gen flag_start=1 if datayear==`start'
		sort registrantid flag_start
		bysort registrantid: replace flag_start = flag_start[_n-1] if missing(flag_start) & _n > 1
		by registrantid: gen flag_end=1 if datayear==`end'
		sort registrantid flag_end
		bysort registrantid: replace flag_end = flag_end[_n-1] if missing(flag_end) & _n > 1

		keep if flag_start==1 & flag_end==1 & (datayear==`start' | datayear==`end')
		
		preserve
		//Save voters at the start of the sample
		keep if datayear==`start'
		gen dem_`start'_=1 if party=="dem"
		replace dem_`start'_=0 if dem_`start'_==.
		tempfile `start'_voters
		save ``start'_voters',replace

		//Save voters at the end of the sample
		restore
		keep if datayear==`end'
		gen dem_`end'_=1 if party=="dem"
		replace dem_`end'_=0 if dem_`end'_==.
		tempfile `end'_voters
		save ``end'_voters',replace

		//Find the nearest neighbors
		use "Datasets/Output/Homeowners_voters.dta",clear
		geonear id prop_latitude prop_longitude using ``start'_voters',neighbors(registrantid latitude longitude) nearcount(40) miles long

		drop if mi_to_registrantid==0
		//Merge in address information of neighbors and homeowners themselves
		merge m:1 registrantid using ``start'_voters'

		drop if _merge==2
		drop _merge

		merge m:1 id using "Datasets/Output/Homeowners_voters.dta"
		drop if _merge!=3
		drop _merge
		
		drop if mi_to_registrantid>0.5 //Drop far neighbors
		bysort id:gen rank=_n

		//Merge back voter registration data at the end of the sample
		merge m:1 registrantid using ``end'_voters'
		drop if _merge!=3
		drop _merge
		
		keep registrantid address mi_to_registrantid dem_`start'_ dem_`end'_ id rank prop_recyr minority prop_input_zip zip city prop_input_city mover_party Hispanic
		reshape wide registrantid address mi_to_registrantid dem_`start'_ dem_`end'_ zip city,i(id) j(rank)
		save "Datasets/Output/neighbor`start'_`end'_by_party.dta",replace
	}
}

//Analysis
est clear
local year "2017 2023"
local size:list sizeof year
local size=`size'-1
forval i=1/1{
	local start `: word `i' of `year''
	local step=`size'+1-`i'
	forval j=1/`step'{
		local z=`i'+`j'
		local end `: word `z' of `year''
		foreach type in race Hispanic{
			if "`type'"=="race"{
				use "Datasets/Output/neighbor`start'_`end'_by_party.dta",clear
			}
			else{
				use "Datasets/Output/neighbor`start'_`end'.dta",clear
			}
			//Prepare variables
			tostring prop_input_zip,replace
			replace prop_input_zip=substr(prop_input_zip,1,5)
			destring prop_input_zip,replace
			order *,sequential

			foreach k in `start' `end'{
				egen Nearest_5_`k'=rowmean(dem_`k'_1-dem_`k'_5)
				egen Nearest_10_`k'=rowmean(dem_`k'_6-dem_`k'_10)
				egen Nearest_20_`k'=rowmean(dem_`k'_11-dem_`k'_20)
				egen Nearest_30_`k'=rowmean(dem_`k'_21-dem_`k'_30)
			}
			
			gen time=`end'-prop_recyr
			if "`type'"=="race"{
				gen mover_dem=1 if mover_party=="dem"
				replace mover_dem=0 if mover_dem==.
			}
			foreach ring in 5 10 20 30{
				gen diff_`ring'=Nearest_`ring'_`end'-Nearest_`ring'_`start'
				*************By race*************
				if "`type'"=="race"{
					areg diff_`ring' minority##mover_dem if prop_recyr>=2017,a(prop_input_zip) robust
					est store race__`ring'_`start'_`end'
			}
				else{
					areg diff_`ring' Hispanic if prop_recyr>=2017,a(prop_input_zip) robust
					est store Hispanic__`ring'_`start'_`end'
				}
		}

	}
}
}
esttab race* using "By_race2017.tex",  keep(1.minority 1.mover_dem 1.minority#1.mover_dem) coeflabels(1.minority "Minority" 1.mover_dem "Mover dem" 1.minority#1.mover_dem "Minority $\times$ mover dem")mgroup("2017-2023", pattern(1 0 0 0) prefix(\multicolumn{@span}{c}{) suffix(}) span erepeat(\cmidrule(lr){@span})) mtitles("Nearest 5" "Nearest 6-10" "Nearest 11-20" "Nearest 21-30") replace se nonumber substitute(\_ _) noabbrev

esttab Hispanic*








local year "2006 2013"
local size:list sizeof year
local size=`size'-1
forval i=1/`size'{
	local start `: word `i' of `year''
	local step=`size'+1-`i'
	forval j=1/`step'{
		local z=`i'+`j'
		local end `: word `z' of `year''
		use "Datasets/Output/CA2006_2013_panel.dta",clear
		sort registrantid datayear
		
		//Filter out voters in both periods
		by registrantid: gen flag_start=1 if datayear==`start'
		sort registrantid flag_start
		bysort registrantid: replace flag_start = flag_start[_n-1] if missing(flag_start) & _n > 1
		by registrantid: gen flag_end=1 if datayear==`end'
		sort registrantid flag_end
		bysort registrantid: replace flag_end = flag_end[_n-1] if missing(flag_end) & _n > 1

		keep if flag_start==1 & flag_end==1 & (datayear==`start' | datayear==`end')
		
		preserve
		//Save voters at the start of the sample
		keep if datayear==`start'
		gen dem_`start'_=1 if party=="dem"
		replace dem_`start'_=0 if dem_`start'_==.
		tempfile `start'_voters
		save ``start'_voters',replace

		//Save voters at the end of the sample
		restore
		keep if datayear==`end'
		gen dem_`end'_=1 if party=="dem"
		replace dem_`end'_=0 if dem_`end'_==.
		tempfile `end'_voters
		save ``end'_voters',replace

		//Find the nearest neighbors
		use "Datasets/Output/Homeowners_voters.dta",clear
		geonear id prop_latitude prop_longitude using ``start'_voters',neighbors(registrantid latitude longitude) nearcount(40) miles long

		drop if mi_to_registrantid==0
		//Merge in address information of neighbors and homeowners themselves
		merge m:1 registrantid using ``start'_voters'

		drop if _merge==2
		drop _merge

		merge m:1 id using "Datasets/Output/Homeowners_voters.dta"
		drop if _merge!=3
		drop _merge
		
		drop if mi_to_registrantid>0.5 //Drop far neighbors
		bysort id:gen rank=_n

		//Merge back voter registration data at the end of the sample
		merge m:1 registrantid using ``end'_voters'
		drop if _merge!=3
		drop _merge
		
		keep registrantid address mi_to_registrantid dem_`start'_ dem_`end'_ id rank prop_recyr minority prop_input_zip zip city prop_input_city mover_party Hispanic
		reshape wide registrantid address mi_to_registrantid dem_`start'_ dem_`end'_ zip city,i(id) j(rank)
		save "Datasets/Output/neighbor`start'_`end'_by_party.dta",replace
	}
}

//Analysis
est clear
local year "2006 2013"
local size:list sizeof year
local size=`size'-1
forval i=1/1{
	local start `: word `i' of `year''
	local step=`size'+1-`i'
	forval j=1/`step'{
		local z=`i'+`j'
		local end `: word `z' of `year''
		di `start' `end'
		use "Datasets/Output/neighbor`start'_`end'_by_party.dta",clear

		//Prepare variables
		tostring prop_input_zip,replace
		replace prop_input_zip=substr(prop_input_zip,1,5)
		destring prop_input_zip,replace
		order *,sequential

		foreach k in `start' `end'{
			egen Nearest_5_`k'=rowmean(dem_`k'_1-dem_`k'_5)
			egen Nearest_10_`k'=rowmean(dem_`k'_6-dem_`k'_10)
			egen Nearest_20_`k'=rowmean(dem_`k'_11-dem_`k'_20)
			egen Nearest_30_`k'=rowmean(dem_`k'_21-dem_`k'_30)
		}
		
		gen time=`end'-prop_recyr
		
		gen mover_dem=1 if mover_party=="dem"
		replace mover_dem=0 if mover_dem==.
		
		foreach ring in 5 10 20 30{
			gen diff_`ring'=Nearest_`ring'_`end'-Nearest_`ring'_`start'
			*************By race*************
			areg diff_`ring' minority##mover_dem if prop_recyr>=`start' & prop_recyr<=`end',a(prop_input_zip) robust
			est store race__`ring'_`start'_`end'
		}
	}
}
esttab race* using "Output/By_race2006.tex",  keep(1.minority 1.mover_dem 1.minority#1.mover_dem) coeflabels(1.minority "Minority" 1.mover_dem "Mover dem" 1.minority#1.mover_dem "Minority $\times$ mover dem")mgroup("2006-2013", pattern(1 0 0 0) prefix(\multicolumn{@span}{c}{) suffix(}) span erepeat(\cmidrule(lr){@span})) mtitles("Nearest 5" "Nearest 6-10" "Nearest 11-20" "Nearest 21-30") replace se nonumber substitute(\_ _) noabbrev


****************************************************************
****************************************************************
************************Individual level ************
****************************************************************
****************************************************************
local year "2017 2023"
local size:list sizeof year
local size=`size'-1
forval i=1/`size'{
	local start `: word `i' of `year''
	local step=`size'+1-`i'
	forval j=1/`step'{
		local z=`i'+`j'
		local end `: word `z' of `year''
		use "Datasets/Output/CA2017_2023_panel.dta",clear
		sort registrantid datayear
		
		//Filter out voters in both periods
		by registrantid: gen flag_start=1 if datayear==`start'
		sort registrantid flag_start
		bysort registrantid: replace flag_start = flag_start[_n-1] if missing(flag_start) & _n > 1
		by registrantid: gen flag_end=1 if datayear==`end'
		sort registrantid flag_end
		bysort registrantid: replace flag_end = flag_end[_n-1] if missing(flag_end) & _n > 1

		keep if flag_start==1 & flag_end==1 & (datayear==`start' | datayear==`end')
		
		preserve
		//Save voters at the start of the sample
		keep if datayear==`start'
		gen dem_`start'=1 if party=="dem"
		replace dem_`start'=0 if dem_`start'==.
		tempfile `start'_voters
		save ``start'_voters',replace

		//Save voters at the end of the sample
		restore
		keep if datayear==`end'
		gen dem_`end'=1 if party=="dem"
		replace dem_`end'=0 if dem_`end'==.
		tempfile `end'_voters
		save ``end'_voters',replace

		//Find the nearest neighbors
		use "Datasets/Output/Homeowners.dta",clear
		geonear id prop_latitude prop_longitude using ``start'_voters',neighbors(registrantid latitude longitude) nearcount(40) miles long

		drop if mi_to_registrantid==0
		//Merge in address information of neighbors and homeowners themselves
		merge m:1 registrantid using ``start'_voters'

		drop if _merge==2
		drop _merge

		merge m:1 id using "Datasets/Output/Homeowners.dta"
		drop if _merge!=3
		drop _merge
		
		drop if mi_to_registrantid>0.5 //Drop far neighbors
		bysort id:gen rank=_n

		//Merge back voter registration data at the end of the sample
		merge m:1 registrantid using ``end'_voters'
		drop if _merge!=3
		drop _merge
		
		keep registrantid address mi_to_registrantid dem_`start' dem_`end' id rank prop_recyr minority prop_input_zip zip city prop_input_city Hispanic
		save "Datasets/Output/neighbor`start'_`end'_Long.dta",replace
	}
}

//Analysis
est clear
local year "2017 2023"
local size:list sizeof year
local size=`size'-1
forval i=1/1{
	local start `: word `i' of `year''
	local step=`size'+1-`i'
	forval j=1/`step'{
		local z=`i'+`j'
		local end `: word `z' of `year''
		use "Datasets/Output/neighbor`start'_`end'_Long.dta",clear

		//Prepare variables
		tostring prop_input_zip,replace
		replace prop_input_zip=substr(prop_input_zip,1,5)
		destring prop_input_zip,replace
		
		drop if rank>20
		keep if prop_recyr>=2017
		egen ring=cut(rank),at(1 6 11 16 21)
		replace ring=(ring-1)/5+1
		collapse (firstnm) zip dem_`start' dem_`end' (sum) minority Hispanic,by(registrantid ring)
		reshape wide minority Hispanic,i(registrantid) j(ring)
		forval rank=1/4{
			gen mover`rank'=1 if minority`rank'!=.
			replace mover`rank'=0 if mover`rank'==.
			replace minority`rank'=0 if minority`rank'==.
			replace Hispanic`rank'=0 if Hispanic`rank'==.
			gen dummy_minority`rank'=1 if minority`rank'>0
			replace dummy_minority`rank'=0 if dummy_minority`rank'==.
		}
		gen diff=dem_`end'-dem_`start'



		*************Individual*************
		areg dem_`end' dummy_minority* mover* dem_`start',a(zip) robust
		est store Ind_1
		areg diff dummy_minority* mover*,a(zip) robust
		est store Ind_2
		areg dem_`start' dummy_minority* mover*,a(zip) robust
		est store Ind_3
		areg dem_`end' dummy_minority* mover*,a(zip) robust
		est store Ind_4

	}
}

esttab Ind* using "Output/Ind_2017.tex",drop (dem_2017)nonumber mtitles("Level" "FD" "Dem 2017" "Dem 2023") coeflabels(dummy_minority1 "minority ring1" dummy_minority2 "minority ring2" dummy_minority3 "minority ring3" dummy_minority4 "minority ring4" mover1 "mover ring1" mover2 "mover ring2" mover3 "mover ring3" mover4 "mover ring4") replace se









local year "2006 2013"
local size:list sizeof year
local size=`size'-1
forval i=1/`size'{
	local start `: word `i' of `year''
	local step=`size'+1-`i'
	forval j=1/`step'{
		local z=`i'+`j'
		local end `: word `z' of `year''
		use "Datasets/Output/CA2006_2013_panel.dta",clear
		sort registrantid datayear
		
		//Filter out voters in both periods
		by registrantid: gen flag_start=1 if datayear==`start'
		sort registrantid flag_start
		bysort registrantid: replace flag_start = flag_start[_n-1] if missing(flag_start) & _n > 1
		by registrantid: gen flag_end=1 if datayear==`end'
		sort registrantid flag_end
		bysort registrantid: replace flag_end = flag_end[_n-1] if missing(flag_end) & _n > 1

		keep if flag_start==1 & flag_end==1 & (datayear==`start' | datayear==`end')
		
		preserve
		//Save voters at the start of the sample
		keep if datayear==`start'
		gen dem_`start'=1 if party=="dem"
		replace dem_`start'=0 if dem_`start'==.
		tempfile `start'_voters
		save ``start'_voters',replace

		//Save voters at the end of the sample
		restore
		keep if datayear==`end'
		gen dem_`end'=1 if party=="dem"
		replace dem_`end'=0 if dem_`end'==.
		tempfile `end'_voters
		save ``end'_voters',replace

		//Find the nearest neighbors
		use "Datasets/Output/Homeowners.dta",clear
		geonear id prop_latitude prop_longitude using ``start'_voters',neighbors(registrantid latitude longitude) nearcount(40) miles long

		drop if mi_to_registrantid==0
		//Merge in address information of neighbors and homeowners themselves
		merge m:1 registrantid using ``start'_voters'

		drop if _merge==2
		drop _merge

		merge m:1 id using "Datasets/Output/Homeowners.dta"
		drop if _merge!=3
		drop _merge
		
		drop if mi_to_registrantid>0.5 //Drop far neighbors
		bysort id:gen rank=_n

		//Merge back voter registration data at the end of the sample
		merge m:1 registrantid using ``end'_voters'
		drop if _merge!=3
		drop _merge
		
		keep registrantid address mi_to_registrantid dem_`start' dem_`end' id rank prop_recyr minority prop_input_zip zip city prop_input_city Hispanic
		save "Datasets/Output/neighbor`start'_`end'_Long.dta",replace
	}
}





est clear
local year "2006 2013"
local size:list sizeof year
local size=`size'-1
forval i=1/1{
	local start `: word `i' of `year''
	local step=`size'+1-`i'
	forval j=1/`step'{
		local z=`i'+`j'
		local end `: word `z' of `year''
		use "Datasets/Output/neighbor`start'_`end'_Long.dta",clear

		//Prepare variables
		tostring prop_input_zip,replace
		replace prop_input_zip=substr(prop_input_zip,1,5)
		destring prop_input_zip,replace
		
		drop if rank>20
		keep if prop_recyr>=2006 & prop_recyr<=2013
		egen ring=cut(rank),at(1 6 11 16 21)
		replace ring=(ring-1)/5+1
		collapse (firstnm) zip dem_`start' dem_`end' (sum) minority Hispanic,by(registrantid ring)
		reshape wide minority Hispanic,i(registrantid) j(ring)
		forval rank=1/4{
			gen mover`rank'=1 if minority`rank'!=.
			replace mover`rank'=0 if mover`rank'==.
			replace minority`rank'=0 if minority`rank'==.
			replace Hispanic`rank'=0 if Hispanic`rank'==.
			gen dummy_minority`rank'=1 if minority`rank'>0
			replace dummy_minority`rank'=0 if dummy_minority`rank'==.
		}
		gen diff=dem_`end'-dem_`start'
		*************Individual*************
		/*
		areg dem_`end' dummy_minority* mover* dem_`start',a(zip) robust
		est store Ind_1
		areg diff dummy_minority* mover*,a(zip) robust
		est store Ind_2
		areg dem_`start' dummy_minority* mover*,a(zip) robust
		est store Ind_3
		areg dem_`end' dummy_minority* mover*,a(zip) robust
		est store Ind_4
		*/
		
		reg dem_`end' dummy_minority* mover1 mover2 mover3 dem_`start', robust
		est store Ind_1
		reg diff dummy_minority* mover1 mover2 mover3, robust
		est store Ind_2
		reg dem_`start' dummy_minority* mover1 mover2 mover3,robust
		est store Ind_3
		reg dem_`end' dummy_minority* mover1 mover2 mover3, robust
		est store Ind_4

	}
}

esttab Ind* using "Output/Ind_2006.tex",drop (dem_2006)nonumber mtitles("Level" "FD" "Dem 2006" "Dem 2013") coeflabels(dummy_minority1 "minority ring1" dummy_minority2 "minority ring2" dummy_minority3 "minority ring3" dummy_minority4 "minority ring4" mover1 "mover ring1" mover2 "mover ring2" mover3 "mover ring3" mover4 "mover ring4") replace se









