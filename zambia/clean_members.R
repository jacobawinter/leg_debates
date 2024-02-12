#### Intro ####
# Title     : clean_members.R
# Objective : Clean list of member and constituency
# Created by: jacobwinter
# Created on: 2024-01-29
## NB: This will not write over old sheets that have already been processed. 
## If you want to re-process them all, delete the files from the folder

library(tidyverse)
library(lubridate)
library(readxl)
options(scipen=99)

path = "~/Dropbox/parl_debates_data/zambia_data/"





















#Load and merge scraped members from different sheets
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
         #name = gsub("  ", " ", name),
         #name = gsub("’", "", name),
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

