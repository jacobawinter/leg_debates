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
library(readxl)
library(parallel)
options(scipen=99)

path = "~/Dropbox/parl_debates_data/zambia_data/"

#### Load and Clean Members ####
#Load and merge scraped members from different sheets
sheets <- excel_sheets(path = paste0(path, "members_from_report/members_list.xlsx"))
members <- data.frame()

for(i in 1:length(sheets)){
  data <- read_excel(paste0(path, "members_from_report/members_list.xlsx"), i)
  members <- plyr::rbind.fill(members, data)
}


###Import Alt names####
alt_names = read_csv(paste0(path,"members_from_report/alt_names.csv")) %>% 
  #filter(matched_constit != "nominated") %>% #For now
  mutate(alt_name = gsub("\n","", speaker),
         id = as.numeric(id)) %>% 
  #aggregate(text ~ group, data = df, FUN = paste, collapse = "")
  aggregate(alt_name ~ id, paste, collapse=" | ") #Paste all entries with |


#Clean name text
members_2 <- members %>% 
  mutate(name = gsub(" GCDS|Rev|Lt|Rtd| Gen.|Col |Brig|The |Hon", "", member),
         name = tolower(name),
         name = removePunctuation(name),
         name = trimws(name),
         surname = word(name,-1),
         surname = gsub(" ", "", surname),
         first_name =  gsub(" ", "", word(name,1)),
         other_name =  gsub(" ", "", word(name,2)),
         other_name = ifelse(other_name==surname,NA, other_name),
         init_name = paste0(substr(first_name, 0,1)," ", surname),
         constituency = tolower(constituency),
         unique = paste(surname, constituency, assembly, sep="_")) %>% #write_csv("~/Desktop/members_merged.csv")
  left_join(alt_names, by="id")
#### Link to Speeches####
#Group speeches by speaker and session
split_raw <- read_csv(paste0(path,"split_debates_sec_2024_01_29.csv")) %>% 
  select(-1) %>% 
  mutate(#speaker = removePunctuation(speaker),
         speaker = gsub("’","",speaker),
         speaker = gsub("\n","",speaker),
         speaker = gsub("asked*","",speaker),
         year = substr(date, 1,4),
         text = ifelse(is.na(text), speaker, text),
         text = gsub("\n\n"," -new_para- ",text)) #The line breaks get lost in processing text, so added them in as a new character for later splitting

#sample_dates <- unique(split_raw$date) %>% sample(250)

split <- split_raw #%>% filter(date %in% sample_dates)#split_raw[sample(nrow(split_raw), 500), ]#[4200:5200,]#

split <- split %>% 
  # fuzzy_left_join(
  # dplyr::select(sessions, -year),
  # by = c("date" = "start","date" = "end"),
  # match_fun = list(`>=`, `<=`)) %>% 
  mutate(assembly = ymd(date),
         assembly = case_when(assembly > ymd("2021-05-14") ~ "2021-2026", #last dates of each assembly, found manually
                              assembly > ymd("2016-11-05") ~ "2016-2021",
                              assembly > ymd("2011-10-06") ~ "2011-2016", #eleventh assembly start
                              assembly > ymd("2006-10-20") ~ "2006-2011", #tenth
                              assembly > ymd("2002-01-25") ~ "2001-2006", #ninth
                              assembly > ymd("1996-01-01") ~ "1996-2001"
                              
                             ),
         speaker_clean = tolower(speaker),
         #speaker_clean = removePunctuation(speaker_clean),
         speaker_clean = gsub("('|:|,|\\.)", "", speaker_clean),
         
         otherspeakers = str_extract_all(speaker_clean,"member|speaker|members|opposition|vice|president|chairperson|chairman|chair"),
         otherspeakers = sapply(otherspeakers,paste,collapse = "_"))

#filter(split, grepl("'", split$speaker_clean)) %>% view() #Check


#### Set up to Match Speakers in Parallel ####
match_member <- function(daily_df){ #We have to process one day at a time because we reference whether a speaker has previously spoken
  
  output = data.frame()
  todays_speakers <- c()
  todays_assembly <- daily_df$assembly[1]
  
  member_pool <- members_2 %>% 
    filter(assembly == todays_assembly) %>% 
    select(-assembly)
  
  for(r in 1:nrow(daily_df)){ #Loop through that day's speeches
    source = daily_df[r,]
    
    if(str_length(source$otherspeakers)>1){ #Check if it is speaker/opposition, etc
      row <- data.frame(unique = paste0(source$otherspeakers,"_", source$assembly),
                        name = source$otherspeakers)
    }
    else{ #Otherwise, check if there is an easy single match, and make that the row
      speaker_name = source$speaker_clean
      matches <- member_pool %>% 
        mutate(match = str_extract(speaker_name, surname),
               match_score = 10) %>% 
        filter(!is.na(match))
      row <- matches[1,] #Keep the first row in case it is a single match
      row$num_matches = nrow(matches)
      
      if(!nrow(matches)==1){ #If there is more than one match, then filter based on criteria
        matches <- member_pool %>% 
          filter(if (grepl("ms |mrs ", speaker_name)) sex=="F" 
                 else TRUE) %>% #If mrs or ms in title, filter to female members
          mutate(match = str_extract(speaker_name, surname),
                 match_val = ifelse(is.na(match),0,3), #Score 3 for surname match
                 
                 match_alt = str_extract(alt_name, fixed(speaker_name)),
                 match_alt_val = ifelse(is.na(match_alt),0,8), #Score 8 if there is a string match with a know alternative name for a member
                 
                 match_constit = str_extract(speaker_name, coll(paste0("(",constituency,")"))),
                 match_constit_val = ifelse(is.na(match_constit),0,6),
                 
                 match_first = str_extract(speaker_name, first_name),
                 match_first_val = ifelse(is.na(match_first),0,1),
                 
                 match_other = str_extract(speaker_name, other_name),
                 match_other = ifelse(str_length(match_other)<2,NA,match_other), #Skip single letter matches
                 match_other_val = ifelse(is.na(match_other),0,1),
                 
                 match_init = str_extract(speaker_name, init_name),
                 match_init_val = ifelse(is.na(match_init),0,1),
                 
                 
                 match_prev_val = ifelse(unique %in% todays_speakers, 2, 0),
                 match_score = match_val+match_first_val+match_init_val+match_other_val+match_constit_val+match_prev_val+match_alt_val #Score for max matches
          ) %>% 
          arrange(desc(match_score),
                  desc(str_length(match)))
      }
      if(max(matches$match_score>2)){row <- matches[1,]} #assign row if highest score is greater than 2
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
    out <- daily_df %>% 
      match_member() 
    cbind(daily_df, out) %>% 
      write_csv(fpath)
  }
}


# Test single day
# date = sample(dates, 1)
# vec = (split$date==date) #I don't know why but it just won't filter otherwise
# out <-
#   split %>% filter(vec) %>% match_member()
# 
# split %>% filter(vec) %>%
#   cbind(select(out, -assembly)) %>%
#   #select(speaker, speaker_clean, text, member, name, constituency, match_alt, match_alt_val) %>%
#   view()

mclapply(dates, match_day, mc.cores=detectCores()) 

#### Re merge ####
filelist <- list.files("/Users/jacobwinter/Dropbox/parl_debates_data/zambia_data/split_matched_debates")

df <- data.frame()
for(f in filelist){
  day <- read_csv(paste0("/Users/jacobwinter/Dropbox/parl_debates_data/zambia_data/split_matched_debates/",f), show_col_types = FALSE)
  df <- plyr::rbind.fill(df, day)
}

df$section_name = str_replace_all(df$section_name, "[\r\n]" , "")

write_csv(df, "/Users/jacobwinter/Dropbox/parl_debates_data/zambia_data/debates_matched_split_sec.csv")
#df <- read_csv("/Users/jacobwinter/Dropbox/parl_debates_data/zambia_data/debates_matched_split_sec.csv")

d2 <- df %>% 
  filter(name == "unmatched"
         ) %>% 
  group_by(speaker_clean, assembly) %>% summarise(num = n()) %>% 
  ungroup() %>% 
  arrange(desc(num))

d3 <- df %>% 
  filter(is.na(otherspeakers)) %>%
  mutate(found = ifelse(name=="unmatched","No","Yes")) %>% 
  group_by(found) %>% 
  summarize(n = n()) %>% 
  mutate(prop = n/sum(n))


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

