import requests
from bs4 import BeautifulSoup
import re
import pandas as pd
# Create list of nodes


h_date = []
h_text = []
h_node = []

main_urls = []

#Main pages
pages = range(0,9)
for i in pages:
    url = "https://www.parliament.gov.zm/publications/debates-list?page="+ str(pages[i])
    main_urls.append(url)

##Old ones
pages = range(0,19)
for i in pages:
    url = "https://www.parliament.gov.zm/publications/debates-proceedings?page="+ str(pages[i])
    main_urls.append(url)


#Get node links
for url in main_urls:
    ## Get links
    page = requests.get(url)
    soup = BeautifulSoup(page.content, "html.parser")
    nodes = soup.find("div", id="block-system-main")
    links = nodes.find_all("a")
    node_names = []
    for ii in links:
        linktext = ii.get('href')
        if re.match('/node/*', linktext):
            node_names.append("https://www.parliament.gov.zm"+linktext)
        else:
            pass
    h_node = h_node + node_names

#Scrape daily (node) texts
for url in h_node:
    print(url)
    if requests.get(url):
        page = requests.get(url)
        soup = BeautifulSoup(page.content, "html.parser")
        date = soup.find("h1", id="page-title").text.strip()
        text_raw = soup.find("div", class_="field-item even")
        t = ""
        lines = text_raw.find_all("p")
        for i in lines:
            line = i.text.strip()
            t = t+"\n"+line
        h_date.append(date)
        h_text.append(t)
    else:
        h_date.append("")
        h_text.append("")


df_text = pd.DataFrame(
    {'date': h_date,
     'text': h_text,
     'url': h_node
    })

df_text.to_csv("parl_debates_zm.csv")