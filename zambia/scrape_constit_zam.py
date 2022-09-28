import requests
from bs4 import BeautifulSoup
import re
import pandas as pd
import time
from tqdm import tqdm
# Create list of nodes


m_name = []
m_dob = []
m_marital = []
m_job = []
m_ed = []
m_hobbies = []
m_session = []
m_party = []
m_district = []
m_link = []
m_portfolio = []

m_page2 =[]
## Scrape parl history and make an entry for each session

# Change and rerun in sections
start = 10000
end = 12500

for i in tqdm(range(start,end)):
    try:
        time.sleep(2)
        url = "https://www.parliament.gov.zm/node/"+str(i)
        page = requests.get(url)
        if page: #If page loads
            soup = BeautifulSoup(page.content, "html.parser")
            type = soup.find('div', {'id':"block-views-members-of-parliament-block-1"}) #Check if it is a parliamentary profile page
            if type:
                page2 = soup.find('div', {'id': 'block-views-members-of-parliament-block-1'})
                page2 = page2.find('a', {'title': 'Go to next page'}) #Check if there is "Page 2" membership data
                if page2:
                    m_page2.append("https://www.parliament.gov.zm/node/" + str(i) + "?page=1")
                sessions = soup.findAll('div', {'class': 'views-field views-field-field-constituency-name'})
                for s in sessions: #Break session info into three strings
                    s = s.get_text("", strip=True)
                    s = s.replace(" ", "")
                    s = s.split("-")
                    if len(s) > 1: #Confirm that there is session info, if blank then skip
                        m_district.append(s[0])
                        m_session.append(s[1])
                        m_party.append(s[2])

                        name = soup.find("h1", id="page-title").text.strip()
                        if name:
                            m_name.append(name)
                        else:
                            m_name.append("")
                        dob = soup.find('div', {'class': 'field field-name-field-date field-type-datetime field-label-inline clearfix'})

                        if dob:
                            dob = dob.find('span', {'class': 'date-display-single'})['content']
                            m_dob.append(dob)
                        else:
                            m_dob.append("")
                        marital = soup.find('div', {'class': 'field field-name-field-marital-status field-type-list-text field-label-inline clearfix'})

                        if marital:
                            marital = marital.find('div', {'class': 'field-item even'}).text.strip()
                            m_marital.append(marital)
                        else:
                            m_marital.append("")
                        job = soup.find('div', {'class': 'field field-name-field-profession field-type-taxonomy-term-reference field-label-inline clearfix'})
                        if job:
                            job = job.get_text(", ", strip=True)
                            job = job.replace("Profession:, ", "")
                        else:
                            job=""
                        m_job.append(job)
                        # if job:
                        #     job = job.get_text(", ", strip=True)
                        #     job = job.replace("Profession:, ", "")
                        #     m_job.append(job)
                        # else:
                        #     m_job.append("job")
                        ed = soup.find('div', {'class': 'field field-name-field-educational-qualification field-type-taxonomy-term-reference field-label-inline clearfix'})
                        if ed:
                            ed = ed.get_text(", ", strip=True)
                            ed = ed.replace("Educational Qualification:, ", "")
                        else:
                            ed = ""
                        m_ed.append(ed)

                        hobbies = soup.find('div', {
                            'class': 'field field-name-field-hobbies field-type-taxonomy-term-reference field-label-inline clearfix'})
                        if hobbies:
                            hobbies = hobbies.get_text(", ", strip=True)
                            hobbies = hobbies.replace("Hobbies:, ", "")
                        else:
                            hobbies = ""
                        m_hobbies.append(hobbies)
                        m_link.append(url)
    except AttributeError:
        print(url)
        break
            # portfolio = soup.findAll('div', {'class': 'views-field views-field-field-portfolio'})
            # for p in portfolio:
            #     p = p.get_text("", strip=True)
            #     p = p.split("(")
            #     m_portfolio.append(p[0])


for j in tqdm(m_page2): #Rescrape pages with a second page
    time.sleep(2)
    page = requests.get(j)
    if page: #If page loads
        soup = BeautifulSoup(page.content, "html.parser")
        type = soup.find('div', {'id':"block-views-members-of-parliament-block-1"})
        if type:
            page2 = soup.find('div', {'id': 'block-views-members-of-parliament-block-1'})
            page2 = page2.find('a', {'title': 'Go to next page'})  # Check if there is "Page 2" membership data
            if page2:
                m_page2.append("https://www.parliament.gov.zm/node/" + str(i) + "?page=1")
            sessions = soup.findAll('div', {'class': 'views-field views-field-field-constituency-name'})
            for s in sessions:  # Break session info into three strings
                s = s.get_text("", strip=True)
                s = s.replace(" ", "")
                s = s.split("-")
                if len(s) > 1:  # Confirm that there is session info, if blank then skip
                    m_district.append(s[0])
                    m_session.append(s[1])
                    m_party.append(s[2])

                    name = soup.find("h1", id="page-title").text.strip()
                    if name:
                        m_name.append(name)
                    else:
                        m_name.append("")
                    dob = soup.find('div', {
                        'class': 'field field-name-field-date field-type-datetime field-label-inline clearfix'}) \
                        .find('span', {'class': 'date-display-single'})['content']
                    if dob:
                        m_dob.append(dob)
                    else:
                        m_dob.append("")
                    marital = soup.find('div', {
                        'class': 'field field-name-field-marital-status field-type-list-text field-label-inline clearfix'}) \
                        .find('div', {'class': 'field-item even'}).text.strip()
                    if marital:
                        m_marital.append(marital)
                    else:
                        m_marital.append("")
                    job = soup.find('div', {
                        'class': 'field field-name-field-profession field-type-taxonomy-term-reference field-label-inline clearfix'})
                    if job:
                        job = job.get_text(", ", strip=True)
                        job = job.replace("Profession:, ", "")
                        m_job.append(job)
                    else:
                        m_job.append("job")
                    ed = soup.find('div', {
                        'class': 'field field-name-field-educational-qualification field-type-taxonomy-term-reference field-label-inline clearfix'})
                    if ed:
                        ed = ed.get_text(", ", strip=True)
                        ed = ed.replace("Educational Qualification:, ", "")
                    else:
                        ed = ""
                    m_ed.append(ed)

                    hobbies = soup.find('div', {
                        'class': 'field field-name-field-hobbies field-type-taxonomy-term-reference field-label-inline clearfix'})
                    if hobbies:
                        hobbies = hobbies.get_text(", ", strip=True)
                        hobbies = hobbies.replace("Hobbies:, ", "")
                    else:
                        hobbies = ""
                    m_hobbies.append(hobbies)
                    m_link.append(j)

length = len(m_district)-1

#Cut so that all are equal length in case of error part way through loop
m_name = m_name[0:length]
m_party = m_party[0:length]
m_district = m_district[0:length]
m_session = m_session[0:length]
m_dob = m_dob[0:length]
m_marital = m_marital[0:length]
m_job = m_job[0:length]
m_ed = m_ed[0:length]
m_hobbies = m_hobbies[0:length]
m_link = m_link[0:length]


df_members = pd.DataFrame(
    {'name': m_name,
     'party': m_party,
     'district': m_district,
     'session': m_session,
     # #'portfolio': m_portfolio,
     'dob': m_dob,
     'marital': m_marital,
     'profession': m_job,
     'education': m_ed,
     'hobbies': m_hobbies,
     'link': m_link
    })

df_members.to_csv("parl_members_zm_"+str(start)+"-"+str(i-1)+".csv")