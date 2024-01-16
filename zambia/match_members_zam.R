#### Intro ####
# Title     : match_members.R
# Objective : Match debate text to corresponding member
# Created by: jacobwinter
# Created on: 2022-06-07 
## NB: This will not write over old sheets that have already been processed. 
## If you want to re-process them all, delete the files from the folder

library(tidyverse)
library(lubridate)
library(zoo)
library(svMisc)
library(tm)
library(quanteda)
library(seededlda)
library(readxl)
library(fuzzyjoin)
library(parallel)
options(scipen=99)

path = "~/Dropbox/parl_debates_data/zambia_data/"

#### Load and Clean Members ####
#Load and merge members from different sheets
sheets <- list.files(paste0(path, "members/"))
members <- data.frame()
for(i in 1:length(sheets)){
  print(i)
  data <- read_csv(paste0(path,"members/", sheets[i]))
  members <- plyr::rbind.fill(members, data)
}
# Assign to sessions
sessions <- read_excel(paste0(path,"year_map.xlsx"),1) %>% 
  arrange(year) %>% 
  drop_na(start) %>% 
  mutate(session = paste(assembly, session, sep="."),
         start = as.Date(start, origin = "1899-12-30"),
         end = lead(start)-1) |> 
  drop_na(end)


#Manually fix error for "Itezhi-Tezhi" members
members <- filter(members, district != "Itezhi")
row1 <- c("1", "Greyford Monde", "UPND", "Itezhi-Tezhi", "2011", "1977-04-09 22:00:00", "Married", "Businessman", "Grade 12", "Football, Praying, Youth Promotion", 'https://www.parliament.gov.zm/node/326')
row2 <- c("20", "Twaambo Elvis Mutinta", "UPND", "Itezhi-Tezhi", "2021", "1983-09-27 22:00:00","Married","Programmes Officer, Teacher","Bachelor of Adult Education, Certificate in Social Work, Diploma in Secondary Education, Grade 12 Certificate, Masters Degree in Development Studies", "Soccer, Vollyball","https://www.parliament.gov.zm/node/9050")
row3 <- c("7","Herbert  Shabula","UPND","Itezhi-Tezhi","2016","1955-03-01 22:00:00","Married","Human Resource Practitioner", "Certificate in Industrial Relations, Form V", "Fishing, Football","https://www.parliament.gov.zm/node/5323")
members <- rbind(members, row1, row2, row3)

#Clean name text
members_2 <- members %>% 
  select(-1) %>% 
  mutate(link = gsub("\\?page=1","", link), #Strip URLs so members have single identifier
         session = as.numeric(session),
         name = gsub(" GCDS|Rev|Lt|Rtd| Gen.|Col |Brig", "", name),
         name = tolower(name),
         name = removePunctuation(name),
         name = gsub("  ", " ", name),
         name = gsub("’", "", name),
         name = trimws(name),
         surname = word(name,-1),
         surname = gsub(" ", "", surname),
         first_name =  gsub(" ", "", word(name,1)),
         other_name =  gsub(" ", "", word(name,2)),
         other_name = ifelse(other_name==surname,NA, other_name),
         init_name = paste0(substr(first_name, 0,1)," ", surname),
         session = as.numeric(session),
         assembly = case_when(session > 2020 ~ 13,
                              session > 2015 ~ 12,
                              session > 2010 ~ 11,
                              session > 2005 ~ 10,
                              session > 1999 ~ 9),
         district = tolower(district),
         district = gsub("central", " central", district),
         district = gsub("north", " north", district),
         district = gsub("south", " south", district),
         district = gsub("west", " west", district),
         district = gsub("east", " east", district),
         assembly_dist = paste0(assembly, "_",district))

##create panel w all district-years
constit_panel <- merge(unique(members_2$district)
                       , unique(sessions$assembly)) %>% 
  rename("assembly" = y, "district" = x) %>% 
  mutate(assembly_dist = paste0(assembly, "_",district)) |> 
  dplyr::select(assembly_dist)%>% 
  right_join(members_2, by="assembly_dist") %>% 
  drop_na(name,assembly) |> 
  mutate(assembly_name = paste0(assembly, "_", surname),
         unique = paste0(init_name,"_",assembly,"_", district,"_",party),
         district_for_matching = sub(" .*", "", district))

write_csv(members_2, "/Users/jacobwinter/Dropbox/parl_debates_data/zambia_data/members_cleaned.csv")
#### Link to Speeches####
#Group speeches by speaker and session
split_raw <- read_csv(paste0(path,"split_debates_sec.csv")) %>% 
  mutate(speaker = removePunctuation(speaker),
         speaker = gsub("’","",speaker),
         speaker = gsub("asked*","",speaker),
         year = substr(date, 1,4),
         text = ifelse(is.na(text), speaker, text),
         text = gsub("\n\n"," -new_para- ",text)) #The line breaks get lost in processing text, so added them in as a new character for later splitting

split <- split_raw# %>% filter(date == "2022-3-2")#split_raw[sample(nrow(split_raw), 500), ]#[4200:5200,]#

split <- fuzzy_left_join(
  split,
  dplyr::select(sessions, -year),
  by = c("date" = "start","date" = "end"),
  match_fun = list(`>=`, `<=`)) %>% 
  mutate(speaker_clean = tolower(speaker),
         speaker_clean = removePunctuation(speaker_clean),
         otherspeakers = str_extract_all(speaker_clean,"speaker|members|opposition|vice|president|chairperson|chairman|chair"),
         otherspeakers = sapply(otherspeakers,paste,collapse = "_")) 

#### Set up to Match Speakers in Parallel ####
match_member <- function(daily_df){ #We have to process one day at a time because we reference whether a speaker has previously spoken
  
  output = data.frame()
  todays_speakers <- c()
  todays_assembly <- daily_df$assembly[1]
  
  
  member_pool <- constit_panel %>% 
    filter(assembly == todays_assembly)
  
  for(r in 1:nrow(daily_df)){ #Loop through that day's speeches
    source = daily_df[r,]
    
    if(str_length(source$otherspeakers)>1){ #Check if it is speaker/opposition, etc
      row <- data.frame(unique = paste0(source$otherspeakers,"_", source$session),
                        name = source$otherspeakers)
    }
    else{ #Otherwise, check if there is an easy single match, and make that the row
      matches <- member_pool %>% 
        mutate(match = str_extract(source$speaker_clean, surname),
               match_score = 10) %>% 
        filter(!is.na(match))
      row <- matches[1,]
      row$num_matches = nrow(matches)
      
      if(!nrow(matches)==1){ #If there is more than one match, then filter based on criteria
        matches <- member_pool %>% 
          mutate(match = str_extract(source$speaker_clean, surname),
                 match_val = ifelse(is.na(match),0,3), #Score 3 for surname match
                 
                 match_constit = str_extract(source$speaker_clean, district_for_matching),
                 match_constit_val = ifelse(is.na(match_constit),0,3),
                 
                 match_first = str_extract(source$speaker_clean, first_name),
                 match_first_val = ifelse(is.na(match_first),0,1),
                 
                 match_other = str_extract(source$speaker_clean, other_name),
                 match_other = ifelse(str_length(match_other)<2,NA,match_other), #Skip single letter matches
                 match_other_val = ifelse(is.na(match_other),0,1),
                 
                 match_init = str_extract(source$speaker_clean, init_name),
                 match_init_val = ifelse(is.na(match_init),0,1),
                 
                 match_prev_val = ifelse(unique %in% todays_speakers, 2, 0),
                 match_score = match_val+match_first_val+match_init_val+match_other_val+match_constit_val+match_prev_val #Score for max matches
          ) %>% 
          arrange(desc(match_score),
                  desc(str_length(match)))
      }
      if(max(matches$match_score>2)){row <- matches[1,]} #assign row if highest score is greater than 1
      else{row=data.frame(unique = NA, name ='unmatched')} #Otherwise show as missing
    }
    todays_speakers <- c(todays_speakers, row$unique[1])
    output <- plyr::rbind.fill(output, row)
  }
  
  return(output)
}
dates <- unique(split$date) #Vector of speech dates
path <-  "/Users/jacobwinter/Dropbox/parl_debates_data/zambia_data/split_matched_debates/" #dest path

match_day <- function(day){ #Generate new file with daily speech, metadata, and speaker info
  fpath = paste0(path,day,".csv")
  daily_df = filter(split, date==day)
  if(!file.exists(fpath)){ #Only process new docs
    cbind(daily_df, match_member(daily_df)) %>% 
      write_csv(fpath)
  }
  print(day)
}


mclapply(dates, match_day, mc.cores=detectCores()) 

#### Re merge ####
filelist <- list.files("/Users/jacobwinter/Dropbox/parl_debates_data/zambia_data/split_matched_debates")

df <- data.frame()
for(f in filelist){
  day <- read_csv(paste0("/Users/jacobwinter/Dropbox/parl_debates_data/zambia_data/split_matched_debates/",f))
  df <- plyr::rbind.fill(df, day)
}

write_csv(df, "/Users/jacobwinter/Dropbox/parl_debates_data/zambia_data/debates_matched_split_sec.csv")


# 
# merged <- cbind(split, dplyr::select(assigned_speakers, -c(assembly, session))) 
# 
# m2 <- merged %>% 
#   mutate(party = ifelse(grepl("government",tolower(speaker)),government, party),
#          party = ifelse(grepl("opposition",tolower(speaker)),opposition, party,
#          party = ifelse(grepl("speaker",tolower(speaker)),government, party)),
#          title = case_when(grepl("Mr ", speaker, ignore.case=T) ~ "Mr",
#                            grepl("Ms ", speaker, ignore.case=T) ~ "Ms",
#                            grepl("Mrs ", speaker, ignore.case=T) ~ "Mrs",
#                            grepl("Dr ", speaker, ignore.case=T) ~ "Dr",
#                            grepl("Prof |Professor", speaker, ignore.case=T) ~ "Prof")
#          )
#Possible additions: get the speaker details added in the loop so that it adds actually member details by session (including deputy). But these speaker statemnts will be filtered out anyway.

#write_csv(split_2, paste0(path,"matched_speeches_v5.csv"))





