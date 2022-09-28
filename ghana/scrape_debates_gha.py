#BLAH BLAH BLAH

import requests
from bs4 import BeautifulSoup
import re, os, pandas as pd
import pandas as pd
# Create list of pages in the table
page_links = []

page = requests.get("https://www.parliament.gh/docs?type=HS&P=0")
soup = BeautifulSoup(page.content, "html.parser")
rows = soup.findAll('a', href=True)
for r in rows:
    link = r['href']
    if re.search("HS&P", link):
        page_links.append(link)

#Function to go through table and get links to pdfs
def get_table_links(u):
    page = requests.get("https://www.parliament.gh/" + str(u))
    soup = BeautifulSoup(page.content, "html.parser")
    rows = soup.findAll('a', onclick=True)
    links = []
    dates = []
    for r in rows:
        l = r['onclick']
        l = re.search("pb.*pdf", l)
        links.append("https://www.parliament.gh/epanel/docs/"+l[0])
        d = r.text
        d = d.replace('Hansard ', "")
        dates.append(d)
    return(links, dates)



#Go through each table tab and get urls
dates = []
urls = []
for i in page_links:
    links = get_table_links(i)
    dates = dates + links[1]
    urls = urls + links[0]

df_docs = pd.DataFrame(
    {'name': dates,
     'link': urls})
df_docs.to_csv("/Users/jacobwinter/repos/parl_debates/ghana/ghana_docs.csv")


os.chdir("/Users/jacobwinter/repos/parl_debates/ghana/ghana_hansard/")
nas = []
i = 0
#Loop through links and save texts
for u in urls:
    filename = dates[i]+".pdf"
    i = i + 1
    print(filename)
    #file = os.path(filename)
    if os.path.isfile(filename): #Skips any existing docs in file (allows to rerun faster if loop fails)
        continue
    else:
        try:
            response = requests.get(u)
            with open(filename,"wb") as doc:
                doc.write(response.content)
        except:
            nas.append(u)

#Save any NAs
with open("na_s_all_agree.txt", "w") as doc:
    for element in nas:
        doc.write(str(element)+"\n ")





