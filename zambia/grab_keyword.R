
library(quanteda)
library(tidyverse)

matched_speeches_v4 <- read.csv("~/Dropbox/RawDataHub/ZMB_Hansard/matched_speeches_v4.csv")

c2 <- matched_speeches_v4 %>% 
  filter(grepl("creditor",text))

write.csv(c2, "~/Desktop/cred_mentions.csv")
