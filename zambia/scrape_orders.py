# Get Order Paper from Zambia Parliament #
# Jacob Winter #
# July 2024 #


import requests
from bs4 import BeautifulSoup
import re
import pandas as pd
from datetime import datetime, date as d
from tqdm import tqdm

# Get new nodes
# Create list of nodes
h_date = []
h_text = []
h_node = []
h_html = []

main_urls = []

def extract_date(date):
    date = re.sub("Monday, |Tuesday, |Wednesday, |Thursday, |Friday, |Saturday, |Sunday, |Debates-|st|th|nd|rd", "", date)
    date = re.sub("Otober", "October", date)
    date = re.sub("Augu", "August", date)
    day = re.findall('[0-3][0-9]|[0-9]', date)[0]
    day = int(day)
    day = str(day)
    if int(day) < 10:     #pad with zero if int(day) < 10
        day = "0" + day
    month = re.findall('January|February|March|April|May|June|July|August|September|October|November|December', date)[0]
    month = datetime.strptime(month, "%B")
    month = month.month
    year = re.findall('[0-9]{4}', date)[0]
    date = str(year)+"-"+str(month)+"-"+str(day)
    date = datetime.strptime(date, "%Y-%m-%d")
    return date


# Main pages
pages = (range(0, 18)) #First time you need to go through all pages, but later just the most recent are sufficient
for i in pages:
    url = "https://www.parliament.gov.zm/publications/order-paper-list?page=" + str(pages[i])
    main_urls.append(url)

# Get node links
for url in tqdm(main_urls):
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


data_dir = "/Users/jacobwinter/Dropbox/parl_debates_data/zambia_data"

existing = pd.read_csv(data_dir + "/order_papers_zm_2024_07_23.csv")

filtered_list = [x for x in h_node if x not in list(existing['url'])]
filtered_list = h_node


# Scrape daily (node) texts
for url in tqdm(filtered_list):
    #print(url) #Print for troubleshooting
    try:
        requests.get(url) #here for the try catch
        page = requests.get(url)
        soup = BeautifulSoup(page.content, "html.parser")
        date = soup.find("h1", id="page-title").text.strip()
        raw = soup.find("div", class_="field-item even")

        h_date.append(extract_date(date))
        h_text.append(raw.text.strip())
        h_html.append(raw)
    except:
        print("Error: "+url)
        h_date.append("")
        h_text.append("")

df_text = pd.DataFrame(
    {'date': h_date,
     'text': h_text,
     'html': h_html,
     'url': filtered_list
     })

# append and resave
today = d.today()
d1 = today.strftime("%Y_%m_%d")

#df_text = pd.concat([existing, df_text])


df_text.to_csv(data_dir + "/order_papers_zm_" + d1 + ".csv")


