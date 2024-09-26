# scrape_portfolios.py
# Jacob Winter
# April 2024
# Scrape portfolios from Zambia parliament website
#
# # Setup
import pandas as pd
import time
from tqdm import tqdm
import requests
from bs4 import BeautifulSoup
import re

members = pd.read_csv("~/Dropbox/parl_debates_data/zambia_data/members_cleaned.csv")

# Create list of nodes
m_url = []
m_portfolio = []

m_page2 = []

#keep only unique urls
urls = list(set(members['link']))


for url in tqdm(urls):
    try:
        time.sleep(1)
        page = requests.get(url)
        if page: #If page loads
            soup = BeautifulSoup(page.content, "html.parser")
            type = soup.find('div', {'id':"block-views-members-of-parliament-block-1"}) #Check if it is a parliamentary profile page
            if type:
                page2 = soup.find('div', {'id': 'block-views-members-of-parliament-block-1'})
                page2 = page2.find('a', {'title': 'Go to next page'}) #Check if there is "Page 2" membership data
                if page2:
                    m_page2.append("https://www.parliament.gov.zm/node/" + str(i) + "?page=1")
                sessions = soup.findAll('div', {'class': 'views-field views-field-field-portfolio'})
                for s in sessions:
                    s = s.get_text("", strip=True)
                    m_portfolio.append(s)
                    m_url.append(url)

    except:
        pass


for j in tqdm(m_page2): #Rescrape pages with a second page
    time.sleep(1)
    page = requests.get(j)
    if page: #If page loads
        soup = BeautifulSoup(page.content, "html.parser")
        sessions = soup.findAll('div', {'class': 'views-field views-field-field-portfolio'})
        for s in sessions:  # Break session info into three strings
            s = s.get_text("", strip=True)
            m_portfolio.append(s)
            m_url.append(j)


df = pd.DataFrame({'url': m_url, 'portfolio': m_portfolio})
df.to_csv("~/Dropbox/parl_debates_data/zambia_data/portfolios.csv", index = False)
