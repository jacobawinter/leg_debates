import requests
from bs4 import BeautifulSoup
import re
import pandas as pd
from datetime import date as d

# Get new nodes
# Create list of nodes
h_date = []
h_text = []
h_node = []

main_urls = []

# Main pages
pages = range(0, 6)
for i in pages:
    url = "https://www.parliament.gov.zm/publications/debates-list?page=" + str(pages[i])
    main_urls.append(url)

# Get node links
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
            node_names.append("https://www.parliament.gov.zm" + linktext)
        else:
            pass
    h_node = h_node + node_names

# Get existing data
data_dir = "/Users/jacobwinter/Dropbox/parl_debates_data/zambia_data"

existing = pd.read_csv(data_dir + "/parl_debates_zm_2023_07_20.csv")
# Get unique links - get hnode not in

filtered_list = [x for x in h_node if x not in list(existing['url'])]

# Scrape daily (node) texts
for url in filtered_list:
    print(url)
    try:
        requests.get(url)
        page = requests.get(url)
        soup = BeautifulSoup(page.content, "html.parser")
        date = soup.find("h1", id="page-title").text.strip()
        text_raw = soup.find("div", class_="field-item even")
        t = ""
        lines = text_raw.find_all("p")
        for i in lines:
            line = i.text.strip()
            t = t + "\n" + line
        h_date.append(date)
        h_text.append(t)
    except:
        print("Error: "+url)
        h_date.append("")
        h_text.append("")

df_text = pd.DataFrame(
    {'date': h_date,
     'text': h_text,
     'url': filtered_list
     })

# append and resave
today = d.today()
d1 = today.strftime("%Y_%m_%d")

pd.concat([existing, df_text]).to_csv(data_dir + "/parl_debates_zm_" + d1 + ".csv")
