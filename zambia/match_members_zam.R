#### Intro ####
# Title     : match_members.R
# Objective : Match debate text to corresponding member
# Created by: jacobwinter
# Created on: 2022-06-07 

library(tidyverse)
library(lubridate)
library(zoo)
library(svMisc)
library(tm)
library(quanteda)
library(seededlda)
library(readxl)
library(fuzzyjoin)
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
         end = lead(start)-1)


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
         surname = gsub(" \\(Rtd\\)", "", name),
         surname = gsub(" GCDS", "", surname),
         surname = word(surname,-1),
         surname = gsub(" ", "", surname),
         district_year = paste0(district, session))
#surnames
districts <- unique(members_2$district)
years <- data.frame("year"=seq(2000, 2023))

#create panel w all district-years
constit_panel <- merge(years, districts) %>% 
  rename("district" = y) %>% 
  mutate(district_year = paste0(district, year)) %>% 
  left_join(members_2, by="district_year") %>% 
  group_by(district.x) %>% 
  mutate_all(funs(na.locf(., na.rm = FALSE))) %>% 
  mutate(name_year = paste0(surname, year)) %>% 
  select(-district.y) %>% 
  rename(district = district.x)
  

#Identify district_years with duplicate- assign them "surname-district" names for clarity
doubles <- constit_panel %>% 
  drop_na(surname) %>% 
  group_by(name_year) %>% 
  summarize(surname = first(surname),
            year = first(year),
            n=n()
            )%>%
  filter(n>1) %>% #Keep only doubles
  select(name_year) %>% 
  left_join(constit_panel, by="name_year") %>% 
  mutate(surname = paste0(surname, " ",district))

constit_panel <- constit_panel %>% 
  filter(!name_year %in% doubles$name_year)%>% #get rid of districts with duplicates
  rbind(doubles) %>% #re-attach disambiguated names
  mutate(name_year = paste0(surname, year))


# #Speakers
all_surnames <- unique(constit_panel$surname)
## Sort short to long so that subnames will be overridden by longer ones (eg. Chila-->Chilama)
# all_surnames <- subset(all_surnames, !(unique(constit_panel$surname) %in% unique(doubles$surname.x))) #Get rid of surnames which occur across multiple constituency_years
# all_surnames <- c(all_surnames, unique(doubles$surname_district)) #Add surnames with constituency added

#### Link to Speeches####
#Group speeches by speaker and session

split_raw <- read_csv(paste0(path,"split_debates.csv")) %>% 
  mutate(year = substr(date, 1,4),
         text = ifelse(is.na(text), speaker, text))

split <- split_raw[sample(nrow(split_raw), 1000), ]

split <- fuzzy_left_join(
  split, sessions,
  by = c("date" = "start","date" = "end"),
  match_fun = list(`>=`, `<=`)) 




# Initialize columns for matching
split$matches <- ""
split$num_matches <- 0
split$multi <- ""
loops <- nrow(split)

#### Loop through "speaker" column and match with members ####
for(r in 1:loops){ #Go through each speech
  speaker <- split[[r,3]]
  num = 0
  ms = ""
  for(i in 1:length(all_surnames)){ #Go through each member
    speaker <- removePunctuation(speaker)
    name <- removePunctuation(all_surnames[i])
    m <- str_extract(speaker, name) #Get matches for member names within "speaker" column
    if(!is.na(m)==T){
      split$matches[[r]] <- m
      num = num+1
      ms <- paste0(ms, m, ", ")
    }
  }
  split$num_matches[[r]] <- num
  split$multi[[r]] <- ms
  progress(r, loops, progress.bar=F)
}

split_2 <- split %>% 
  mutate(name_year = paste0(matches, year)) %>% 
  left_join(constit_panel, by="name_year") %>% #Add member metainfo
  mutate(dummy = grepl("speaker|members|government|opposition",speaker, ignore.case = T))# %>% #Dummy for formal
  select(-year.x) %>% 
  rename(year=year.y)

prop.table(table(split_2$num_matches))*100
#Session assign
#Speaker session
#Group and assign

#When do MPs start after being elected?
# match "mr"/"mrs" to get get title (gender)
#match president, opposition, members, w party, meta
write_csv(split_2, paste0(path,"matched_speeches_v1.csv"))


