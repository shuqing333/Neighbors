/*
This do file:
	1. Conduct analysis at the individual level for three panels: 2017-2020, 2006-2013, 2006-2020
*/
cd "/Users/shuqingchen/Library/CloudStorage/Box-Box/Neighbors"
****************************************************************
****************************************************************
************************FD,FE,Level,Joint Time******************
****************************************************************
****************************************************************
use "/Users/shuqingchen/Library/CloudStorage/Box-Box/Neighbors/Datasets/Final/Analysis.dta",clear
gen time=2023-year(date)
foreach party in Dem Ind Rep{
	foreach ring in 5 10 20 40{
		gen diff_`party'_`ring'=`party'2023_Nearest`ring'-`party'2013_Nearest`ring'
			*************Level*************
			reg `party'2023_Nearest`ring' black `party'2013_Nearest`ring',robust
			est store Level_`ring'_`party'
			
			*************FD*************
			reg diff_`party'_`ring' black,robust
			est store FD_`ring'_`party'
			
			*************FE*************
			areg diff_`party'_`ring' black,a(zip) robust
			est store FE_`ring'_`party'
			
			*************With time*************
			areg diff_`party'_`ring' black##c.time,a(zip) robust
			est store time_`ring'_`party'
	}
		*************Joint*************
		reg diff_`party'_5 black diff_`party'_10 diff_`party'_20 diff_`party'_40,a(zip) robust
		est store Joint_`party'
}


//Build the tables
foreach party in Dem Ind Rep{
	*Build the DID table
	foreach model in Level FD FE{
		esttab `model'*_`party',replace se star(* 0.10 ** 0.05 *** 0.01) nomtitles keep(black) cells("b(fmt(3)star)" "se(fmt(3)par)")
		local outcomes `""Nearest 5" "Nearest 6-10" "Nearest 11-20" "Nearest 21-40""'
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
		eststo drop `model'_`party'
		eststo `model'_`party'
		}
	esttab Level_`party' FD_`party' FE_`party' using "Output/DID_`party'.tex",mtitles("Level" "FD" "FE") noobs nonumber se replace
}

//Build the Joint table
foreach party in Dem Ind Rep{
	esttab Joint_`party', replace se star(* 0.10 ** 0.05 *** 0.01) nomtitles keep(black diff*) cells("b(fmt(3)star)" "se(fmt(3)par)")
	local outcomes `""Black" "Nearest 6-10" "Nearest 11-20" "Nearest 21-40""'
	matrix C=r(coefs)
	matrix Observations=r(stats)
		
		local j 0
		cap matrix drop b
		cap matrix drop se
		foreach outcome of local outcomes{
			local ++j
			matrix tmp=C[`j',1]
			if tmp[1,1]<. {
				matrix colnames tmp = "`outcome'"
				matrix b = nullmat(b), tmp
				matrix tmp[1,1] = C[`j',2]
				matrix se = nullmat(se), tmp
			}
		}
		ereturn post b
		estadd matrix se
		estadd local Observations=Observations[1,1]
		eststo drop Joint_`party'_output
		eststo Joint_`party'_output
	}
esttab Joint_Dem_output Joint_Ind_output Joint_Rep_output using "Output/Joint.tex",nonumber mtitles("Democrats" "Independent" "Republican") replace se

//Build the Regression with Time table
foreach party in Dem Ind Rep{
	esttab time_5_`party' time_10_`party' time_20_`party' time_40_`party' using "Output/time_`party'.tex",keep(1.* time) coeflabels(1.black "Black" 1.black#c.time "black $\times$ year" time "year") replace se nonumber mtitles("Nearest 5" "Nearest 6-10" "Nearest 11-20" "Nearest 21-40")
	}


esttab time_5_Dem* using "Output/time_2017.tex",keep(1.*) coeflabels(1.black "Black" 1.minority#c.time "minority $\times$ time") mgroup("2017-2020" "2017-2023", pattern(1 0 0 0 1 0 0 0) prefix(\multicolumn{@span}{c}{) suffix(}) span erepeat(\cmidrule(lr){@span})) mtitles("Nearest 5" "Nearest 6-10" "Nearest 11-20" "Nearest 21-30" "Nearest 5" "Nearest 6-10" "Nearest 11-20" "Nearest 21-30") replace se nonumber substitute(\_ _)




****************************************************************
****************************************************************
************************Individual level ************
****************************************************************
****************************************************************
local year "2013 2023"
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









