import requests
from bs4 import BeautifulSoup
import pandas as pd

members = pd.read_csv("/Users/jacobwinter/repos/parl_debates/kenya/kenya_members.csv")
all_ed = []
all_jobs = []

for i in range(0,len(members)):
    row = members.iloc[i]
    link = row.link
    print(link)
    page = requests.get(row.link)
    soup = BeautifulSoup(page.content, "html.parser")
    ed_table = soup.find('div', {'class':'field field--name-field-education-background field--type-text-long field--label-hidden field__item'})

    try:
        ed_table = pd.read_html(str(ed_table))[0]
        degrees = []
        for r in range(1,len(ed_table)):
            topic = ed_table.iloc[r, -1]
            degree = ed_table.iloc[r, -2]
            degrees.append(str(topic)+ ", "+str(degree))

        ed = '; '.join(degrees)
        all_ed.append(ed)
    except ValueError:
        all_ed.append("")

    jobs = []
    job_table = soup.find('div', {'class':'field field--name-field-employment-history field--type-text-long field--label-hidden field__item'})
    try:
        job_table = pd.read_html(str(job_table))[0]
        for r in range(1,len(job_table)):
            role = job_table.iloc[r, -1]
            inst = job_table.iloc[r, -2]
            jobs.append(str(role)+ ", "+str(inst))
        jobs = '; '.join(jobs)
        all_jobs.append(jobs)
    except ValueError:
        all_jobs.append("")




members['education'] = all_ed
members['occupation'] = all_jobs



members.to_csv("/Users/jacobwinter/repos/parl_debates/kenya/kenya_members_2.csv")

