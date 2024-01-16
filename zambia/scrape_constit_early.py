import requests
from bs4 import BeautifulSoup
import re
import pandas as pd
import time
from tqdm import tqdm
# Create list of nodes


m_name = []
m_date = []
m_party = []
m_district = []
m_link = []

# m_dob = []
# m_marital = []
# m_job = []
# m_ed = []
# m_hobbies = []
# m_session = []
# m_portfolio = []
# m_page2 =[]
## Scrape parl history and make an entry for each session

# Change and rerun in sections
start = 10000
end = 12500

i = 4375

url = "https://www.parliament.gov.zm/node/"+str(i)
page = requests.get(url)

soup = BeautifulSoup(page.content, "html.parser")

type = soup.find('div',
                     {'class': "field field-name-field-mp field-type-entityreference field-label-above"})  # Check if it is a parliamentary profile page


if page:  # If page loads
    soup = BeautifulSoup(page.content, "html.parser")
    type = soup.find('div',
                     {'id': "field field-name-field-mp field-type-entityreference field-label-above"})  # Check if it is a parliamentary profile page
    if type:
        name = soup.find("h1", id="page-title").text.strip()
        if name:
            m_name.append(name)
        else:
            m_name.append("")

        #date
        date_elec = soup.find('span', {'class': "date-display-single"}).text.strip()
        if date_elec:
            m_date.append(date_elec)
        else:
            m_date.append("")

        # party
        party = soup.find('div', {'class': "field field-name-field-political-party field-type-taxonomy-term-reference field-label-above"})
        party = party.find('a').text.strip()
        if party:
            m_party.append(party)
        else:
            m_party.append("")

        #constit
        district = soup.find('span', {'class': "field field-name-field-constituency-name field-type-entityreference field-label-above"})
        if date_elec:
            m_date.append(date_elec)
        else:
            m_date.append("")


