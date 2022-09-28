# Title     : prelim_process.R
# Objective : Process zambia Debate Texts
# Created by: jacobwinter
# Created on: 2022-04-23

library(tidyverse)
library(quanteda)
library(lubridate)

setwd("~/Desktop/UofT/Projects/scrape_zambia")
texts <- read_csv("~/repos/parl_debates_zambia/raw_data/parl_debates_zm.csv")

toks <- corpus(texts) %>%
  tokens()

tax <- kwic(toks, "tax*")

hipc <- kwic(toks, "HIPC*")

kubeba <- kwic(toks, "kubeba", 15)

copper_raw <- readxl::read_excel("commodity_prices.xlsx", sheet=2)
copper <- copper_raw %>%
  mutate(date_2 = parse_date_time(month, "%Y%m"),
         period = format(date_2, "%Y.%m"),
         copper = as.numeric(Copper)) %>%
  select(period, copper) %>%
  filter(period > 200601)


t <- tax %>%
  mutate(number = gsub("text", "", docname),
         number = as.integer(number)) %>%
  right_join(texts, by=c("number" = "X1"))


tt <- t %>%
  mutate(date_2 = parse_date_time(date, "%A, %d %b, %Y"),
         period = format(date_2, "%Y.%m")) %>%
  group_by(period) %>%
  summarize(mentions = n()) %>%
  right_join(copper) %>%
  mutate(period = parse_date_time(period, "%Y.%m"),
         copper_map = scales::rescale(copper, to=c(min(.$mentions, na.rm=T), max(.$mentions, na.rm=T))))

tt <- texts %>%
  mutate(date = parse_date_time(date, "%A, %d %b, %Y"),
         period = format(date, "%Y.%m")) %>%
  group_by(period) %>% 
  summarise(n=n())

p <- ggplot(drop_na(tt)) +
  theme_bw() +
  geom_rect(aes(xmin=parse_date_time("2010-10-01", "%Y-%m-%d"),
                xmax = parse_date_time("2010-12-01", "%Y-%m-%d"),
                ymin=0, ymax=Inf), fill = "lightblue", alpha=.4) +
  geom_rect(aes(xmin=parse_date_time("2011-10-01", "%Y-%m-%d"),
                xmax = parse_date_time("2011-12-01", "%Y-%m-%d"),
                ymin=0, ymax=Inf), fill = "lightblue", alpha=.4) +
  geom_rect(aes(xmin=parse_date_time("2012-10-01", "%Y-%m-%d"),
                xmax = parse_date_time("2012-12-01", "%Y-%m-%d"),
                ymin=0, ymax=Inf), fill = "lightblue", alpha=.4) +
  geom_line(aes(x=period, y=copper_map, group=1), color="red", linetype=4, alpha=.8) +
  geom_line(aes(x=period, y=mentions, group=1)) +
  scale_x_continuous(breaks = parse_date_time(seq(2006, 2022, 1), "%Y"), labels=seq(2006, 2022, 1)) +
  annotate("text", label="Debate Periods Analyzed", x=parse_date_time("2011-12-01", "%Y-%m-%d"), y=520, size=4, color='darkblue') +
  annotate("text", label="Copper Price\n Index", x=parse_date_time("2020-03-01", "%Y-%m-%d"), y=350, size=4, color='red') +
  #annotate("text", label="\'Tax\' mentions", x=parse_date_time("2009-06-01", "%Y-%m-%d"), y=460, size=4) +
  xlab("Year") +
  ylab("Mentions of Tax in Debates")

ggsave(plot=p, "rhetoric.jpg", width=10, height=5)

openxlsx::write.xlsx(texts, "debates.xlsx")


split_raw <- read_csv("~/repos/parl_debates_zambia/split_debates.csv")

split <- split_raw %>% 
  group_by(speaker) %>% 
  summarize(n = n())

