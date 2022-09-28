import requests
from bs4 import BeautifulSoup
import re, os, pandas as pd


years = [2013, 2017]
session_count = [17, 35]

#Function to go through table and get links to pdfs
def get_table_links(s, p):
    import pandas as pd
    sessions = []
    members = []
    counties = []
    constits = []
    parties = []
    statuses = []
    links = []

    page = requests.get("http://www.parliament.go.ke/the-national-assembly/mps?title=%20&field_parliament_value="+str(s)+"&page="+str(p))
    soup = BeautifulSoup(page.content, "html.parser")
    rows = soup.findAll('tr', {'class':'mp'})

    for r in rows:
        sessions.append(s)

        member = r.find('td', {'class':'views-field views-field-field-name'})
        if member:
            member = member.text.replace("  ", "")
        else:
            member = ""
        members.append(member)

        county = r.find('td', {'class': 'views-field views-field-field-county'})
        if county:
            county = county.text.replace("  ", "")
        else:
            county = ""
        counties.append(county)

        constit = r.find('td', {'class': 'views-field views-field-field-constituency'})
        if constit:
            constit = constit.text.replace("  ", "")
        else:
            constit = ""
        constits.append(constit)

        party = r.find('td', {'class': 'views-field views-field-field-party'})
        if party:
            party = party.text.replace("  ", "")
        else:
            party = ""
        parties.append(party)

        status = r.find('td', {'class': 'views-field views-field-field-status'})
        if status:
            status = status.text.replace("  ", "")
        else:
            status = ""
        statuses.append(status)

        link = r.find('a', href=True)
        if link:
            link = "http://www.parliament.go.ke/"+link['href']
        else:
            link = ""
        links.append(link)

    table = pd.DataFrame({"session":sessions,
                          "member": members,
                          "county": counties,
                          "constituency": constits,
                          "party":parties,
                          "status":statuses,
                          "link":links})
    return table

#Initialize DF and then loop through based on URLS and page counts from manual inspection
member_table  = get_table_links(2013, 0)
for p in range(1,17):
    df = get_table_links(2013, p)
    member_table = pd.concat([member_table, df])

for p in range(0,35):
    df = get_table_links(2017, p)
    member_table = pd.concat([member_table, df])

member_table.to_csv("/Users/jacobwinter/repos/parl_debates/kenya/kenya_members.csv")