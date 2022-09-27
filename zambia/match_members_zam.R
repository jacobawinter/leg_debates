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
path = "~/repos/parl_debates_zambia/"

#Load and merge members
sheets <- list.files(paste0(path, "raw_data/members/"))
members <- read_csv(paste0(path,"raw_data/members/", sheets[1]))

for(i in 2:length(sheets)){
  print(i)
  data <- read_csv(paste0(path,"raw_data/members/", sheets[i]))
  members <- plyr::rbind.fill(members, data)
}


#Manually fix error for "Itezhi-Tezhi" members
members <- filter(members, district != "Itezhi")
row1 <- c("1", "Greyford Monde", "UPND", "Itezhi-Tezhi", "2011", "1977-04-09 22:00:00", "Married", "Businessman", "Grade 12", "Football, Praying, Youth Promotion", 'https://www.parliament.gov.zm/node/326')
row2 <- c("20", "Twaambo Elvis Mutinta", "UPND", "Itezhi-Tezhi", "2021", "1983-09-27 22:00:00","Married","Programmes Officer, Teacher","Bachelor of Adult Education, Certificate in Social Work, Diploma in Secondary Education, Grade 12 Certificate, Masters Degree in Development Studies", "Soccer, Vollyball","https://www.parliament.gov.zm/node/9050")
row3 <- c("7","Herbert  Shabula","UPND","Itezhi-Tezhi","2016","1955-03-01 22:00:00","Married","Human Resource Practitioner", "Certificate in Industrial Relations, Form V", "Fishing, Football","https://www.parliament.gov.zm/node/5323")
members <- rbind(members, row1, row2, row3)


members_2 <- members %>% 
  select(-X1) %>% 
  mutate(link = gsub("\\?page=1","", link), #Strip URLs so members have single identifier
         session = as.numeric(session),
         surname = gsub(" \\(Rtd\\)", "", name),
         surname = gsub(" GCDS", "", surname),
         surname = word(surname,-1),
         surname = gsub(" ", "", surname),
         district_year = paste0(district, session))
#surnames
districts <- unique(members_2$district)
years <- data.frame("year"=seq(2000, 2022))

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
  

#Identify Country_years with duplicate
doubles <- constit_panel %>% 
  drop_na(surname) %>% 
  group_by(name_year) %>% 
  summarize(surname = first(surname),
            year = first(year),
            n=n()
            )%>%
  filter(n>1) %>% 
  select(name_year) %>% 
  left_join(constit_panel, by="name_year") %>% 
  mutate(surname = paste0(surname, " ",district))

constit_panel <- constit_panel %>% 
  filter(!name_year %in% doubles$name_year)%>% 
  rbind(doubles) %>% 
  mutate(name_year = paste0(surname, year))


# #Speakers
all_surnames <- unique(constit_panel$surname)
## Sort short to long so that subnames will be overridden by longer ones (eg. Chila-->Chilama)
# all_surnames <- subset(all_surnames, !(unique(constit_panel$surname) %in% unique(doubles$surname.x))) #Get rid of surnames which occur across multiple constituency_years
# all_surnames <- c(all_surnames, unique(doubles$surname_district)) #Add surnames with constituency added

#Group speeches by speaker and session
split_raw <- read_csv(paste0(path,"raw_data/split_debates.csv")) %>% 
  mutate(year = substr(date, 1,4),
         text = ifelse(is.na(text), speaker, text))

split <- split_raw#[sample(nrow(split_raw), 1000), ]

table(substr(split_raw$date, 0,4))

split$matches <- ""
split$num_matches <- 0
split$multi <- ""
loops <- nrow(split)
for(r in 1:loops){
  speaker <- split[[r,3]]
  num = 0
  ms = ""
  for(i in 1:length(all_surnames)){
    speaker <- removePunctuation(speaker)
    name <- removePunctuation(all_surnames[i])
    m <- str_extract(speaker, name)
    if(!is.na(m)==T){
      split$matches[[r]] <- m
      num = num+1
      split$num_matches[[r]] <- num
      ms <- paste0(ms, m, ", ")
    }
  }
  split$multi[[r]] <- ms
  progress(r, loops, progress.bar=F)
}
split_2 <- split %>% 
  mutate(name_year = paste0(matches, year)) %>% 
  left_join(constit_panel, by="name_year") %>% 
  mutate(dummy = grepl("speaker|members|government|opposition",speaker, ignore.case = T)) %>% 
  select(-year.x) %>% 
  rename(year=year.y)

options(scipen=99)
prop.table(table(split_2$num_matches))*100


#Session assign
#Speaker session
#Group and assign


#When do MPs start after being elected?
# match "mr"/"mrs" to get get title (gender)
#match president, opposition, members, w party, meta
write_csv(split_2, paste0(path,"raw_data/matched_speeches_v1.csv"))
################### Start Here ############
text <- read_csv(paste0(path,"raw_data/matched_speeches_v1.csv"))

table(substr(text$date, 0,4))

corpus <- corpus(text)

toks_news <- tokens(corpus, remove_punct = TRUE, remove_numbers = TRUE, remove_symbol = TRUE)
toks_news <- tokens_remove(toks_news, pattern = c(stopwords("en"), "*-time", "updated-*", "gmt", "bst"))
dfmat_news <- dfm(toks_news) %>% 
  dfm_trim(min_termfreq = 0.8, termfreq_type = "quantile",
           max_docfreq = 0.1, docfreq_type = "prop")

tmod_lda <- textmodel_lda(dfmat_news, k = 15)

terms(tmod_lda, 10)
# assign topic as a new document-level variable
dfmat_news$topic <- topics(tmod_lda)

# cross-table of the topic frequency
table(dfmat_news$topic)

df <- data.frame(dfmat_news@docvars) %>% 
  group_by(year, topic) %>% 
  summarize() 

ggplot(filter(df, topic=='topic1'|topic=='topic14'|topic=='topic15'), aes(x=year, y=n, group=topic)) +
  geom_line(aes(color=topic))

table(df$year, df$topic)

df <- cbind(text, tmod_lda[["theta"]]) %>% 
  mutate(title = ifelse(grepl("Mr ", speaker, ignore.case=T), "Mr", 
                        ifelse(grepl("Ms", speaker, ignore.case=T), "Ms", 
                               ifelse(grepl("Mrs", speaker, ignore.case=T), "Mrs", 
                                      ifelse(grepl("Dr", speaker, ignore.case=T), "Dr", "NA"))))
  )

df2 <- df %>% 
  group_by(year, party) %>% 
  summarize(topic1=mean(topic1),  #tax
            topic15 = mean(topic15), #farmers
            topic2=mean(topic2), #corrupt
            topic12=mean(topic12)) #roads 

ggplot(filter(df2, year>2007, party %in% c("MMD", "PF", "UPND")
              ), aes(x=year, y=topic2, group=party)) +
  geom_line(aes(color=party)) +
  #geom_line(aes(y=topic15), color=2) +
  #geom_line(aes(y=topic12), color=3) +
  theme_bw()


df2 <- df %>% 
  group_by(year, title) %>% 
  summarize(topic1=mean(topic1),  #tax
            topic15 = mean(topic15), #farmers
            topic2=mean(topic2), #corrupt
            topic12=mean(topic12)) #roads 

ggplot(filter(df2, year>2007, title %in% c("Mr", "Ms", "Mrs", "Dr")
), aes(x=year, y=topic15, group=title)) +
  geom_line(aes(color=title)) +
  #geom_line(aes(y=topic15), color=2) +
  #geom_line(aes(y=topic12), color=3) +
  theme_bw()
  

