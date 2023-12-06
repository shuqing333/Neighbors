# Neighbors
Datasets:
	1.	Input:
	a.	CAVotingData
	⁃	Raw CA voter registration data
	b.	FLVotingData
	c.	HousingData
	⁃	California Infutor property data
	2.	Intermediate
	a.	Temporary datasets generated for various purposes
	3.	Final
	a.	Final dataset for analysis


Code:
	1.	Clean_CA_voting cleans CA voter registration data from 2006-2023. Produces two panels 2006-2013 and 2017-2023 because of registrantid change in 2013.
	2.	Predict_races.R uses a R package written by Jacob Kaplan (2023)
	3.	Clean_Infutor cleans Infutor property data and uses predict_races to add a predicted race to the dataset. Produces CA_Infutor_Clean
	4.	Geocode.py: python script uses ArcGIS Api to geocode addresses
	5.	Individual_anlaysis: Conduct individual-level analysis.

Table_output.lyx
	1.	Lyx file to view table outputs.
