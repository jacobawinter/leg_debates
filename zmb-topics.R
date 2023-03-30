# Title     : zmb_topics.R
# Objective : process legislative debates and get topics
# Created by: jacobwinter
# Created on: 2023-03-14 

library(tidyverse)
library(lubridate)
library(quanteda)
library(countrycode)
library(readxl)
library(stm)
library(seededlda)
library(keyATM)
library(haven)

options(scipen=99)
theme_set(theme_minimal())

path = "~/Dropbox/parl_debates_data/zambia_data/"

text <- read_csv(paste0(path,"matched_speeches_v1.csv")) |> 
  mutate(date = ymd(date))

leaders <- read_excel("~/repos/archive/parl_debates/zambia/raw_data/year_map.xlsx",1) |> 
  mutate(gov = paste(government,"- ", president)) |> 
  select(year, gov)

text2 <- text |> 
  filter(str_length(text)>0, str_length(text)<10000) |> 
  rename('doc_id' =1)  |>  
  left_join(leaders, by='year') |> 
  mutate(time = as.numeric(substr(date, 1,4))+(as.numeric(substr(date, 6,7))/12),
         doc_id = 1,
         doc_id = cumsum(doc_id)) 

text2 |> 
  mutate(year = substr(date, 1,4),
         month=substr(date, 6,7)) |> 
  group_by(year, month) |> 
  summarize(n = n()) |>
  ggplot(aes(x=month, y=n)) + geom_col() + facet_wrap(vars(year)) + theme_bw()

custom_stops <- c("order", "mr", "hon", "minister", 'speaker', "government", 
                  "people", "hear","madam","question",'thank', 'committee',
                  'point','house','sir','zambia','ministry','member','laughter',
                  'country','one','can','us','interruptions','yes','chair',
                  'motion','raised','floor','second','please','words', 'zambians',
                  'mospagebreak', 'interrupt','shame', 'hammer','heckle', "govern",
                  "countri","zambian",'minist','ministri')

dfm <- corpus(text2) |> 
  tokens(remove_punct = TRUE,
         remove_symbols = TRUE,
         remove_numbers = TRUE) |> 
  tokens_wordstem() |> 
  dfm(remove = c(custom_stops, stopwords(source = "smart")))


m <- table(text2$text) |> data.frame()
# ####
# dfm2 <- dfm |> 
#   dfm_sample(9500)
# 
# dim(dfm2)
# 
# set.seed(123)
# topics <- textmodel_lda(dfm2, k=15)
# 
# terms(topics, 15)
# 
# m <- terms(topics, 4) |> t() |> 
#   as.data.frame() |> 
#   rownames_to_column() |> 
#   rename("topic"="rowname") |> 
#   mutate(topic_name = paste(topic,V1,V2,V3,V4, sep="_")) |> 
#   select(c(1,6))
# 
# 
# text2$topic <- topics(topics)
# 
# t3 <- text2 |> 
#   group_by(year, topic) |> 
#   summarize(n = n()) |> 
#   group_by(year) |> 
#   mutate(total = sum(n, na.rm=T),
#          topic_prev = n/total) |> 
#   group_by(topic) |> 
#   mutate(topic_share = sum(topic_prev)) |> 
#   left_join(m, by='topic')
#   
# table(t3$topic_name)
# t3 |> 
#   drop_na(topic) |> 
#   ungroup() |> 
#   filter(#topic_share > 1.05,#mean(topic_share, na.rm=T),
#          !topic %in% c("topic14", "topic8", "topic2", "topic4")) |> 
#   ggplot() +
#   geom_line(aes(x=year, y=topic_prev, color=topic_name, group=topic_name)) +
#   geom_point(aes(x=year, y=topic_prev, color=topic_name, group=topic_name)) +
#   facet_wrap(vars(topic_name)#, scales='free'
#              )
#   

###### KeyATM #####
#Assign topic keywords with keyATM

n <- (ntoken(dfm))
dfm$length <- list(n)

dfm3 <- dfm_subset(dfm, length >0)

#dfm3 <- dfm_sample(dfm3, 5000)
docs <- keyATM_read(dfm3, progress_bar = TRUE, keep_docnames = TRUE)

keywords <- list(
  Borrowing = c("borrow", "debt", "loan", "bond",'eurobond','credit','creditor'),
  Tax = c("tax", "revenue", "paye", "royal","zra"),
  Copper = c("mine", 'copper','ore'),
  Roads = c('road','highway','pave','bitumen')
)

visualize_keywords(docs, keywords)

table(dfm3$time)

dfm3$time2 <- as.integer(factor(dfm3$time))
dfm3 <-  dfm3[order(dfm3$time2),]
time_states <- length(unique(dfm3$time2))

out <- keyATM(docs=docs, no_keyword_topics = 9, keywords = keywords, 
              #model='base',
              model = "dynamic",
              model_settings = list(time_index = dfm3$time2,num_states = time_states),
              options = list(iterations=1000, seed=123, store_theta = TRUE, thinning=10))
save(out, file="model_zmbparl.RData")
#beepr::beep()


top_words(out, 20)
plot_pi(out)
plot_alpha(out)
p <- plot_timetrend(out, time_index_label=(dfm3$time), point='median', scales='free') +
  geom_smooth()

ggsave("~/Desktop/fig1.jpg", plot=p)


text3 <- text2 |> 
  filter(doc_id %in% docs[["docnames"]]) |> 
  cbind(out$theta)


rates <- read.csv("~/Dropbox/RawDataHub/US_interest_rates/TB3MS_2023.02.csv") |> 
  mutate(date = as.Date(DATE),
         year_mon = lubridate::floor_date(date, "month")) |> 
  dplyr::select(year_mon, TB3MS)
#Fig by party

#How much to adjust FED rate
scale_factor <- .1

text3 |> 
  mutate(year_mon = lubridate::floor_date(date, "month")) |> 
  group_by(year_mon, party) |> 
  filter(party %in% c("UPND", "MMD","PF")) |> 
  summarize(borrowing = mean(`1_Borrowing`,na.rm=T),
            tax = mean(`2_Tax`,na.rm=T),
            copper = mean(`3_Copper`,na.rm=T),
            roads = mean(`4_Roads`,na.rm=T),
            social = mean(`Other_5`,na.rm=T),
            ) |> 
  left_join(rates, by='year_mon') |> 
  filter(year_mon > as.Date("2006-01-01")) |> 
  ggplot(aes(x=year_mon, 
             y=tax, 
             group=party, color=party)) +
  geom_vline(xintercept = as.Date("2021-08-01"), color='darkblue') +
  geom_vline(xintercept = as.Date("2016-08-01"), color='darkblue') +
  geom_vline(xintercept = as.Date("2011-09-01"), color='darkblue') +
  geom_vline(xintercept = as.Date("2006-09-01"), color='darkblue') +
  geom_line(alpha=.8) + geom_point(size=.5) +
  geom_line(aes(y= TB3MS*scale_factor), color="red", linetype=2) +
  scale_x_date(date_labels="%Y",date_breaks  ="1 year") +
  theme(axis.text.x = element_text(angle = 90, vjust = .5, hjust=0)) +
  geom_smooth(se=F) +
  #ylim(0,.25) +
  labs(x='Date',
       title="Legislative Rhetoric and Interest Rates",
       subtitle="Red line shows Fed Rate (TB3MS, rescaled), blue vertical lines show election months")

text3 |> 
  mutate(year_mon = lubridate::floor_date(date, "month")) |> 
  group_by(year_mon) |> 
  summarize(borrowing = mean(`1_Borrowing`,na.rm=T),
            tax = mean(`2_Tax`,na.rm=T),
            copper = mean(`3_Copper`,na.rm=T),
            roads = mean(`4_Roads`,na.rm=T),
            social = mean(`Other_5`,na.rm=T),
  ) |> 
  left_join(rates, by='year_mon') |> 
  filter(year_mon > as.Date("2006-01-01")) |> 
  ggplot(aes(x=year_mon, 
             y=tax)) +
  geom_vline(xintercept = as.Date("2021-08-01"), color='darkblue') +
  geom_vline(xintercept = as.Date("2016-08-01"), color='darkblue') +
  geom_vline(xintercept = as.Date("2011-09-01"), color='darkblue') +
  geom_vline(xintercept = as.Date("2006-09-01"), color='darkblue') +
  geom_line(alpha=.8) + geom_point(size=.5) +
  #geom_line(aes(y= TB3MS/20), color="red", linetype=2) +
  scale_x_date(date_labels="%Y",date_breaks  ="1 year") +
  theme(axis.text.x = element_text(angle = 90, vjust = .5, hjust=0)) +
  #ylim(0,.25) +
  labs(x='Date',
       title="Legislative Rhetoric and Interest Rates",
       subtitle="Red line shows Fed Rate (TB3MS, rescaled), blue vertical lines show election months")


#Correlation
t4 <- text3 |> 
  mutate(year_mon = lubridate::floor_date(date, "month")) |> 
  group_by(year_mon) |> 
  #filter(party %in% c("UPND", "MMD","PF")) |> 
  summarize(borrowing = mean(`1_Borrowing`,na.rm=T),
            tax = mean(`2_Tax`,na.rm=T),
            copper = mean(`3_Copper`,na.rm=T),
            roads = mean(`4_Roads`,na.rm=T),
            social = mean(`Other_5`,na.rm=T),
  ) |> 
  left_join(rates, by='year_mon') |> 
  filter(year_mon > as.Date("2006-01-01")) |> 
  arrange(year_mon) |> 
  mutate(lag_rates = lag(TB3MS, 1),
         year = substr(year_mon,1,4))

  ggplot(t4, aes(x=lag_rates, 
             y=borrowing)) + 
  geom_point(alpha=.5, aes(color=year_mon)) + geom_smooth(method='lm', se=F) +
  viridis::scale_color_viridis() +
  labs(x="Interest Rates (month lag)", 
       #y="Prevalence of Tax Talk"
       )

lm(borrowing ~lag_rates, data=t4) |> summary()


                         