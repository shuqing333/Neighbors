# Install and load required packages
install.packages(c("purrr", "readr"))
library(purrr)
library(readr)
library(dplyr)
library(lubridate)
library(haven)
library(nabor)
library(FNN)
library(geodist)
library(tidyr)
library(data.table)
library(geosphere)
library("microbenchmark")
rm(list=ls())

#############################Load some datasets#############################
Countycode <-read.csv("~/Library/CloudStorage/Box-Box/Neighbors/Datasets/Input/FLVotingData/Countycode.csv")
FL_address_geocoded <- read.csv("~/Library/CloudStorage/Box-Box/Neighbors/Datasets/Intermediate/FL_address_geocoded.csv")
FL_infutor_clean <- read_dta("/Users/shuqingchen/Library/CloudStorage/Box-Box/Neighbors/Datasets/Intermediate/FL_infutor_clean.dta")
#############################Generate the variables need to uses#############################
#Variables names of the voting datasets
new_col_names <-c("Countycode","voterid","lastname","suffix","firstname","middle","exemption","resid_addr1","resid_addr2","resid_city","resid_state","resid_zipcode","mail_addr1","mail_addr2","mail_addr3","mail_city","mail_state","mail_zipcode","mail_country","gender","race","DOB","DOR","party","precinct","precinctgroup","precinctsplit","precinctsuffix","voterstatus","CD","HD","SD","CCD","SBD","daytimecode","phone","extension","email") 

years <- c(2020,2023)

#############################Clean 2020 and 2023 FL voter data#############################
for (year in years){
  # Set the directory path where your text files are located
  if (year==2020){
    directory_path <- "/Users/shuqingchen/Library/CloudStorage/Box-Box/Neighbors/Datasets/Input/FLVotingData/FL2020/Voter_Registration_20200407/20200407_VoterDetail"
  }
  else{
    directory_path <- "/Users/shuqingchen/Library/CloudStorage/Box-Box/Neighbors/Datasets/Input/FLVotingData/FL2023/20230509_VoterDetail"
  }
  # Get a list of all text files in the directory
  file_list <- list.files(path = directory_path, pattern = "\\.txt$", full.names = TRUE)
  # Loop through each text file and read its content into a data frame
  Dataframe_list <-list()
  for (counter in seq_along(file_list)) {
    file <-file_list[counter]
    
    # Read the text file into a data frame (adjust read.table parameters as needed)
    current_data <- read_delim(file, delim = "\t", escape_double = FALSE,col_names = FALSE, trim_ws = TRUE)
    
    # Append the data frame to the list
    Dataframe_list[[counter]] <-current_data
  }
  Voting<-do.call(rbind, Dataframe_list)
  rm(Dataframe_list)
  
  #Rename dataset and convert the foramt of some variables
  colnames(Voting) <- new_col_names
  Voting <- Voting %>% 
    select(-c("email","daytimecode","phone","extension")) %>% 
    mutate(DOB=mdy(DOB),DOR=mdy(DOR),resid_zipcode=as.numeric(substr(resid_zipcode,1,5))) %>%
    mutate_at(vars(voterid,resid_zipcode,precinct,CD,HD,SD,CCD,SBD,precinctgroup),as.numeric) %>%
    filter(resid_addr1!="*")
  
  #Convert county codes to county names
  Voting <- left_join(Voting,Countycode,by="Countycode") %>% select(-c("exemption","Countycode","resid_state"))
  
  #Generate year of the data
  if (year==2020){
    Voting$year<-2020
  }
  else{
    Voting$year<-2023
  }
  
  output_path <- paste0("/Users/shuqingchen/Library/CloudStorage/Box-Box/Neighbors/Datasets/Intermediate/FL_",year,"_cleaned.csv")
  
  fwrite(Voting, file = output_path)
}

#############################Clean 2013 FL voter data#############################
FL2013 <- read_dta("~/Library/CloudStorage/Box-Box/Neighbors/Datasets/Input/FLVotingData/FL2013/Florida Voter File/FL_2013_neighbors_extract.dta")

#Clean data to fit the format
FL2013 <- FL2013 %>% mutate_if(is.character, utf8::utf8_encode)
FL2013 <- left_join(FL2013,Countycode,by=c("county"="Countycode")) %>%
  select(-c("resid_statere","county")) %>%
  rename(middle=middlename,CD=CDS) %>%
  mutate(DOB=mdy(DOB),DOR=mdy(DOR),year=2013,resid_zipcode=as.numeric(substr(resid_zipcode,1,5))) %>%
  mutate_at(vars(voterid,resid_zipcode,precinct,CD,HD,SD,CCD,SBD,precinctgroup),as.numeric) %>%
  filter(resid_addr1!="*")

#############################Combine everything to form a panel#############################
FL2020<- fread("/Users/shuqingchen/Library/CloudStorage/Box-Box/Neighbors/Datasets/Intermediate/FL_2020_cleaned.csv",skip = 0, header=TRUE)
FL2023<- fread("/Users/shuqingchen/Library/CloudStorage/Box-Box/Neighbors/Datasets/Intermediate/FL_2023_cleaned.csv", skip = 0, header=TRUE)
Voting <- rbind(FL2013,FL2020,FL2023)
rm(FL2013,FL2020,FL2023)

#############################Merge the FL voting data with the geocoded addresses#############################
Voting <- left_join(Voting,FL_address_geocoded,by=c("resid_addr1"="USER_resid_addr1","resid_city"="USER_resid_city","resid_zipcode"="USER_resid_zipcode")) %>% 
  distinct(voterid, year, .keep_all = TRUE)
#save a copy
fwrite(Voting, file = "/Users/shuqingchen/Library/CloudStorage/Box-Box/Neighbors/Datasets/Intermediate/FL_panel_cleaned.csv")

rm(FL_address_geocoded)

#############################Find closest neighbors of each property#############################
#Clean the infutor property data data and select variables
FL_infutor_clean<- FL_infutor_clean %>% select("id","prop_latitude","prop_longitude","prop_ownerocc","prop_recedate","white","hispanic","asian","black","zip") %>% mutate(date=as.Date(FL_infutor_clean$prop_recedate, origin = "1960-01-01")) %>% filter(year(date)>2013,prop_ownerocc=="O")
Voting <- fread("/Users/shuqingchen/Library/CloudStorage/Box-Box/Neighbors/Datasets/Intermediate/FL_panel_cleaned.csv",skip = 0, header=TRUE)
#Clean and select variables for the voter panel
Voting <- Voting %>%
  filter(Addr_type=="PointAddress") %>%
  group_by(voterid) %>%
  filter(n() >= 3) %>%
  ungroup() %>%
  mutate(
    Dem = if_else(party == "DEM", 1, 0),
    Rep = if_else(party == "REP", 1, 0),
    Ind = if_else(party == "NPA", 1, 0)
  ) %>%
  select(-party) %>%
  filter(Dem!=0 | Rep!=0 | Ind!=0) %>%
  select(c("voterid","gender","race","Dem","Ind","Rep","X","Y","year"))

#Save the 2013 and 2020 data for analysis
Voting <- Voting %>%filter(year!=2023)

#Generate indicator for anyone changed addresses
Voting <- Voting %>%
  group_by(voterid) %>%
  mutate(address_diff = ifelse(n_distinct(paste(X, Y)) > 1, 1, 0)) %>%
  ungroup()

#Generate adress ID
Voting <- Voting %>%
  group_by(X, Y) %>%
  mutate(address_id = cur_group_id()) %>%
  ungroup()
FL2013 <- Voting %>% filter(year==2013) %>% rename(Dem2013=Dem,Rep2013=Rep,Ind2013=Ind,lon2013=X,lat2013=Y) %>% filter(!is.na(lat2013))
FL2020 <- Voting %>% filter(year==2020) %>% rename(Dem2020=Dem,Rep2020=Rep,Ind2020=Ind,lon2020=X,lat2020=Y) %>% filter(!is.na(lat2020)) %>% select(-c("gender","race","address_id","address_diff"))

#Find the nearest neighbor using KNN
input <- FL2013 %>% select("lat2013","lon2013") 
query <- FL_infutor_clean %>% select("prop_latitude","prop_longitude")
knn <-get.knnx(query,input,k=40)

#Find the row indices of the neighbors
loc <- knn$nn.index
loc[] <- FL_infutor_clean$id[loc]
colnames(loc) <- paste0("neighbour_",1:ncol(loc))

#Merge back the property id
array <- FL2013 %>% 
  select(voterid) %>% 
  bind_cols(loc %>% as.data.frame())

#Reshape to long format for easier merging
array_long <- pivot_longer(array,cols = starts_with("neighbour_"),names_to = "Rank",values_to = "neighbor_id",names_prefix = "neighbour_")
array_long$Rank <- as.numeric(array_long$Rank)

#############################Merge back voter information and property owner information to the neighbor array generate the final sample#############################
#Merge the voter information back to the neighbor array
array_long <-left_join(array_long,FL2013,by=c("voterid"="voterid"))
array_long <-left_join(array_long,FL2020,by=c("voterid"="voterid"))
array_long <- left_join(array_long,FL_infutor_clean,by=c("neighbor_id"="id"))
rm(FL2013,FL2020)

#Save a copy
fwrite(array_long,"/Users/shuqingchen/Library/CloudStorage/Box-Box/Neighbors/Datasets/Intermediate/array.csv",row.names = FALSE)


#Process the data in checks
chunk_size <- 4000000
current_chunk <-0
fread("/Users/shuqingchen/Library/CloudStorage/Box-Box/Neighbors/Datasets/Intermediate/array.csv", nrows = chunk_size, skip = 0, header=TRUE) -> chunk
colnames<-colnames(chunk)
chunks <- list()
while (nrow(chunk) > 0) {
  print(summary(chunk))
  # Rename the columns
  colnames(chunk) <- colnames
  
  #Merge back the property owner information
  chunk <- left_join(chunk,FL_infutor_clean,by=c("neighbor_id"="id"))
  
  #Calculate the disatance between property and voters
  chunk <- chunk %>%
    mutate(distance = distHaversine(
      matrix(c(lon2013, lat2013), ncol = 2),
      matrix(c(prop_longitude, prop_latitude), ncol = 2)
    ))
  #Drop certain properties: 1. Those the closest neighbors are further than 500m. 2. Those that were transacted before 2013 since we only have voter data starting from 2013.
  ids_to_drop <- chunk %>%
    filter((Rank == 1 & distance > 500) | year(date)<=2013) %>%
    pull(voterid)
  chunk <- chunk %>% filter(!(voterid %in% ids_to_drop))
  
  #Save only necessary variables
  chunk <- chunk %>% select(-c("year.x","year.y","prop_ownerocc","prop_recedate")) %>% select(-c("lat2013","lon2013","lat2020","lon2020","prop_latitude","prop_longitude")) %>% mutate(date=year(date)) %>% rename(year=date)

    #Save a copy of each chunk of the dataset
  fwrite(chunk, file = paste0("/Users/shuqingchen/Library/CloudStorage/Box-Box/Neighbors/Datasets/Intermediate/chunk_", current_chunk, ".csv"))
  
  # Read the next chunk
fread("/Users/shuqingchen/Library/CloudStorage/Box-Box/Neighbors/Datasets/Intermediate/array.csv", nrows = chunk_size, skip = chunk_size * current_chunk) -> chunk
  current_chunk <- current_chunk + 1
}

#Combine all the processed chunks
setwd("/Users/shuqingchen/Library/CloudStorage/Box-Box/Neighbors/Datasets/Intermediate/")
chunk_files <- list.files(pattern = "chunk_\\d+\\.csv")
combined_df <- rbindlist(lapply(chunk_files, fread))


#Save the final analysis sample
write_dta(combined_df,"/Users/shuqingchen/Library/CloudStorage/Box-Box/Neighbors/Datasets/Final/Analysis.dta")





# Assuming Voter_address and FL_infutor_clean data frames are already defined

results <- list()

# Loop over a subset or all rows of Voter_address
for (i in 1:min(1000, nrow(Voter_address))) {
  individual <- Voter_address[i, ]
  
  # Calculate distances to all properties
  execution_time<- microbenchmark(distances <- distHaversine(
    matrix(c(individual$X, individual$Y), nrow = 1),
    matrix(c(FL_infutor_clean$prop_longitude, FL_infutor_clean$prop_latitude), ncol = 2)
  ))
  print(execution_time)
  # Find properties within the specified radius
  nearby_properties <- FL_infutor_clean[distances <= 1000, ]
  
  # Add distance and individual ID to the results
  nearby_properties$distance <- distances[distances <= 1000]
  nearby_properties$address_id <- individual$address_id
  
  results[[i]] <- nearby_properties
}

# Combine the results into a single data frame
final_results <- bind_rows(results)

final_results <- final_results %>%
  group_by(address_id) %>%
  arrange(address_id, distance) %>%
  mutate(rank = rank(distance, ties.method = "first")) %>%
  ungroup()
# Print the result
print(final_results)

execution_time<- microbenchmark(distances <- distm(
  matrix(c(individual$X, individual$Y), nrow = 1),
  matrix(c(FL_infutor_clean$prop_longitude, FL_infutor_clean$prop_latitude), ncol = 2)
))
print(execution_time)

distance_matrix <- distm(individual_coords, property_coords, fun = distHaversine)